---
name: ci
description: Sets up, reviews or fixes CI for a Flutter project (GitHub Actions by default) - quality gate, generated-files check, per-platform builds, caching, SHA-pinned actions, minimal permissions, Dependabot. Use when asked to add, harden or repair a pipeline. Do not use to debug a test that also fails locally (use triage).
argument-hint: "['setup' | 'review' | 'fix <run-url>']"
---

# CI

## `setup`
1. Detect what exists (`.github/workflows`, `codemagic.yaml`, `bitrise.yml`,
   `fastlane/`). Extend the existing system; don't add a second one.
2. Start from `templates/flutter-ci.yml` (this skill's directory) and adapt:
   - Flutter version from the project's pin (`.fvmrc`) or
     `flutter-version-file: pubspec.yaml` (requires
     `environment: flutter:` in the pubspec).
   - If the project has a verify script, run it instead of separate steps.
   - Drop the codegen step if build_runner isn't used; add
     `flutter gen-l10n` if l10n output isn't generated on `pub get`.
   - Build jobs only for the platforms the project targets; iOS on
     `macos-latest` with `--no-codesign`.
3. Hardening: `permissions: contents: read` at top level, jobs elevate only
   what they need; actions pinned to commit SHAs with the tag in a comment
   (look up current SHAs with `gh api repos/<owner>/<action>/git/ref/tags/<tag>`);
   `persist-credentials: false`; `concurrency` to cancel superseded runs;
   `timeout-minutes` on every job.
4. Add `.github/dependabot.yml` for `github-actions` and `pub` ecosystems
   (weekly).
5. Secrets (signing, store credentials) only through repository secrets; list
   which ones the user must create. Never write their values.

## `review`
Check the hardening list above, cache usage, duplicated steps, missing
`git diff --exit-code` after codegen/format, flaky test patterns, and total
runtime. Report ranked findings.

## `fix <run-url>`
`gh run view <id> --log-failed | tail -n 80`, find the root cause, reproduce
locally when possible (same Flutter version), fix, and explain. Don't
"fix" by skipping steps or tests.
