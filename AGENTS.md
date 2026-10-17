# Anchored Menu Agent Guide

This file is the repository-level execution guide for agents and maintainers.
It records current architectural boundaries, quality gates, and release rules.

## Project Scope

`anchored_menu` is a standalone Flutter widget package published on pub.dev.
It provides anchored popup menus with recursive card-style submenus.

- Repository: `LumiDesk/anchored_menu`
- Package: `anchored_menu`
- License: BSD 3-Clause
- Minimum toolchain in CI: Flutter 3.47.2 / Dart 3.13.2
- Runtime dependency: Flutter SDK only

The package must remain reusable outside Veri Fin. Do not introduce business
models, ledger concepts, Veri Fin design tokens, localization strings, or app
state management into the package.

Use Chinese when communicating with the maintainer. Keep code, API names,
commits, and package documentation in English.

## Current Architecture

| Path | Responsibility |
| --- | --- |
| `lib/anchored_menu.dart` | Stable public barrel; the only import consumers should need |
| `lib/src/anchored_menu_anchor.dart` | Public trigger widgets and controlled-choice adapter |
| `lib/src/anchored_menu_entry.dart` | Public menu entry and item models |
| `lib/src/anchored_menu_theme.dart` | Public `ThemeExtension` and resolved theme values |
| `lib/src/anchored_menu_route.dart` | Internal overlay route, placement, animation, focus, and rendering |
| `example/` | Runnable Android/Web example using the package through a path dependency |
| `test/` | Widget tests and release-script unit tests |
| `scripts/publish.dart` | Maintainer release helper |
| `doc/screenshots/` | README and pub.dev screenshots |

`AnchoredMenuRoute` and `ResolvedAnchoredMenuTheme` live under `lib/src` and are
not exported. Keep routing and rendering internals private. If another file
needs them, prefer moving shared behavior into a focused internal module rather
than exporting implementation details from the barrel.

## Public API Rules

Public entry points currently include:

- `AnchoredMenuAnchor`
- `AnchoredMenuButton`
- `AnchoredMenuChoice<T>`
- `AnchoredMenuEntry`
- `AnchoredMenuItem`
- `AnchoredMenuDivider`
- `AnchoredMenuAnchorBuilder`
- `AnchoredMenuThemeData`

Follow these rules:

- Use product-neutral names. Do not add a `Veri` or Veri Fin prefix.
- Keep widget APIs controlled: selection, disabled state, and current values
  remain owned by the caller.
- Require stable, unique menu item IDs. Do not derive IDs from localized text
  or list indexes.
- Keep `keyPrefix` configurable. Default keys use `anchored_menu_*`; existing
  consumers may pass another prefix to preserve integration keys.
- Do not add direct access to application controllers, persistence, providers,
  or global state.
- Public identifiers must have useful Dart documentation comments.
- Prefer additive, parameterized APIs over duplicating widgets.

Before 1.0, breaking API changes may ship in a minor release, but they must be
called out clearly in `CHANGELOG.md`.

## Behavior Invariants

Changes must preserve the established menu behavior unless the request
explicitly changes it:

- Position the menu relative to the trigger and keep it inside the viewport.
- Open below when there is enough space; otherwise open above.
- Keep the complete ancestor card stack visible while navigating submenus.
- Each nested card expands from the activated row and preserves continuous
  content.
- Outside tap closes the complete menu.
- Android/system back closes one submenu level before closing the root menu.
- Arrow keys move the highlighted enabled item.
- Enter, Numpad Enter, and Space activate the highlighted item.
- Horizontal arrow directions follow LTR/RTL reading direction.
- Escape and horizontal back navigation return one menu level.
- Disabled items are skipped by keyboard navigation.
- Menu and selected-item semantics remain available to screen readers.
- Text measurement must use the active `TextDirection` and `TextScaler`.
- Respect `MediaQuery.disableAnimationsOf(context)`.

The current visual timings are root 220ms, submenu forward 280ms, and submenu
reverse 260ms. Do not change them incidentally.

## Theme and Styling

`AnchoredMenuThemeData` is the package-owned styling boundary. It may override:

- surface and border colors
- foreground and selected colors
- panel and item radii
- title and subtitle styles
- minimum menu width

Unspecified values resolve from the surrounding Material theme. Do not import
application theme files or hardcode consumer brand colors.

The menu surface must remain opaque. Do not add blur, refraction, shader
effects, or decorative gradients.

## Code Quality

