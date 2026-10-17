import 'dart:convert';
import 'dart:io';

import 'release.dart';

bool get _colorEnabled =>
    !Platform.environment.containsKey('NO_COLOR') && stdout.supportsAnsiEscapes;

String _paint(String value, String code) =>
    _colorEnabled ? '\u001B[${code}m$value\u001B[0m' : value;

void info(String message) => stdout.writeln(message);

void step(String message) => stdout.writeln(_paint('▶ $message', '36'));

void success(String message) => stdout.writeln(_paint('✓ $message', '32'));

void warn(String message) => stdout.writeln(_paint('! $message', '33'));

void error(String message) => stderr.writeln(_paint('✗ $message', '31'));

Directory findRepoRoot() {
  var directory = Directory.current.absolute;
  while (true) {
    final pubspec = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (pubspec.existsSync()) {
      final text = pubspec.readAsStringSync();
      if (RegExp(
        r'^name:\s*anchored_menu\s*$',
        multiLine: true,
      ).hasMatch(text)) {
        return directory;
      }
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw ScriptException('找不到 anchored_menu 仓库根目录。');
    }
    directory = parent;
  }
}

Future<void> run(
  List<String> command, {
  required Directory workingDirectory,
}) async {
  final process = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory.path,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ScriptException('命令失败（退出码 $exitCode）：${command.join(' ')}');
  }
}

Future<({int exitCode, String stdout, String stderr})> capture(
  List<String> command, {
  required Directory workingDirectory,
  bool allowFailure = false,
}) async {
  const utf8Loose = Utf8Codec(allowMalformed: true);
  final result = await Process.run(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory.path,
    runInShell: Platform.isWindows,
    stdoutEncoding: utf8Loose,
    stderrEncoding: utf8Loose,
  );
  final output = (
    exitCode: result.exitCode,
    stdout: (result.stdout as String?) ?? '',
    stderr: (result.stderr as String?) ?? '',
  );
  if (result.exitCode != 0 && !allowFailure) {
    final detail = output.stderr.trim();
    throw ScriptException(
      '命令失败（退出码 ${result.exitCode}）：${command.join(' ')}'
      '${detail.isEmpty ? '' : '\n$detail'}',
    );
  }
  return output;
}

String? resolveCommand(String command) {
  const utf8Loose = Utf8Codec(allowMalformed: true);
  final finder = Platform.isWindows ? 'where' : 'which';
  final result = Process.runSync(
    finder,
    <String>[command],
    runInShell: Platform.isWindows,
    stdoutEncoding: utf8Loose,
    stderrEncoding: utf8Loose,
  );
  if (result.exitCode != 0) {
    return null;
  }
  return ((result.stdout as String?) ?? '')
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
}

Future<String?> flutterVersion(Directory root) async {
  final result = await capture(
    <String>['flutter', '--version', '--machine'],
    workingDirectory: root,
    allowFailure: true,
  );
  if (result.exitCode != 0) {
    return null;
  }
  try {
    final json = jsonDecode(result.stdout) as Map<String, Object?>;
    return json['frameworkVersion'] as String?;
  } on FormatException {
    return null;
  }
}
