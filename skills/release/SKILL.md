---
name: release
description: Prepare a Flutter app release - version bump, changelog from Conventional Commits, pre-release checks, release builds with obfuscation, and a store submission checklist. Use only when the user explicitly asks to prepare or cut a release.
argument-hint: "[major | minor | patch | <version>]"
disable-model-invocation: true
---

# Release

Nothing here pushes, tags, uploads or publishes without the user's explicit
approval at that step.

## 1. Version
- `pubspec.yaml` `version: X.Y.Z+N`: bump X.Y.Z per argument (or infer from
  commits since the last tag: `feat` → minor, `fix` → patch, `!`/`BREAKING
  CHANGE` → major) and always increment the build number `N`.
- If the project uses a release tool (release-please, cider, melos version),
  use it instead.

## 2. Changelog
From `git log <last-tag>..HEAD --oneline`, group Conventional Commits into
Features / Fixes / Breaking / Other in `CHANGELOG.md` under the new version
and date. User-facing release notes (store "What's new") written separately,
in plain language, per locale the store listing supports.

## 3. Pre-release checks
- `verify` skill green; integration tests if they exist.
- No debug leftovers: `debugPrint`, `print`, `kDebugMode` bypasses, test
  endpoints, `debugShowCheckedModeBanner: true`.
- Config for the release flavor points to production; no secrets in the repo.
- Android: `minSdk`/`targetSdk` meet Play requirements, signing via
  `key.properties` (never read it), permissions justified.
- iOS: deployment target, `Info.plist` usage descriptions for every
  permission, privacy manifest (`PrivacyInfo.xcprivacy`) up to date.

## 4. Builds
```sh
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols [--flavor prod -t lib/main_prod.dart]
flutter build ipa --release --obfuscate --split-debug-info=build/symbols [--flavor prod ...]
flutter build web --release
```
Keep `build/symbols` (upload to Crashlytics/Sentry) and never commit it.

## 5. Hand-off
Propose: the release commit (`chore(release): vX.Y.Z`), the tag `vX.Y.Z`,
and the store checklist (screenshots, release notes, staged rollout %).
Execute each only after approval.
