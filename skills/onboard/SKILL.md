---
name: onboard
description: Gets productive in an unfamiliar Flutter/Dart codebase in minutes - detects the stack, checks the project can build on this machine (SDK constraints, codegen, env files, flavors), maps architecture and conventions with the flutter-explorer agent, and can draft a project CLAUDE.md. Use when opening a new repo or starting a task in an unknown project. Do not use in a project already mapped in this session.
argument-hint: "[--write-claude-md]"
---

# Onboard

1. In parallel, from this skill's directory:
   - `scripts/detect_stack.sh <project-root>`: stack inventory.
   - `scripts/env_check.sh <project-root>`: readiness to build and run
     (SDK vs pins and CI, pub get, codegen outputs committed or not, l10n,
     env/define files, flavors, Firebase config). Read-only.
2. Delegate the deep read to the `flutter-explorer` agent. Give it the
   detector output and the detector's absolute path. If the user mentioned a
   task, ask it to also map the area of the code that task touches.
3. Get the project runnable, asking before each step that changes the
   working tree or installs something (`fvm install`, `pub get`,
   build_runner, creating env files from templates). Missing secrets or
   config: tell the user what to request from the team; never invent values.
4. Present to the user: the explorer briefing (trimmed), environment status
   (`⚠` items first), and the 3 most useful next steps.

## Then
Work by the `standards` skill, sections 1 and 2 (the project wins; diffs stay
on-task in someone else's code). Before the first change, run the `verify`
skill once so you know the baseline.

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
