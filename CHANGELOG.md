# Changelog

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
