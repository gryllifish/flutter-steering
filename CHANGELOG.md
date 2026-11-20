# Changelog

## 0.4.0 - 2026-11-20

Repositioned as a companion to the official Dart and Flutter plugin
(`dart-flutter@dart-flutter` from flutter/agent-plugins).

- MCP: the bundled server now exposes only the app lifecycle tools the
  official configuration leaves off (`--disable all --enable
  flutter_app_lifecycle`), so the two plugins never duplicate tools. Server
  renamed to `dart-app`.
- `standards`: rewritten to novel information only (project-first rules,
  on-task diffs, deprecated APIs agents still generate). The generic
  architecture, state-management and widget references were removed.
- Removed the `test` skill and its testing reference; the official test
  skills and the `flutter-test-writer` agent cover it.
- `l10n` became `l10n-audit`: setup is left to the official
  `flutter-setup-localization`; adds `arb_parity.sh` for key and
  placeholder parity across locales.
- `feature` points to the official architecture skill for new projects.
- Every skill description is in third person and says when not to use it.
- SessionStart adds session rules (baseline before changes, hot reload after
  `lib/` edits, no commits without approval) and suggests the official
  plugin when it isn't enabled.
- `flutter-reviewer` leaves analyzer findings to the analyzer and checks
  that new tests would fail if the fix were reverted.
- CI validates skills with `skills_lint` and runs every test script.

## 0.3.0 - 2026-11-20

- `triage` skill: root cause from any log source (flutter run/test,
  logcat, iOS simulator, Gradle, Xcode, CocoaPods, pub, analyzer, CI), with
  a dependency-free Dart extractor that keeps distinct errors in order,
  deduplicates repeats and drops every stack frame outside the project.
  Tested against real `flutter test` and `pub get` logs and synthetic
  native/device logs.
- Dart MCP server: app lifecycle tools enabled (`list_devices`,
  `launch_app`, `get_app_logs`, `stop_app`), so Claude can run the app and
  read its logs directly.
- CI formats and analyzes the Dart scripts and runs the triage tests.

## 0.2.0 - 2026-11-20

Safer defaults for working in someone else's codebase.

- `onboard`: new `env_check.sh` readiness check (SDK constraints vs installed
  SDK, FVM pins, CI version drift, pub get, committed codegen outputs, l10n,
  env and `--dart-define-from-file` inputs, flavors, launch configs,
  Firebase config). Guidance for keeping diffs on-task in foreign code.
- Format hook: skips files whose committed version isn't dart-formatted.
- Stop hook: blocks only on issues in lines changed vs HEAD (any line for new
  files); pre-existing issues are mentioned without blocking. Uses the
  analyzer's machine format, so paths match reliably.
- Secrets guard: checks each command segment; build tools (`flutter`, `fvm`,
  `dart`, Gradle, `xcodebuild`, fastlane, melos) may reference secret files.

## 0.1.0 - 2026-11-20

Initial release.

- Skills: `standards`, `onboard`, `verify`, `feature`, `test`, `review`,
  `perf-audit`, `a11y-audit`, `l10n`, `deps`, `release`, `ci`, `commit`.
- Agents: `flutter-explorer`, `flutter-reviewer`, `flutter-test-writer`.
- Hooks: stack context on session start, generated-file guard, secrets and
  destructive-command guard, format on edit, analyze before finishing.
- Dart & Flutter MCP server configuration.
- Hook test suite and CI.
