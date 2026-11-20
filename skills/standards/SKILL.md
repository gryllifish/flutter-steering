---
name: standards
description: Project-first rules for writing Dart/Flutter code as an agent - follow the codebase's own conventions, keep diffs on-task in someone else's code, and avoid APIs that current Flutter, Dart, Riverpod, freezed and go_router have deprecated. Use before writing, refactoring or reviewing Dart/Flutter code. Do not use for general Flutter how-to (architecture, layouts, routing, JSON, l10n setup, tests); the official dart-flutter plugin skills cover those.
---

# Flutter standards

Only what changes an agent's default behavior is here. General Flutter best
practice is left out on purpose: the model already knows it, and the official
`dart-flutter` plugin has task skills for architecture, layouts, routing,
JSON, HTTP, localization and tests (see the table at the end).

## 1. The project wins
1. Read the project's `CLAUDE.md` / `AGENTS.md` / steering docs first.
2. Know the stack: the SessionStart line, or
   `../onboard/scripts/detect_stack.sh <project-root>` (relative to this
   skill's directory).
3. Mirror the closest existing example (feature, widget, test): naming,
   folders, state management, error handling, test style.
4. Introduce a pattern only when the project has none, and say so. Never add
   a second state-management, routing or DI library.
5. Write for the SDK the project pins (`.fvmrc`, pubspec `environment`). If it
   is older than an API below, match the neighboring code instead.

## 2. In someone else's codebase
- The diff contains the task and nothing else: no drive-by refactors,
  renames, reformatting or lint cleanup outside the lines you change.
- If something looks wrong, say so and ask; don't fix it as a side effect.
- State the plan and its assumptions before any non-trivial edit.

## 3. Outdated APIs agents still generate
The analyzer reports these as `deprecated_member_use` and the Stop hook feeds
that back, but getting them right first saves a turn. Recheck this table when
the project upgrades one of these packages.

| Don't generate | Use instead | Since |
|---|---|---|
| `color.withOpacity(0.5)` | `color.withValues(alpha: 0.5)` | Flutter 3.27 |
| `color.value`, `.red`/`.green`/`.blue`/`.alpha` (ints) | `color.toARGB32()`, `.r`/`.g`/`.b`/`.a` (doubles 0-1) | Flutter 3.27 |
| `WillPopScope`, `onPopInvoked` | `PopScope` with `canPop` + `onPopInvokedWithResult` | Flutter 3.12 / 3.24 |
| `MaterialStateProperty`, `MaterialState` | `WidgetStateProperty`, `WidgetState` | Flutter 3.19 |
| `textScaleFactor` | `TextScaler`, `MediaQuery.textScalerOf(context)` | Flutter 3.16 |
| `ColorScheme` `background`, `onBackground`, `surfaceVariant` | `surface`, `onSurface`, `surfaceContainerHighest` | Flutter 3.22 |
| `MediaQuery.of(context).size` | `MediaQuery.sizeOf(context)` (rebuilds only on size changes) | Flutter 3.10 |
| `dart:html`, `package:js` | `package:web` + `dart:js_interop` (required for Wasm) | Dart 3.3 |
| Riverpod `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider` in new code | `Notifier` / `AsyncNotifier` (the old ones live in `flutter_riverpod/legacy.dart`) | Riverpod 3.0 |
| freezed `class X with _$X` | `abstract class X with _$X` or `sealed class X with _$X` | freezed 3.0 |
| freezed `.when()` / `.map()` in new code | Dart `switch` with pattern matching | freezed 3.0 |
| go_router `state.queryParams`, `state.location` | `state.uri.queryParameters`, `state.uri`, `state.matchedLocation` | go_router 10 |
| `print` / `debugPrint` for diagnostics | the project's logger, else `log()` from `dart:developer` | |

## 4. Agent conduct
- Ask before adding a dependency; evaluate it with the `deps` skill.
- Never silence the analyzer (`// ignore`, lowered severities, deleted tests)
  to get green.
- Never hand-edit generated files (a hook blocks it): change the source and
  regenerate.

## Where the rest lives
| Need | Use |
|---|---|
| Architecture for a new project | official `flutter-apply-architecture-best-practices` |
| Overflow / unbounded constraints | official `flutter-fix-layout-issues` (`triage` when you only have a log) |
| Routing, JSON, HTTP, localization setup, responsive layout | official `flutter-setup-declarative-routing`, `flutter-implement-json-serialization`, `flutter-use-http-package`, `flutter-setup-localization`, `flutter-build-responsive-layout` |
| Tests, mocks, coverage | official `flutter-add-widget-test`, `flutter-add-integration-test`, `dart-add-unit-test`, `dart-generate-test-mocks`, `dart-collect-coverage`; the `flutter-test-writer` agent for larger batches |
