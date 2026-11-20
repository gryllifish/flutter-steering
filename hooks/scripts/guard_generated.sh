#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|NotebookEdit): blocks hand edits to
# generated Dart files and points Claude to the source + generator instead.
source "$(dirname "$0")/lib.sh"

file="$(json .tool_input.file_path)"
[[ -n "$file" ]] || exit 0
is_generated "$file" || exit 0

deny "$(basename "$file") is generated code. Edit its source instead (the annotated class, ARB file, .proto, asset folder...) and regenerate: \`dart run build_runner build --delete-conflicting-outputs\` for build_runner outputs, \`flutter gen-l10n\` for localizations."
