---
name: onboard
description: Get productive in an unfamiliar Flutter/Dart codebase in minutes. Detects the stack, maps architecture and conventions with the flutter-explorer agent, and can draft a project CLAUDE.md. Use when opening a new repo, at the start of a task in an unknown project, or when asked "how does this project work".
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

## Working in someone else's codebase
- Their conventions over this plugin's defaults, always. If something looks
  wrong, say so and ask; don't "fix" it as a side effect of the task.
- Keep diffs minimal and on-task: no drive-by refactors, renames,
  reformatting or lint cleanups outside the lines the task touches (the
  hooks already avoid reformatting unformatted files and only block on
  issues in changed lines).
- State the plan before editing, and the assumptions it relies on.

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
