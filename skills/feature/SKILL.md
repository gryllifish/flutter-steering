---
name: feature
description: Builds a new Flutter feature end to end (model, data, repository, state, UI, tests) by mirroring the project's most complete existing feature, with a plan first and the verify gate last. Use when asked to add a feature, a screen backed by data, or a new module. Do not use for one-file changes or bug fixes (use triage for bugs), or to choose an architecture for a new project (the official flutter-apply-architecture-best-practices skill covers that).
argument-hint: "<feature-name> [short description]"
---

# Feature

## 1. Align before coding
- If the project has its own scaffolding (a project `new-feature` skill,
  mason bricks in `bricks/`, very_good templates), use it and stop here.
- Find the **reference feature**: the most complete existing one with data,
  state, UI and tests. Its structure is the template.
- If requirements are ambiguous (data source, states, navigation entry point,
  offline behavior), ask before writing code. Few, concrete questions.
- No reference feature (new project): use the official
  `flutter-apply-architecture-best-practices` skill, and state the stack you
  chose and why.

## 2. Plan
For anything beyond a trivial feature, show the file list mirroring the
reference feature, plus route registration, DI/provider wiring, l10n keys in
every locale, and any fake data source the project uses. Wait for the user's
go-ahead.

## 3. Build bottom-up
domain → data → state → UI. Run codegen once after the annotated files are
in place, not after every file. The UI renders every state: loading, empty,
error with retry, data.

## 4. Test and verify
- Tests for domain rules, DTO mapping, repository error mapping, state
  transitions, and one widget test per screen state, in the project's test
  style (official `flutter-add-widget-test` / `dart-add-unit-test`, or the
  `flutter-test-writer` agent for a whole feature).
- Run the `verify` skill until green.
- If the UI is visible, look at it: golden, screenshot, or the running app
  (hot reload through the Dart MCP server).

## 5. Report
What was built (files grouped by layer), decisions and why, and what was
intentionally left out.
