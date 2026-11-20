---
name: feature
description: Build a new Flutter feature end to end (model → data → repository → state → UI → tests) following the project's existing architecture and stack. Use when asked to add a feature, a screen backed by data, or a new module.
argument-hint: "<feature-name> [short description]"
---

# Feature

## 1. Align before coding
- If the project has its own scaffold skill or templates (e.g. a project
  `new-feature` skill, mason bricks in `bricks/`, `very_good` templates), use
  those instead and stop here.
- Find the **reference feature**: the most complete existing feature with
  data + state + UI + tests. Its structure is the template.
- If requirements are ambiguous (data source, states, navigation entry
  point, offline behavior), ask before writing code. Keep questions few and
  concrete.
- New project with no reference: use `../standards/references/architecture.md`
  and the default stack (Riverpod codegen, go_router, freezed), stated to
  the user.

## 2. Plan (show the user for anything beyond a trivial feature)
File list mirroring the reference feature, e.g.:
```
features/<name>/domain/<entity>.dart, <name>_repository.dart
features/<name>/data/<entity>_dto.dart, <name>_remote_data_source.dart, <name>_repository_impl.dart
features/<name>/application/<name>_controller.dart      (or bloc/cubit)
features/<name>/presentation/<name>_screen.dart, widgets/...
test/features/<name>/... mirroring each logic file
```
Plus: route registration, DI/provider wiring, l10n keys (all locales), and
any fake/mock data source the project uses for demos.

## 3. Build bottom-up
domain → data → state → UI. After codegen-affecting files, run build_runner
once (not after every file). UI renders every state: loading, empty, error
with retry, data.

## 4. Test and verify
- Tests for domain rules, DTO mapping, repository error mapping, state
  transitions, and a widget test per screen state (use the `test` skill or
  the `flutter-test-writer` agent for larger features).
- Run the `verify` skill until green.
- If the UI is visible, check it: golden, screenshot skill, or launch it
  through the Dart MCP server and take a look.

## 5. Report
What was built (files grouped by layer), decisions taken and why, and what
was intentionally left out.
