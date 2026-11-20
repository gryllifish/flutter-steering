---
name: triage
description: Find the root cause of a Flutter/Dart error fast from any log - flutter run/test output, device logs (logcat, iOS), Gradle/Xcode/CocoaPods builds, pub resolution, analyzer, CI runs. Extracts the signal from long logs, keeps only the project's own stack frames, then traces it to the code. Use when the user shares an error or stack trace, a build or test fails, or the app crashes.
argument-hint: "[log-file | 'device' | 'ci <run-url>' | failing command]"
---

# Triage

Never read a long log into the conversation: save it to a file and extract.

## 1. Get the log into a file (scratch directory)
| Source | How |
|---|---|
| Pasted by the user | write it to a file |
| A failing command (build, test, pub get) | re-run it capturing output: `<cmd> > <file> 2>&1`; add `--verbose` / `--stacktrace` only if the extract isn't enough |
| Running app | Dart MCP: `list_devices` → `launch_app` (or `dtd` → connect to an app the user started) → reproduce → `get_runtime_errors` / `get_app_logs` |
| Android device | `adb logcat -c`, reproduce, `adb logcat -d -t 3000 > <file>` |
| iOS simulator | `xcrun simctl spawn booted log show --last 5m --style compact --predicate 'process == "Runner"' > <file>` |
| CI | `gh run view <id> --log-failed > <file>` |
| Crashlytics / Sentry | their MCP server if the project already has one; otherwise ask the user for the issue's stack trace (ask before adding any server) |

## 2. Extract
```sh
dart <skill-dir>/scripts/extract_errors.dart --root <project-root> <file>
```
Distinct errors in order of first appearance, deduplicated with counts,
with only project frames (`lib/`, `test/`, native project files) and the
error-causing widget. Exit 1 when errors were found. If the extract is not
enough, read the raw log only around one message:
`grep -n -A 20 '<message>' <file>`.

## 3. Diagnose
- Start from the **first** error; later ones are often cascades
  ("Another exception was thrown", failures after a failed build step).
- Read the code at the top project frame or the error-causing widget before
  forming a hypothesis.
- Messages that point away from the cause:

| Message | Look at |
|---|---|
| `Vertical viewport was given unbounded height`, `RenderBox was not laid out` | the parent: a scrollable inside a Flex or another scrollable without bounded size |
| `Incorrect use of ParentDataWidget` | `Expanded`/`Flexible`/`Positioned` not directly under a Flex/Stack |
| `setState() called after dispose()`, `Looking up a deactivated widget's ancestor` | an `await` followed by `context`/`setState` without a `mounted` check |
| `MissingPluginException` | plugin added without a full rebuild, unsupported platform, or a test without a mock |
| `ProviderNotFoundException`, `No ProviderScope found`, `BlocProvider.of() called with a context that does not contain` | the `context` sits above the provider |
| Gradle `Unsupported class file major version`, AGP/Kotlin errors | JDK/AGP/Kotlin/Gradle version mismatch (`flutter doctor -v`, `android/settings.gradle*`, `gradle-wrapper.properties`) |
| CocoaPods `could not find compatible versions` | `pod repo update` + `pod install` in `ios/`; deployment target in `Podfile` |
| pub `version solving failed` | the `Because…` chain; the `* Try` suggestion is usually the fix |

## 4. Fix and prove it
1. State the root cause in one or two sentences with `path:line` evidence.
   If unsure, say what would confirm it instead of guessing.
2. If it reproduces in a test, write the failing regression test first
   (`test` skill), then fix.
3. Re-run the same command or reproduction and extract again: the error must
   be gone, not replaced by a different one.
4. Fix the cause, not the symptom: no catch that swallows, no `?? ''` over a
   value that shouldn't be null, no analyzer `ignore`.

## Report
Root cause · evidence (`path:line` + extract excerpt) · fix · how it was
verified · cascade errors that disappeared with it.
