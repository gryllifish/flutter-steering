# Workflows

How the pieces fit together in three common situations. Prompts are
examples; plain language works because skills trigger on their
descriptions.

## 1. Joining an existing codebase

Goal: understand the project well enough to change it safely, fast.

1. Open the repo. The `SessionStart` hook already adds the stack line to the
   context (for example `Flutter app; state=Bloc; routing=go_router;
   models=freezed; tests=mocktail`).
2. `/flutter-steering:onboard`: stack report plus a readiness check that
   catches the usual first-hour blockers: an SDK older than the pubspec
   requires, a pinned FVM version not installed, codegen outputs not
   committed, a missing `.env` or `--dart-define-from-file` input, flavors,
   missing Firebase config. Then `flutter-explorer` traces one feature end
   to end and returns conventions, commands, risks and open questions.
   With `--write-claude-md` it drafts a project `CLAUDE.md` for review.
3. Get it running, approving each step that installs or generates
   something. Ask the team for secrets; the agent never reads or invents
   them.
4. Before a task in an unknown area, ask to map just that area ("how does
   checkout get its prices?"); the explorer answers with `path:line`
   references.
5. Make the change following the closest existing example
   (`standards` → rule zero). Hooks format and analyze as you go, without
   touching code outside the task: files the team doesn't format stay
   unformatted, and pre-existing lint issues are reported, not fixed.
6. `/flutter-steering:verify` (it uses the project's own gate if there is
   one), then `/flutter-steering:review`.

What this shows: reading before writing, respecting existing decisions, and
checking the result.

## 2. Building a feature from scratch

1. Clarify scope: states (loading, empty, error, data), data source,
   navigation entry point. `feature` asks if something is ambiguous.
2. `/flutter-steering:feature payments "list of payments with 30-day total"`:
   plan first (files per layer), then bottom-up: domain → data → state → UI.
3. Tests: the official `flutter-add-widget-test` / `dart-add-unit-test`
   skills for individual tests, or let `flutter-test-writer` cover a whole
   feature in parallel while you review the UI.
4. Quality passes as needed: `l10n-audit`, `a11y-audit`, `perf-audit` on the
   new screens.
5. `verify` → `review` → `commit` (proposes atomic commits, waits for
   approval).

## 3. Getting a change ready for review

1. `/flutter-steering:review`: findings ranked blocker → nit with fixes.
2. Fix blockers and majors; add missing tests for the changed files
   (`flutter-test-writer`).
3. `/flutter-steering:verify` until green.
4. `/flutter-steering:commit`, then open the PR with a description of the
   why, screenshots for UI changes, and how it was tested.

## Other entry points

| Situation | Use |
|---|---|
| Crash, red screen, failing build or test | `triage` with the log, the failing command, `device` or a CI run: first error, project frames only, then fix with a regression test |
| App feels janky | `perf-audit`, then profile mode + DevTools (or the MCP server's inspector) |
| Adding a package | `deps add <pkg>`: evaluation table, alternatives, waits for approval |
| Flutter upgrade | `deps sdk <version>`: breaking changes that affect this code, pins, CI, native |
| New pipeline or failing CI | `ci setup` / `ci fix <run-url>` |
| Shipping | `release minor`: version, changelog, checks, builds; each outward step needs approval |
