---
name: verify
description: Definition of Done gate for Dart/Flutter projects (pub get, codegen, l10n, format, analyze, test) with token-cheap output. Uses the project's own gate when it has one. Use after any code change and before proposing a commit or declaring a task done.
argument-hint: "[--skip-codegen] [--no-test]"
---

# Verify

Run `scripts/verify.sh` from this skill's directory, passing the project root:

```sh
<skill-dir>/scripts/verify.sh [--skip-codegen] [--no-test] <project-root>
```

- If the project has its own gate (`scripts/verify.sh`, `melos run verify`,
  `make verify`), the script delegates to it. Otherwise it infers the steps
  (FVM, Flutter vs Dart, build_runner, gen-l10n) from the project.
- `--skip-codegen`: no annotated class, ARB or `.proto` changed since the last
  successful codegen. `--no-test`: quick loop while iterating; never for the
  final check.
- Output is one `✓`/`✗` line per step plus the tail of failures. Do not
  re-run the underlying commands to "see more" unless the tail is truly
  insufficient.

## On failure
1. Fix the root cause. Never edit generated files; fix the source and
   regenerate.
2. Never silence the analyzer (`// ignore:`, lowering lint severity, deleting
   tests) to get green. If an ignore is truly justified, add it on the line
   with a comment explaining why, and tell the user.
3. Re-run until green. Report the final status and anything you could not fix.

## What the script cannot check
Before saying "done", also confirm:
- New or changed logic has tests (see the `test` skill).
- No hardcoded user-facing strings, colors or sizes where the project has
  l10n and a theme.
- Layer rules and conventions of the project (its `CLAUDE.md` or the
  `standards` skill) still hold.
- If UI changed, it was checked visually (screenshot, golden or running app
  through the Dart MCP server).
