#!/usr/bin/env bash
# Shared helpers for flutter-steering hooks. Sourced by every hook script.
#
# Design rules:
# - Compatible with the bash 3.2 that ships with macOS (no mapfile, no
#   associative arrays, no `set -u` because empty arrays trip it).
# - Fail open: if a prerequisite is missing, hooks do nothing instead of
#   blocking the session.
# - Only act inside Dart/Flutter projects, so the plugin can be installed
#   globally without side effects elsewhere.

set -o pipefail

command -v jq >/dev/null 2>&1 || exit 0

HOOK_INPUT="$(cat)"

# Reads a field from the hook's JSON input; prints nothing when absent.
json() { jq -r "$1 // empty" <<<"$HOOK_INPUT"; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(json .cwd)}"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"

# True when the project root, or a package up to three levels down
# (monorepos, `app/` subfolders), has a pubspec.yaml.
is_dart_project() {
  [[ -f "$PROJECT_DIR/pubspec.yaml" ]] && return 0
  [[ -n "$(find "$PROJECT_DIR" -maxdepth 3 -name pubspec.yaml \
    -not -path '*/.dart_tool/*' -not -path '*/build/*' \
    -not -path '*/node_modules/*' -print -quit 2>/dev/null)" ]]
}

# Uses the project's pinned SDK through FVM when the project pins one.
dart_cmd() {
  if [[ -f "$PROJECT_DIR/.fvmrc" || -f "$PROJECT_DIR/.fvm/fvm_config.json" ]] &&
    command -v fvm >/dev/null 2>&1; then
    (cd "$PROJECT_DIR" && fvm dart "$@")
  else
    (cd "$PROJECT_DIR" && dart "$@")
  fi
}

# Files produced by code generators. They must be regenerated, never edited.
is_generated() {
  local file="$1"
  case "$file" in
    *.g.dart | *.freezed.dart | *.mocks.dart | *.gr.dart | *.config.dart | \
      *.gen.dart | *.pb.dart | *.pbenum.dart | *.pbjson.dart | \
      *.pbserver.dart | */generated/*.dart | */.dart_tool/*)
      return 0 ;;
  esac
  [[ "$file" == *.dart && -f "$file" ]] &&
    head -n 5 "$file" | grep -qiE 'GENERATED CODE|DO NOT (EDIT|MODIFY)|Generated file'
}

# Files that hold credentials or signing material.
is_secret() {
  local name
  name="$(basename -- "$1")"
  case "$name" in
    .env.example | .env.sample | .env.template | .env.dist) return 1 ;;
    .env | .env.* | *.env | key.properties | *.jks | *.keystore | *.p12 | \
      *.p8 | *.pem | *.mobileprovision | service-account*.json | \
      *serviceAccount*.json | *-credentials.json | credentials.json)
      return 0 ;;
  esac
  return 1
}

# Per-session list of Dart files Claude touched, used by the Stop hook.
touched_list() {
  local session
  session="$(json .session_id)"
  echo "${TMPDIR:-/tmp}/flutter-steering-${session:-default}.touched"
}

# PreToolUse decisions (JSON on stdout, exit 0).
pre_tool_decision() {
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}
deny() { pre_tool_decision deny "$1"; }
ask() { pre_tool_decision ask "$1"; }