- Follow default Dart formatting with two-space indentation.
- Keep files in `snake_case.dart`; use `UpperCamelCase` for public types.
- Prefer small internal helpers over a configuration-object monolith.
- Avoid adding packages for behavior that Flutter already provides.
- Any new dependency requires a concrete maintenance, size, licensing, and
  platform rationale.
- Do not use `print` for library logging.
- Do not add platform plugins unless the package scope changes explicitly.
- Keep public API documentation current when behavior changes.

## Testing

Every behavior change needs a focused widget or unit test.

Required checks before committing:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter analyze
flutter test
```

Run the final two commands from `example/`.

Tests should cover, as applicable:

- root placement and edge avoidance
- recursive submenu navigation
- selected, disabled, divider, icon, and subtitle states
- outside tap and system back
- keyboard focus and activation
- RTL layout and direction
- narrow viewports, long labels, and large text
- custom widths and key prefixes
- theme extension fallback and overrides
- example integration

Do not replace interaction tests with golden-only tests. Goldens may be added
for visual regression, but behavioral assertions remain required.

## Package Hygiene

Before publishing, inspect the complete file list from:

```powershell
dart pub publish --dry-run
```

`.pubignore` overrides `.gitignore` for pub publication. When changing
`.pubignore`, verify that local build/cache artifacts remain excluded:

- `/build/`
- `/coverage/`
- `/doc/api/`
- `/*.iml`
- `scripts/`
- `test/scripts_publish_test.dart`

Pub validation must report `0 warnings`. Do not use `--skip-validation` or
silence unrelated warnings.

The README and `pubspec.yaml` screenshot paths must remain valid and included in
the published archive.

## Release Process

`CHANGELOG.md` must contain a `## [Unreleased]` section with release notes.
The release helper promotes those notes into a dated version section.

Preview the release first:

```powershell
dart run scripts/publish.dart patch --dry-run
```

Release commands:

```powershell
dart run scripts/publish.dart patch
dart run scripts/publish.dart minor
dart run scripts/publish.dart major
dart run scripts/publish.dart 1.2.3
```

The helper:

1. Requires a clean `main` branch that is not behind `origin/main`.
2. Verifies local Flutter matches the CI-pinned version.
3. Updates `pubspec.yaml` and `CHANGELOG.md`.
4. Runs formatting, dependency resolution, analysis, and package/example tests.
5. Validates package contents.
6. Creates `chore: release vX.Y.Z`.
7. Creates and pushes an annotated `vX.Y.Z` tag.
8. Waits for the GitHub Actions publish workflow.

Do not run the non-dry-run release helper, push a release tag, or call
`dart pub publish` unless the maintainer explicitly authorizes a release.

Published pub.dev versions are permanent. Never reuse or move a release tag.
The repository ruleset protects `v*` tags from updates and deletion.

## GitHub and Contributions

- External PR creation is disabled with
  `pull_request_creation_policy: collaborators_only`.
- Issues remain enabled for feedback.
- Do not re-enable general PR creation without an explicit maintainer decision.
- Maintainers implement accepted changes directly.
- Do not push commits unless requested.
- Use concise commit messages such as `feat: add ...`, `fix: ...`, or
  `chore: ...`; do not add AI or Codex attribution.

## CI and Publishing

- `.github/workflows/ci.yml` runs format, analyze, package tests, example
  tests, and publish dry-run on `main` and pull requests.
- `.github/workflows/publish.yml` runs only for `vX.Y.Z` tags.
- Publication uses pub.dev OIDC and the official
  `dart-lang/setup-dart/.github/workflows/publish.yml@v1` reusable workflow.
- The pub.dev tag pattern is `v{{version}}`; `pubspec.yaml` and the tag must
  match exactly.
- Do not add long-lived pub.dev credentials to GitHub secrets.

## Documentation and Completion

- `README.md` is the public package page. Keep installation, usage, theming,
  keyboard behavior, screenshots, and license references accurate.
- `CHANGELOG.md` records every published change. Use user-visible wording.
- Do not add process notes, plans, or review transcripts to the repository.
- If implementation and documentation disagree, verify source, tests,
  workflows, and release scripts first, then update the documentation.

Before reporting completion:

- Check that the change is within the requested scope.
- Confirm the worktree contains no unintended generated files.
- Run the applicable format, analyze, package tests, and example tests.
- Run `dart pub publish --dry-run` when package contents, metadata, or release
  behavior changed.
- Report commands run, results, commits created, and anything intentionally not
  run.
