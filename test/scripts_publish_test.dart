import 'package:flutter_test/flutter_test.dart';

import '../scripts/src/release.dart';

void main() {
  group('ReleaseVersion', () {
    const current = ReleaseVersion(major: 1, minor: 2, patch: 3);

    test('bumps patch, minor, and major', () {
      expect(current.bump('patch').name, '1.2.4');
      expect(current.bump('minor').name, '1.3.0');
      expect(current.bump('major').name, '2.0.0');
    });

    test('accepts an explicit higher version', () {
      expect(current.bump('2.1.0').name, '2.1.0');
    });

    test('rejects invalid or non-increasing explicit versions', () {
      expect(() => current.bump('1.2.2'), throwsA(isA<ScriptException>()));
      expect(() => current.bump('next'), throwsA(isA<ScriptException>()));
    });
  });

  test('reads and replaces the pubspec version', () {
    const pubspec = 'name: anchored_menu\nversion: 0.1.1\n';
    final current = readPubspecVersion(pubspec);
    expect(current.name, '0.1.1');

    final updated = replacePubspecVersion(pubspec, current.bump('patch'));
    expect(updated, contains('version: 0.1.2\n'));
  });

  test('promotes Unreleased notes into a dated version section', () {
    const changelog = '''
# Changelog

## [Unreleased]

- Add a release helper.

## [0.1.1] - 2026-10-17

- Previous release.
''';

    final updated = promoteChangelog(
      changelog,
      const ReleaseVersion(major: 0, minor: 1, patch: 2),
      date: DateTime(2026, 10, 18),
    );

    expect(updated, contains('## [Unreleased]\n\n## [0.1.2] - 2026-10-18'));
    expect(updated, contains('- Add a release helper.'));
    expect(updated, contains('## [0.1.1] - 2026-10-17'));
    expect(
      updated.indexOf('## [0.1.2]'),
      lessThan(updated.indexOf('## [0.1.1]')),
    );
  });

  test('rejects empty Unreleased notes', () {
    const changelog = '''
## [Unreleased]

## [0.1.1] - 2026-10-17
''';

    expect(
      () => promoteChangelog(
        changelog,
        const ReleaseVersion(major: 0, minor: 1, patch: 2),
        date: DateTime(2026, 10, 18),
      ),
      throwsA(isA<ScriptException>()),
    );
  });
}
