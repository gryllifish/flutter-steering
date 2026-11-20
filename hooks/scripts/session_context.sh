#!/usr/bin/env bash
# SessionStart: in Dart/Flutter projects, injects a short stack summary so
# Claude follows the project's existing conventions from the first message.
# Stdout of a SessionStart hook is added to Claude's context.
source "$(dirname "$0")/lib.sh"
is_dart_project || exit 0

stack="$("$(dirname "$0")/../../skills/onboard/scripts/detect_stack.sh" --brief "$PROJECT_DIR" 2>/dev/null)"

cat <<EOF
[flutter-steering] Dart/Flutter project detected.
Stack: ${stack:-unknown (run the onboard skill)}
Follow the conventions this project already uses over any generic default. Load the \`flutter-steering:standards\` skill before writing or reviewing Dart code. Run the project's verify gate before declaring work done.
EOF
