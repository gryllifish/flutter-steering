---
name: onboard
description: Get productive in an unfamiliar Flutter/Dart codebase in minutes. Detects the stack, maps architecture and conventions with the flutter-explorer agent, and can draft a project CLAUDE.md. Use when opening a new repo, at the start of a task in an unknown project, or when asked "how does this project work".
argument-hint: "[--write-claude-md]"
---

# Onboard

1. Run the stack detector (this skill's directory):
   `scripts/detect_stack.sh <project-root>`
2. Delegate the deep read to the `flutter-explorer` agent. Give it the
   detector output and the detector's absolute path. If the user mentioned a
   task, ask it to also map the area of the code that task touches.
3. Sanity check the environment, quickly and in parallel:
   - SDK: the pinned version (`.fvmrc`) vs installed (`flutter --version`).
   - `flutter pub get` succeeds.
   - Codegen outputs are up to date (`git status` clean after
     `dart run build_runner build --delete-conflicting-outputs`, only if
     build_runner is used and the user is fine with running it).
4. Present to the user: the explorer briefing (trimmed), environment status,
   and the 3 most useful next steps.

## `--write-claude-md`
If the project has no `CLAUDE.md` (or `AGENTS.md`), draft one, under 80
lines, from the briefing:
- one-paragraph project description;
- non-negotiable rules observed in the code (layers, state management,
  error handling, l10n, theming);
- exact commands (run, test, codegen, verify);
- a "read on demand" table pointing at the reference feature and docs.
Show it to the user before writing it. Never overwrite an existing one;
propose a diff instead.
