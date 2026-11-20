#!/usr/bin/env bash
# SessionStart: in Dart/Flutter projects, injects the stack summary and the
# few session rules that must hold from the first message. Stdout of a
# SessionStart hook is added to Claude's context. Plugins can't ship
# always-on rules otherwise (Claude Code doesn't load plugin rule files), so
# this is kept short: every line costs context in every session.
source "$(dirname "$0")/lib.sh"
is_dart_project || exit 0

stack="$("$(dirname "$0")/../../skills/onboard/scripts/detect_stack.sh" --brief "$PROJECT_DIR" 2>/dev/null)"

cat <<EOF
[flutter-steering] Dart/Flutter project detected.
Stack: ${stack:-unknown (run the onboard skill)}
- Follow this project's conventions over any default. Load the \`flutter-steering:standards\` skill before writing Dart (it lists deprecated APIs to avoid).
- Know the baseline before changing code: if not done yet this session, run the verify gate once so later failures are attributable.
- After editing Dart under lib/ while the app runs, hot reload through the Dart MCP server; hot restart if main(), initState or app-level state initialization changed. Skip for test-only, comment-only or formatting edits.
- Never commit or push without the user's approval.
EOF

# The official Dart & Flutter plugin provides the main Dart MCP tools
# (analyzer, hot reload, runtime errors, widget inspector) and task skills;
# this plugin only adds app lifecycle tools on top. Point it out if missing.
official_enabled=false
for settings in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" \
  "$PROJECT_DIR/.claude/settings.json" "$PROJECT_DIR/.claude/settings.local.json"; do
  if grep -qE '"dart-flutter@[^"]*"[[:space:]]*:[[:space:]]*true' "$settings" 2>/dev/null; then
    official_enabled=true
  fi
done
if ! $official_enabled; then
  echo "- The official dart-flutter plugin is not enabled, so analyzer/hot reload MCP tools and the official flutter-*/dart-* skills are missing. If the task needs them, tell the user once: \`/plugin marketplace add flutter/agent-plugins\` then \`/plugin install dart-flutter@dart-flutter\`."
fi
exit 0
