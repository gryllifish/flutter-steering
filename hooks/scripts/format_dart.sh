#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): formats the Dart file Claude just
# changed, so formatting never costs a turn, and records it for the Stop
# hook's analysis. Generated files are skipped.
source "$(dirname "$0")/lib.sh"

file="$(json .tool_input.file_path)"
[[ "$file" == *.dart && -f "$file" ]] || exit 0
is_generated "$file" && exit 0

dart_cmd format "$file" >/dev/null 2>&1
echo "$file" >>"$(touched_list)"
exit 0
