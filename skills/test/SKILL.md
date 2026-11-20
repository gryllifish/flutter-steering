---
name: test
description: Write or improve Flutter/Dart tests (unit, widget, golden, integration, accessibility) following the project's existing test style. Use when adding tests for new or changed code, when coverage is missing, or when a bug needs a regression test.
argument-hint: "[file, feature or 'changed']"
---

# Test

## Scope
- Argument is a file or feature: test that.
- `changed` or no argument: the Dart files changed vs the base branch
  (`git diff --name-only $(git merge-base HEAD origin/HEAD 2>/dev/null || echo HEAD) -- '*.dart'`
  plus untracked files), excluding generated files.

## Steps
1. Read `references/testing.md` (this skill's directory) and 1–2 existing
   tests in the project of the same kind; the project's style wins.
2. For a bug: write the failing regression test first, confirm it fails,
   then fix.
3. For substantial work (several files or a whole feature), delegate to the
   `flutter-test-writer` agent with the list of files and the test style you
   found; it works in its own context and reports back.
4. Run only the affected tests while iterating:
   `flutter test --no-pub --reporter failures-only <paths>`.
5. Finish with the `verify` skill.

## Report
List what is now covered (behaviors, not files) and any gap you
deliberately left, with the reason.
