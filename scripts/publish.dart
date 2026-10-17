// Release helper: bump version, run quality gates, commit, tag, push, and wait
// for the GitHub Actions publish workflow.
//
// Usage:
//   dart run scripts/publish.dart patch
//   dart run scripts/publish.dart minor
//   dart run scripts/publish.dart major
//   dart run scripts/publish.dart 1.2.3
//   dart run scripts/publish.dart patch --dry-run

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'src/commands.dart';
import 'src/release.dart';

const String _usage = '''
Usage:
  dart run scripts/publish.dart patch|minor|major|X.Y.Z [options]

Options:
  --dry-run             Validate and print the plan without changing files.
  --skip-version-check  Skip comparing local Flutter with the CI version.
  --no-wait             Do not wait for the GitHub Actions publish workflow.
  -h, --help            Show this help.
''';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await _run(arguments);
  } on ScriptException catch (exception) {
    error(exception.message);
    exitCode = 1;
  }
}

Future<int> _run(List<String> arguments) async {
  var dryRun = false;
  var skipVersionCheck = false;
  var waitForWorkflow = true;
  final positional = <String>[];

  for (final argument in arguments) {
    switch (argument) {
      case '--dry-run':
        dryRun = true;
      case '--skip-version-check':
        skipVersionCheck = true;
      case '--no-wait':
        waitForWorkflow = false;
      case '-h' || '--help':
        info(_usage);
        return 0;
      default:
        if (argument.startsWith('-')) {
          error('未知选项：$argument');
          info(_usage);
          return 1;
        }
        positional.add(argument);
    }
  }

  if (positional.length != 1) {
    info(_usage);
    return 1;
  }

  final root = findRepoRoot();
  final spec = positional.single;

  step('Checking repository state');
  final status = await capture(<String>[
    'git',
    'status',
    '--porcelain',
  ], workingDirectory: root);
  if (status.stdout.trim().isNotEmpty) {
    if (!dryRun) {
      throw ScriptException('工作树不干净。请先提交或 stash，再执行正式发布。');
    }
    warn('工作树不干净；dry-run 只做检查，不会写入或发布。');
  } else {
    success('工作树干净');
  }

  final branch = await capture(<String>[
    'git',
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  ], workingDirectory: root);
  if (branch.stdout.trim() != 'main') {
    throw ScriptException('发布必须在 main 分支执行，当前为 ${branch.stdout.trim()}。');
  }
  success('当前分支：main');

  step('Fetching remote state');
  await run(<String>[
    'git',
    'fetch',
    'origin',
    'main',
    '--tags',
  ], workingDirectory: root);
  final divergence = await capture(<String>[
    'git',
    'rev-list',
    '--left-right',
    '--count',
    'HEAD...origin/main',
  ], workingDirectory: root);
  final counts = divergence.stdout.trim().split(RegExp(r'\s+'));
  final behind = counts.length == 2 ? int.parse(counts[1]) : 0;
  if (behind > 0) {
    throw ScriptException('本地 main 落后 origin/main $behind 个提交，请先同步。');
  }
  success('本地 main 不落后远端');

  if (!skipVersionCheck) {
    step('Checking Flutter version');
    final pinned = ciPinnedFlutterVersion(root);
    final local = await flutterVersion(root);
    if (local == null) {
      throw ScriptException('无法读取本机 Flutter 版本。');
    }
    if (pinned == null) {
      warn('未能从 CI workflow 解析 Flutter 版本，跳过比对。');
    } else if (pinned != local) {
      throw ScriptException(
        '本机 Flutter $local 与 CI 固定版本 $pinned 不一致。'
        '请切换 Flutter，或加 --skip-version-check。',
      );
    } else {
      success('Flutter $local（与 CI 一致）');
    }
  }

  step('Calculating release version');
  final current = readRepoVersion(root);
  final next = current.bump(spec);
  final releaseDate = DateTime.now();
  info('  ${current.name} → ${next.name}（tag ${next.tag}）');

  final changelog = File('${root.path}${Platform.pathSeparator}CHANGELOG.md')
      .readAsStringSync();
  final nextChangelog = promoteChangelog(changelog, next, date: releaseDate);
  success('CHANGELOG.md 含待发布说明');

  final localTag = await capture(
    <String>[
      'git',
      'rev-parse',
      '--verify',
      '--quiet',
      'refs/tags/${next.tag}',
    ],
    workingDirectory: root,
    allowFailure: true,
  );
  if (localTag.exitCode == 0) {
    throw ScriptException('标签 ${next.tag} 已存在（本地）。');
  }
  final remoteTag = await capture(
    <String>[
      'git',
      'ls-remote',
      '--exit-code',
      '--tags',
      'origin',
      'refs/tags/${next.tag}',
    ],
    workingDirectory: root,
    allowFailure: true,
  );
  if (remoteTag.exitCode == 0) {
    throw ScriptException('标签 ${next.tag} 已存在（origin）。');
  }
  success('标签 ${next.tag} 可用');

  if (dryRun) {
    step('Release plan');
    info('  1. 更新 pubspec.yaml 与 CHANGELOG.md');
    info('  2. dart format .');
    info('  3. flutter pub get / analyze / test（包与 example）');
    info('  4. dart pub publish --dry-run');
    info('  5. git commit -m "chore: release ${next.tag}"');
    info('  6. git tag ${next.tag}');
    info('  7. git push origin main && git push origin ${next.tag}');
    if (waitForWorkflow) {
      info('  8. 等待 GitHub Actions 发布 workflow');
    }
    info('');
    info('建议写入的新版本段落预览：');
    info(
      nextChangelog
          .substring(
            nextChangelog.indexOf('## [${next.name}]'),
            nextChangelog.indexOf('## [${current.name}]'),
          )
          .trimRight(),
    );
    success('dry-run 完成：未修改文件、未提交、未推送。');
    return 0;
  }

  step('Writing release metadata');
  writeReleaseFiles(root, next: next, date: releaseDate);
  success('pubspec.yaml 与 CHANGELOG.md 已更新');

  step('Running quality gates');
  await run(<String>['dart', 'format', '.'], workingDirectory: root);
  await run(<String>['flutter', 'pub', 'get'], workingDirectory: root);
  final example = Directory('${root.path}${Platform.pathSeparator}example');
  await run(<String>['flutter', 'pub', 'get'], workingDirectory: example);
  await run(<String>['flutter', 'analyze'], workingDirectory: root);
  await run(<String>['flutter', 'test'], workingDirectory: root);
  await run(<String>['flutter', 'analyze'], workingDirectory: example);
  await run(<String>['flutter', 'test'], workingDirectory: example);

  step('Preflight package validation');
  await run(<String>[
    'dart',
    'pub',
    'publish',
    '--dry-run',
    '--ignore-warnings',
  ], workingDirectory: root);

  step('Creating release commit');
  await run(<String>['git', 'add', '-A'], workingDirectory: root);
  await run(<String>[
    'git',
    'commit',
    '-m',
    'chore: release ${next.tag}',
  ], workingDirectory: root);

  final strictStatus = await capture(<String>[
    'git',
    'status',
    '--porcelain',
  ], workingDirectory: root);
  if (strictStatus.stdout.trim().isNotEmpty) {
    throw ScriptException('发布提交后工作树仍不干净，停止打标签。');
  }

  step('Strict publish validation');
  await run(<String>[
    'dart',
    'pub',
    'publish',
    '--dry-run',
  ], workingDirectory: root);

  step('Tagging and pushing');
  await run(<String>[
    'git',
    'tag',
    '-a',
    next.tag,
    '-m',
    'anchored_menu ${next.name}',
  ], workingDirectory: root);
  await run(<String>['git', 'push', 'origin', 'main'], workingDirectory: root);
  await run(<String>[
    'git',
    'push',
    'origin',
    next.tag,
  ], workingDirectory: root);
  success('已推送 ${next.tag}');

  if (waitForWorkflow) {
    await _waitForPublishWorkflow(root);
  } else {
    info('已跳过 workflow 等待。');
  }
  info('pub.dev: https://pub.dev/packages/anchored_menu');
  return 0;
}

