# flutter-steering

[![CI](https://github.com/gryllifish/flutter-steering/actions/workflows/ci.yml/badge.svg)](https://github.com/gryllifish/flutter-steering/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A [Claude Code](https://claude.com/claude-code) plugin for working on Flutter
projects with an agent, built to sit next to the official
[Dart and Flutter plugin](https://github.com/flutter/agent-plugins). The
official plugin teaches Claude Flutter tasks (layouts, routing, tests, JSON,
localization) and provides the Dart MCP server. This one adds what a team
needs around those tasks: guardrails that keep the agent's diff clean,
getting a foreign codebase running, finding the cause of an error in a long
log, review, audits, and release workflows.

It doesn't impose a stack. On session start it reads the project's
pubspecs (Riverpod, Bloc, Provider, go_router, freezed, FVM, melos...) and
tells Claude to follow what the project already does. Outside a Flutter or
Dart project it stays quiet.

## Install

Both plugins, in Claude Code:

```
/plugin marketplace add flutter/agent-plugins
/plugin install dart-flutter@dart-flutter
/plugin marketplace add gryllifish/flutter-steering
/plugin install flutter-steering@flutter-steering
```

Or in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "dart-flutter": { "source": { "source": "github", "repo": "flutter/agent-plugins" } },
    "flutter-steering": { "source": { "source": "github", "repo": "gryllifish/flutter-steering" } }
  },
  "enabledPlugins": {
    "dart-flutter@dart-flutter": true,
    "flutter-steering@flutter-steering": true
  }
}
```

Requirements: `bash`, `jq` and a Dart SDK 3.9+ on `PATH`. Without `jq` the
hooks turn themselves off instead of blocking. flutter-steering works
without the official plugin, but then Claude has no analyzer, hot reload or
runtime-error MCP tools; the session-start hook points that out.

## How the two plugins split the work

| | Official `dart-flutter` | `flutter-steering` |
|---|---|---|
| Dart MCP server | analyzer, LSP, hot reload/restart, runtime errors, widget inspector, pub, pub.dev search | only the app lifecycle tools the official config leaves off: `list_devices`, `launch_app`, `get_app_logs`, `list_running_apps`, `stop_app` |
| Skills | how to do Flutter tasks: `flutter-fix-layout-issues`, `flutter-add-widget-test`, `flutter-setup-declarative-routing`, `flutter-apply-architecture-best-practices`... | how to work in a codebase: onboarding, verify gate, triage, review, audits, dependencies, CI, release |
| Always-on rules | none in Claude Code (plugin rules aren't loaded; the docs say to copy them into `CLAUDE.md`) | injected by the `SessionStart` hook: stack summary, project-first rule, baseline before changes, hot reload after `lib/` edits, no commits without approval |
| Hooks and agents | none | guardrail hooks and three agents (below) |

The two MCP configurations expose disjoint tool sets, so nothing is
duplicated. That is deliberate: Claude Code has no reliable way to
persistently disable one MCP server inside a plugin.

## What's inside

### Skills
Invoked as `/flutter-steering:<name>`, or loaded by Claude when the task
matches the description. Every description says when **not** to use the
skill, pointing to the official skill or Claude Code built-in that fits
better. `release` and `commit` are manual-only because they have side effects.

| Skill | What it does |
|---|---|
| `standards` | Only what changes the agent's defaults: the project wins, on-task diffs in foreign code, and a table of deprecated APIs agents still generate (`withOpacity`, `WillPopScope`, `MaterialState`, Riverpod 3, freezed 3, go_router 10...). |
| `onboard` | Detects the stack, checks the project can build here (SDK constraints and pins, codegen outputs, env/define files, flavors, Firebase config), maps the codebase through `flutter-explorer`, can draft a project `CLAUDE.md`. |
| `verify` | Definition of Done gate. Runs the project's own gate if it has one, otherwise infers the steps (FVM, codegen, l10n, format, analyze, test). Prints only failures. |
| `triage` | Root cause of an error from any log: `flutter run`/`test`, logcat, iOS simulator, Gradle, Xcode, CocoaPods, pub, analyzer, CI. A Dart extractor turns a 200-line log into the distinct errors with only the project's own frames; then the skill traces it to the code and proves the fix. |
| `feature` | Builds a feature end to end by mirroring the project's most complete feature: plan first, verify gate last. |
| `review` | Flutter-specific review of a diff, branch or PR through `flutter-reviewer`, beyond what the analyzer reports. |
| `perf-audit` | Static scan for rebuild, list, image and isolate problems, plus profiling, app size and startup guidance. |
| `a11y-audit` | Semantics, tap targets, contrast, text scaling, focus, and `meetsGuideline` tests. |
| `l10n-audit` | Hardcoded strings, ARB key and placeholder parity across locales, RTL-unsafe layout. |
| `deps` | Evaluates a package before adding it (with approval), upgrades in small verified steps, migrates the Flutter SDK. |
| `ci` | Sets up or reviews GitHub Actions: pinned actions, minimal permissions, generated-files check, Dependabot. |
| `release` | Version bump, changelog from Conventional Commits, pre-release checks, obfuscated builds. |
| `commit` | Proposes atomic Conventional Commits and commits only after approval. |

### Agents
They run in their own context, so a large review or a codebase walk doesn't
fill up the main conversation.

| Agent | Tools | Role |
|---|---|---|
| `flutter-explorer` | read-only | Maps a codebase: architecture, one feature traced end to end, conventions, commands, risks. |
| `flutter-reviewer` | read-only | Findings ranked by severity with `path:line` and a concrete fix. Leaves to the analyzer what the analyzer catches, and checks that new tests would fail if the fix were reverted. |
| `flutter-test-writer` | read/write | Writes tests in the project's style and runs them until they pass. Reports production bugs instead of bending tests around them. |

### Hooks
Rules that must hold every time are hooks, not instructions.

| Event | Hook |
|---|---|
| `SessionStart` | Adds the stack summary and the session rules above. Suggests the official plugin if it isn't enabled. |
| `PreToolUse` | Denies edits to generated files (`*.g.dart`, `*.freezed.dart`, files with a generated header...) and points to the generator. |
| `PreToolUse` | Denies access to secrets (`.env`, keystores, `key.properties`, service accounts, `.p8`); build tools may still reference them (`flutter run --dart-define-from-file=.env`). Asks before force push, hard reset, `git clean`, broad `rm -rf` and `pub publish`. |
| `PostToolUse` | Runs `dart format` on each Dart file Claude edits, unless the committed version wasn't formatted: in a codebase that doesn't use `dart format`, a one-line edit stays a one-line diff. |
| `Stop` | Runs `dart analyze` on the files touched in the session. Issues on lines Claude changed block the turn once and go back to Claude; pre-existing issues elsewhere are mentioned, never forced. |

## Design notes

- **Complement, don't duplicate.** Where the Flutter team ships a skill, this
  plugin points to it instead of carrying its own.
- **Only information the model doesn't have.** Following the Flutter team's
  [guidance for skills](https://github.com/flutter/flutter/tree/main/.agents/skills)
  ("tell the agent what it needs to know, not what it already knows"),
  general best practice is left out; what remains is project-first behavior,
  deprecated APIs and checkable procedures.
- **Small footprint in someone else's code.** No reformatting of files the
  team doesn't format, no blocking on lint debt Claude didn't create, no
  drive-by refactors. The diff should contain the task and nothing else.
- **Deterministic where possible.** Formatting, analysis, generated files
  and secrets are enforced by hooks, which don't depend on the model
  remembering a rule.
- **Cheap on context.** Skill bodies load only when used; scripts print
  compact output (`✓`/`✗` per step, distinct errors only).
- **Nothing outward-facing without approval.** Adding dependencies,
  committing, pushing, tagging and publishing all stop for confirmation.
- **Portable scripts.** Hooks run on the bash 3.2 that ships with macOS and
  fail open if a prerequisite is missing; the log extractor is Dart with no
  dependencies.

## Workflows
[docs/workflows.md](docs/workflows.md) has walkthroughs for joining an
existing codebase, building a feature from scratch and getting a change
ready for review.

## Development

```sh
for t in tests/*_test.sh; do "$t"; done   # hooks, triage extractor, l10n scripts
dart pub global run skills_lint --skills-directory skills \
  --check-relative-paths --check-trailing-whitespace --no-disallowed-field
```

CI also runs shellcheck and `dart analyze` on the scripts. To try local
changes, add the clone as a marketplace:
`/plugin marketplace add /path/to/flutter-steering`.

## License
[MIT](LICENSE)
