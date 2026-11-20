#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): formats the Dart file Claude just
# changed, so formatting never costs a turn, and records it for the Stop
# hook's analysis. Generated files are skipped.
#
# Files whose committed version is not dart-formatted are left alone: in a
# codebase that doesn't use `dart format` (or pins another formatter
# version), a one-line edit must not turn into a whole-file diff.
source "$(dirname "$0")/lib.sh"

file="$(json .tool_input.file_path)"
[[ "$file" == *.dart && -f "$file" ]] || exit 0
is_generated "$file" && exit 0

# True for new/untracked files, or when the HEAD version is already formatted.
committed_version_formatted() {
  local rel
  rel="$(git -C "$PROJECT_DIR" ls-files --full-name -- "$file" 2>/dev/null | head -n 1)"
  [[ -n "$rel" ]] || return 0
  git -C "$PROJECT_DIR" cat-file -e "HEAD:$rel" 2>/dev/null || return 0
  git -C "$PROJECT_DIR" show "HEAD:$rel" |
    dart_cmd format --output=none --set-exit-if-changed --stdin-name="$file" >/dev/null 2>&1
}

committed_version_formatted && dart_cmd format "$file" >/dev/null 2>&1
echo "$file" >>"$(touched_list)"
exit 0