Future<void> _waitForPublishWorkflow(Directory root) async {
  if (resolveCommand('gh') == null) {
    warn('找不到 gh，跳过发布 workflow 等待。');
    return;
  }

  step('Waiting for GitHub Actions publish workflow');
  final head = await capture(<String>[
    'git',
    'rev-parse',
    'HEAD',
  ], workingDirectory: root);
  final sha = head.stdout.trim();

  for (var attempt = 0; attempt < 24; attempt++) {
    final listed = await capture(
      <String>[
        'gh',
        'run',
        'list',
        '--workflow',
        'publish.yml',
        '--limit',
        '10',
        '--json',
        'databaseId,headSha,workflowName',
      ],
      workingDirectory: root,
      allowFailure: true,
    );
    if (listed.exitCode == 0) {
      try {
        final runs = jsonDecode(listed.stdout) as List<Object?>;
        for (final item in runs.whereType<Map<String, Object?>>()) {
          if (item['headSha'] == sha &&
              item['workflowName'] == 'Publish to pub.dev') {
            final id = item['databaseId'];
            if (id is int) {
              await run(<String>[
                'gh',
                'run',
                'watch',
                '$id',
                '--exit-status',
              ], workingDirectory: root);
              success('GitHub Actions 发布成功');
              return;
            }
          }
        }
      } on FormatException {
        // Fall through and retry while GitHub indexes the new run.
      }
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
  warn('两分钟内未发现发布 workflow；请到 GitHub Actions 手动检查。');
}
