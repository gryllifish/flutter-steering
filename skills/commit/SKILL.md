---
name: commit
description: Propose atomic Conventional Commits for the current changes and create them only after the user approves. Use when the user asks to commit or to prepare commit messages.
disable-model-invocation: true
---

# Commit

If the project has its own commit skill or rules (`CONTRIBUTING.md`,
commitlint config, git-workflow docs), they take precedence.

1. `git status --short` and `git diff --stat`; open specific diffs only when
   the stat is not enough.
2. Group changes into small, atomic commits with one purpose each. Generated
   files go in the same commit as the source change that produced them.
   Tests go with the code they test.
3. Propose the plan as a list: `<type>(<scope>): <description>` + files.
   Types: feat, fix, refactor, perf, test, docs, style, build, ci, chore.
   Imperative, lowercase, no trailing period, ≤ 72 chars; scope = feature or
   area; `!` + `BREAKING CHANGE:` footer for breaking changes; body when the
   *why* isn't obvious.
4. **Wait for explicit approval.** Never commit or push without it.
5. Run the `verify` skill before the first commit (`--skip-codegen` if
   codegen already passed); stop if it fails.
6. `git add <files>` (never `git add -A` blindly) + `git commit`. Append any
   attribution trailer the session requires.
7. Show `git log --oneline -n <count>`. Don't push unless asked.
