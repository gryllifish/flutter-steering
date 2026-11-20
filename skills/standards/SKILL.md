---
name: standards
description: Senior Flutter/Dart engineering standards (architecture, state management, error handling, widgets, testing, style) that adapt to the project's existing stack. Use before writing, refactoring or reviewing Dart/Flutter code, or when unsure how something should be structured.
---

# Flutter engineering standards

## Rule zero: the project wins
These are defaults for gaps, not a rewrite mandate. Before writing code:
1. Read the project's `CLAUDE.md` / `AGENTS.md` / steering docs if present.
2. Know the stack: the SessionStart context line, or run
   `../onboard/scripts/detect_stack.sh <project-root>` (relative to this
   skill's directory).
3. Find the closest existing example (a similar feature, widget or test) and
   mirror it: naming, folders, state management, error handling, test style.

Introduce a new pattern only when the project has none for the problem, and
say so explicitly. Never mix a second state-management library into a project.

## Non-negotiables (any stack)
- **Layers with one-way dependencies:** UI → state (controllers/blocs/
  notifiers) → domain ← data. Domain is pure Dart (no Flutter, no packages
  with I/O). Widgets never call repositories, HTTP or storage directly.
- **Widgets render state and forward events.** No business rules, parsing or
  data fetching in `build`. Ephemeral UI state (animation, focus, text
  controllers, tab index) may live in a `StatefulWidget`.
- **Typed errors, no silent failures.** Data layer converts exceptions into
  domain failures (sealed classes/Result). No empty `catch`, no `catch (e)`
  without logging or rethrow, no raw exception messages shown to users.
- **Immutability:** immutable models (freezed/equatable/records), `final`
  and `const` everywhere possible, collections not mutated in place.
- **Null safety used honestly:** no `!` without a proven invariant, no `late`
  for things that might not be initialized, no `dynamic` unless crossing a
  JSON boundary (and then parsed immediately into types).
- **Async correctness:** check `mounted` / `context.mounted` after `await`
  before using `context`; cancel subscriptions, timers and controllers in
  `dispose`; never fire-and-forget a Future that can fail (`unawaited` only
  with a reason).
- **No hardcoded UI values when the project has a system for them:** strings
  via l10n, colors/typography from `Theme`/design tokens, spacing and
  durations from constants.
- **Zero analyzer issues.** Respect the configured lints; don't add
  `// ignore` to get green.
- **No `print`;** use the project's logger.
- **Dependencies:** ask the user before adding one; justify it (see the `deps`
  skill).

## Read on demand
| When | Read (relative to this skill) |
|---|---|
| Structuring a feature, repository, error handling, DI | `references/architecture.md` |
| Writing state management code (Riverpod, Bloc, Provider, others) | `references/state-management.md` |
| Building widgets, layouts, theming, animations | `references/widgets.md` |
| Writing any test | `../test/references/testing.md` |
| Performance concerns | `../perf-audit/SKILL.md` |
| Accessibility concerns | `../a11y-audit/SKILL.md` |
