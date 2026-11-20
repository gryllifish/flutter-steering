---
name: review
description: Reviews Flutter/Dart changes (working tree, branch vs base, a PR or given files) for Flutter-specific correctness, state management, performance, accessibility, security and test gaps through the flutter-reviewer agent, beyond what the analyzer reports. Use before committing or opening a PR, or when asked to review Flutter code. Do not use for non-Dart code or a language-agnostic bug hunt (Claude Code's /code-review covers that).
argument-hint: "[base-branch | PR number | paths]"
---

# Review

1. Resolve the target:
   - no argument: uncommitted changes (`git diff HEAD` + untracked files); if
     clean, the current branch vs its base (`git merge-base HEAD origin/HEAD`).
   - a branch name: `<branch>...HEAD`.
   - a PR number: `gh pr diff <n>` (and `gh pr view <n>` for context).
   - paths: those files.
2. Run `git diff --stat` for the target to size it. For more than ~15 changed
   files, split by feature and give each part to its own `flutter-reviewer`
   agent in parallel.
3. Delegate to the `flutter-reviewer` agent with: the exact diff command, the
   project's conventions file(s) to respect, and anything the user said about
   intent.
4. Present the findings to the user ranked by severity, deduplicated, with
   `path:line` links. Do not apply fixes unless asked; offer to apply the
   blocker/major ones.
