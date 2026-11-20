---
name: deps
description: Manage Dart/Flutter dependencies safely - evaluate and add a package (with user approval), upgrade outdated packages in small verified steps, or migrate the Flutter/Dart SDK version. Use when adding a package, running pub upgrades, fixing version conflicts or bumping Flutter.
argument-hint: "['add <package>' | 'upgrade' | 'sdk <version>']"
---

# Dependencies

Prefix commands with `fvm` when the project pins an SDK with FVM.

## `add <package>`: never add without the user's approval
1. Check whether the need is already covered by the SDK or an existing
   dependency.
2. Evaluate on pub.dev (the Dart MCP server's `pub_dev_search` if available,
   else `https://pub.dev/api/packages/<name>` and the package page): pub
   points, likes/popularity, verified publisher, last release date, open
   issues trend, null safety/Dart 3, platform support for the project's
   targets, license (flag GPL/AGPL), transitive dependency weight, native
   setup required.
3. Present to the user: what it solves, 1–2 alternatives (including "write it
   ourselves" when < ~100 lines), the evaluation in a short table, and a
   recommendation. Wait for approval.
4. Add with `flutter pub add <pkg>` (or `dev:<pkg>`), keep the project's
   constraint style (caret), complete native setup (Android manifest,
   iOS Info.plist / Podfile min version), and run the `verify` skill.

## `upgrade`
1. `flutter pub outdated --json` → classify: patch/minor (resolvable) vs
   major (breaking) vs blocked (by constraints or SDK).
2. Patch/minor in one go: `flutter pub upgrade`, then verify.
3. Majors **one package (or tightly coupled family) at a time**: read the
   CHANGELOG/migration guide between versions, `flutter pub upgrade
   --major-versions <pkg>`, apply migrations, regenerate codegen, verify.
   One commit per major upgrade.
4. `dart fix --dry-run` → apply with `dart fix --apply` when it addresses
   deprecations from the upgrade.
5. Report: upgraded, skipped (why), breaking changes handled, follow-ups.

## `sdk <version>`
1. Read the Flutter release notes and breaking changes between current and
   target versions; list the ones that affect this codebase (grep for the
   affected APIs).
2. Update the pin (`.fvmrc` / `fvm use <version>`), the SDK constraint in
   `pubspec.yaml` if needed, CI's `flutter-version`, and any Dockerfile.
3. `flutter pub get`, `dart fix --apply`, codegen, verify. Fix deprecations
   rather than ignoring them.
4. Native side: Android Gradle Plugin/Kotlin/Gradle wrapper versions and iOS
   deployment target, when the release notes require them. Build each
   target platform once (`flutter build apk --debug`, `flutter build ios
   --no-codesign --debug`, `flutter build web`).
