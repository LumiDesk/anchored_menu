import 'dart:io';

class ScriptException implements Exception {
  ScriptException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReleaseVersion {
  const ReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  String get name => '$major.$minor.$patch';

  String get tag => 'v$name';

  ReleaseVersion bump(String spec) {
    switch (spec) {
      case 'patch':
        return ReleaseVersion(major: major, minor: minor, patch: patch + 1);
      case 'minor':
        return ReleaseVersion(major: major, minor: minor + 1, patch: 0);
      case 'major':
        return ReleaseVersion(major: major + 1, minor: 0, patch: 0);
    }

    final explicit = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(spec);
    if (explicit == null) {
      throw ScriptException('版本参数非法：$spec（可用 patch / minor / major / X.Y.Z）');
    }
    final next = ReleaseVersion(
      major: int.parse(explicit.group(1)!),
      minor: int.parse(explicit.group(2)!),
      patch: int.parse(explicit.group(3)!),
    );
    if (!next.isAfter(this)) {
      throw ScriptException('目标版本 ${next.name} 必须高于当前版本 $name。');
    }
    return next;
  }

  bool isAfter(ReleaseVersion other) {
    if (major != other.major) {
      return major > other.major;
    }
    if (minor != other.minor) {
      return minor > other.minor;
    }
    return patch > other.patch;
  }

  static ReleaseVersion parse(String value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(value.trim());
    if (match == null) {
      throw ScriptException('版本号格式不正确：$value（应为 X.Y.Z）');
    }
    return ReleaseVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
    );
  }
}

ReleaseVersion readPubspecVersion(String pubspecText) {
  final match = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$',
    multiLine: true,
  ).firstMatch(pubspecText);
  if (match == null) {
    throw ScriptException('pubspec.yaml 中找不到合法的 version 行。');
  }
  return ReleaseVersion.parse(match.group(1)!);
}

String replacePubspecVersion(String pubspecText, ReleaseVersion next) {
  final updated = pubspecText.replaceFirst(
    RegExp(r'^version:\s*[^\r\n]+', multiLine: true),
    'version: ${next.name}',
  );
  if (updated == pubspecText) {
    throw ScriptException('pubspec.yaml 的 version 行未被更新。');
  }
  return updated;
}

String promoteChangelog(
  String changelog,
  ReleaseVersion next, {
  required DateTime date,
}) {
  final lines = changelog.split('\n');
  final unreleasedIndex = lines.indexWhere(
    (line) => RegExp(r'^##\s+\[Unreleased\]\s*$').hasMatch(line),
  );
  if (unreleasedIndex < 0) {
    throw ScriptException('CHANGELOG.md 缺少 `## [Unreleased]` 段落。');
  }

  var nextReleaseIndex = lines.length;
  for (var index = unreleasedIndex + 1; index < lines.length; index++) {
    if (RegExp(r'^##\s+\[').hasMatch(lines[index])) {
      nextReleaseIndex = index;
      break;
    }
  }

  final notes = lines
      .sublist(unreleasedIndex + 1, nextReleaseIndex)
      .join('\n')
      .trim();
  if (notes.isEmpty) {
    throw ScriptException('`## [Unreleased]` 中没有发布说明，请先补充 CHANGELOG.md。');
  }

  final dateLabel =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final before = lines.sublist(0, unreleasedIndex + 1);
  final after = lines.sublist(nextReleaseIndex);
  return <String>[
    ...before,
    '',
    '## [${next.name}] - $dateLabel',
    '',
    notes,
    '',
    ...after,
  ].join('\n');
}

ReleaseVersion readRepoVersion(Directory root) {
  return readPubspecVersion(_file(root, 'pubspec.yaml').readAsStringSync());
}

void writeReleaseFiles(
  Directory root, {
  required ReleaseVersion next,
  required DateTime date,
}) {
  final pubspec = _file(root, 'pubspec.yaml');
  final changelog = _file(root, 'CHANGELOG.md');
  final pubspecText = pubspec.readAsStringSync();
  final changelogText = changelog.readAsStringSync();

  pubspec.writeAsStringSync(
    replacePubspecVersion(pubspecText, next),
    flush: true,
  );
  changelog.writeAsStringSync(
    promoteChangelog(changelogText, next, date: date),
    flush: true,
  );
}

String? ciPinnedFlutterVersion(Directory root) {
  final workflows = Directory(
    '${root.path}${Platform.pathSeparator}.github'
    '${Platform.pathSeparator}workflows',
  );
  if (!workflows.existsSync()) {
    return null;
  }
  final files = workflows.listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.yml') && !file.path.endsWith('.yaml')) {
      continue;
    }
    final match = RegExp(r"flutter-version:\s*'?([0-9]+\.[0-9]+\.[0-9]+)'?")
        .firstMatch(file.readAsStringSync());
    if (match != null) {
      return match.group(1);
    }
  }
  return null;
}

File _file(Directory root, String name) =>
    File('${root.path}${Platform.pathSeparator}$name');
