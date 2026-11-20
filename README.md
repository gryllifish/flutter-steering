# flutter-steering

[![CI](https://github.com/gryllifish/flutter-steering/actions/workflows/ci.yml/badge.svg)](https://github.com/gryllifish/flutter-steering/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A [Claude Code](https://claude.com/claude-code) plugin with the workflow I
use for Flutter work: engineering standards, three specialized agents,
audits, dependency and release workflows, guardrail hooks and the Dart &
Flutter MCP server. It is installed once and works in any Flutter or Dart
project; outside of one, it stays quiet.

It doesn't impose a stack. On session start it reads the project's
pubspecs (Riverpod, Bloc, Provider, go_router, freezed, FVM, melos...) and
tells Claude to follow what the project already does. My preferred defaults
(Riverpod with codegen, go_router, freezed) only apply to new projects.

## Install

In Claude Code:

```
/plugin marketplace add gryllifish/flutter-steering
/plugin install flutter-steering@flutter-steering
```

Or in `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "flutter-steering": {
      "source": { "source": "github", "repo": "gryllifish/flutter-steering" }
    }
  },
  "enabledPlugins": { "flutter-steering@flutter-steering": true }
}
```

Requirements: `bash`, `jq` and a Dart SDK (3.9+ for the MCP server) on
`PATH`. Without `jq` the hooks turn themselves off instead of blocking.

## What's inside

### Skills
Invoked as `/flutter-steering:<name>`. Claude also loads them by itself when
the task matches their description; only `release` and `commit` are
manual-only because they have side effects.

| Skill | What it does |
|---|---|
| `standards` | Architecture, state management (Riverpod, Bloc, Provider), widgets and error-handling rules. Short entry point, details read on demand. |
| `onboard` | Detects the stack, checks the project can build here (SDK constraints and pins, codegen outputs, env/define files, flavors, Firebase config), maps the codebase through `flutter-explorer`, can draft a project `CLAUDE.md`. |
| `verify` | Definition of Done gate. Runs the project's own gate if it has one, otherwise infers the steps (FVM, codegen, l10n, format, analyze, test). Prints only failures. |
| `feature` | Builds a feature end to end, using the project's most complete feature as the template. |
| `test` | Unit, widget, golden, bloc/provider and accessibility tests in the project's style. |
| `review` | Reviews a diff, branch or PR through `flutter-reviewer`. |
| `triage` | Root cause of an error from any log: `flutter run`/`test`, logcat, iOS simulator, Gradle, Xcode, CocoaPods, pub, analyzer, CI. A Dart extractor turns a 200-line log into the distinct errors with only the project's own frames; then the skill traces it to the code and proves the fix. |
| `perf-audit` | Static scan for rebuild, list, image and isolate problems, plus profiling, app size and startup guidance. |
| `a11y-audit` | Semantics, tap targets, contrast, text scaling, focus, and guideline tests (`meetsGuideline`). |
| `l10n` | Adds strings to every locale, finds hardcoded strings, checks ARB parity and RTL. gen-l10n, slang or easy_localization. |
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
| `flutter-reviewer` | read-only | Findings ranked by severity with `path:line` and a concrete fix. Verifies each claim before reporting it. |
| `flutter-test-writer` | read/write | Writes tests in the project's style and runs them until they pass. Reports production bugs instead of bending tests around them. |

### Hooks
Rules that should hold every time are hooks, not instructions.

| Event | Hook |
|---|---|
| `SessionStart` | Adds a one-line stack summary to the context, so conventions are known from the first message. |
| `PreToolUse` | Denies edits to generated files (`*.g.dart`, `*.freezed.dart`, files with a generated header...) and points to the generator. |
| `PreToolUse` | Denies access to secrets (`.env`, keystores, `key.properties`, service accounts, `.p8`); build tools may still reference them (`flutter run --dart-define-from-file=.env`). Asks before force push, hard reset, `git clean`, broad `rm -rf` and `pub publish`. |
| `PostToolUse` | Runs `dart format` on each Dart file Claude edits, unless the committed version wasn't formatted: in a codebase that doesn't use `dart format`, a one-line edit stays a one-line diff. |
| `Stop` | Runs `dart analyze` on the files touched in the session. Issues on lines Claude changed block the turn once and go back to Claude; pre-existing issues elsewhere are mentioned, never forced. |

### MCP
`.mcp.json` registers the official Dart & Flutter MCP server
(`dart mcp-server`) with app lifecycle tools enabled: analyzer, pub.dev
search, listing devices, launching and stopping the app, its logs and
runtime errors, widget tree and hot reload.

## Design notes

- **Project conventions win.** Every skill starts by finding the closest
  existing example in the project. The plugin fills gaps; it doesn't
  rewrite a codebase into my preferences.
- **Small footprint in someone else's code.** No reformatting of files the
  team doesn't format, no blocking on lint debt Claude didn't create, no
  drive-by refactors. The diff should contain the task and nothing else.
- **Cheap on context.** Skill descriptions are always loaded; bodies only
  when used; reference files only when a skill needs them. Scripts print
  compact output (`✓`/`✗` per step, tails of failures) so results don't
  burn tokens.
- **Deterministic where possible.** Formatting, analysis, generated files
  and secrets are enforced by hooks, which don't depend on the model
  remembering a rule.
- **Nothing outward-facing without approval.** Adding dependencies,
  committing, pushing, tagging and publishing all stop for confirmation.
- **Layered.** Personal preferences in `~/.claude/CLAUDE.md`, Flutter
  practice in this plugin, project rules in each repo's `CLAUDE.md`.
- **Portable scripts.** Hooks run on the bash 3.2 that ships with macOS and
  fail open if a prerequisite is missing.

## Workflows
[docs/workflows.md](docs/workflows.md) has walkthroughs for joining an
existing codebase, building a feature from scratch and getting a change
ready for review.

## Development

```sh
tests/hooks_test.sh    # hook test suite (needs jq and dart)
tests/triage_test.sh   # log extractor against real and synthetic logs
```

To try local changes, add the clone as a marketplace:
`/plugin marketplace add /path/to/flutter-steering`.

## License
[MIT](LICENSE)
