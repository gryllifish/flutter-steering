#!/usr/bin/env bash
# Tests for the hook scripts: feeds hook JSON on stdin inside a throwaway
# Dart project and asserts on the decision, exit code and side effects.
#
# Usage: tests/hooks_test.sh        (requires bash, jq and dart on PATH)
set -o pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
hooks="$root/hooks/scripts"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

project="$tmp/app"
mkdir -p "$project/lib"
cat >"$project/pubspec.yaml" <<'EOF'
name: sample
environment:
  sdk: ^3.5.0
dependencies:
  flutter_bloc: ^9.0.0
  go_router: ^16.0.0
dev_dependencies:
  mocktail: ^1.0.0
EOF
mkdir -p "$tmp/not_dart"

export TMPDIR="$tmp"
# Hermetic: never read the real user settings.
export CLAUDE_CONFIG_DIR="$tmp/claude-config"
mkdir -p "$CLAUDE_CONFIG_DIR"
passed=0
failed=0

# run <hook> <project_dir> <json> → sets $out and $code
run() {
  out="$(CLAUDE_PROJECT_DIR="$2" "$hooks/$1" <<<"$3" 2>&1)"
  code=$?
}
decision() {
  local input="$out"
  [[ -n "$input" ]] || input='{}'
  jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$input" 2>/dev/null || echo invalid-output
}
check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "✗ $name: expected '$expected', got '$actual'"
    [[ -n "$out" ]] && head -n 5 <<<"$out" | sed 's/^/    /'
  fi
}
tool() { jq -nc --arg t "$1" --arg k "$2" --arg v "$3" '{session_id: "s1", tool_name: $t, tool_input: {($k): $v}}'; }

# guard_generated
run guard_generated.sh "$project" "$(tool Edit file_path "$project/lib/model.g.dart")"
check "generated: .g.dart denied" deny "$(decision)"
run guard_generated.sh "$project" "$(tool Write file_path "$project/lib/model.freezed.dart")"
check "generated: .freezed.dart denied" deny "$(decision)"
printf '// GENERATED CODE - DO NOT MODIFY BY HAND\nclass A {}\n' >"$project/lib/app_localizations.dart"
run guard_generated.sh "$project" "$(tool Edit file_path "$project/lib/app_localizations.dart")"
check "generated: header detected" deny "$(decision)"
run guard_generated.sh "$project" "$(tool Edit file_path "$project/lib/model.dart")"
check "generated: regular file allowed" none "$(decision)"

# guard_secrets: files
for f in .env .env.production android/key.properties upload.jks AuthKey_X.p8 service-account.json; do
  run guard_secrets.sh "$project" "$(tool Read file_path "$project/$f")"
  check "secrets: read $f denied" deny "$(decision)"
done
for f in .env.example lib/env.dart pubspec.yaml; do
  run guard_secrets.sh "$project" "$(tool Read file_path "$project/$f")"
  check "secrets: read $f allowed" none "$(decision)"
done
run guard_secrets.sh "$project" "$(tool Grep path "$project/.env")"
check "secrets: grep in .env denied" deny "$(decision)"
run guard_secrets.sh "$tmp/not_dart" "$(tool Read file_path "$tmp/not_dart/.env")"
check "secrets: inactive outside Dart projects" none "$(decision)"

# guard_secrets: commands
while IFS='|' read -r expected cmd; do
  run guard_secrets.sh "$project" "$(tool Bash command "$cmd")"
  check "bash: $cmd" "$expected" "$(decision)"
done <<'EOF'
deny|cat .env
deny|grep API_KEY "android/key.properties"
deny|cp ~/keys/upload.jks android/app/
ask|git push --force origin main
ask|git push -f
none|git push --force-with-lease origin feature
ask|git reset --hard HEAD~1
ask|git clean -fd
ask|git checkout -- .
ask|git branch -D old
ask|rm -rf .
ask|rm -rf *
none|rm -rf build/
none|rm -rf ./build
ask|flutter pub publish
none|dart pub publish --dry-run
none|flutter run --dart-define-from-file=.env
none|fvm flutter build apk --dart-define-from-file=.env.production
none|cd android && ./gradlew assembleRelease
deny|flutter run --dart-define-from-file=.env && cat .env
deny|flutter test; head -n 3 .env.production
none|flutter test
none|git push origin main
EOF

# format_dart + analyze_on_stop
printf 'void main(){final unused=1;print("x");}\n' >"$project/lib/main.dart"
(cd "$project" && dart pub get >/dev/null 2>&1)
run format_dart.sh "$project" "$(tool Edit file_path "$project/lib/main.dart")"
check "format: file formatted" "4" "$(wc -l <"$project/lib/main.dart" | tr -d ' ')"
check "format: file tracked" "$project/lib/main.dart" "$(cat "$tmp/flutter-steering-s1.touched" 2>/dev/null)"
run format_dart.sh "$project" "$(tool Edit file_path "$project/lib/model.g.dart")"
check "format: generated not tracked" "1" "$(wc -l <"$tmp/flutter-steering-s1.touched" | tr -d ' ')"

run analyze_on_stop.sh "$project" '{"session_id":"s1","stop_hook_active":false}'
check "stop: issues block the turn" 2 "$code"
check "stop: issues reported" yes "$(grep -q 'unused_local_variable' <<<"$out" && echo yes)"
check "stop: list consumed" no "$([[ -e $tmp/flutter-steering-s1.touched ]] && echo yes || echo no)"

echo "$project/lib/main.dart" >"$tmp/flutter-steering-s1.touched"
run analyze_on_stop.sh "$project" '{"session_id":"s1","stop_hook_active":true}'
check "stop: second stop never blocks" 0 "$code"

printf 'void main() {}\n' >"$project/lib/main.dart"
echo "$project/lib/main.dart" >"$tmp/flutter-steering-s1.touched"
run analyze_on_stop.sh "$project" '{"session_id":"s1","stop_hook_active":false}'
check "stop: clean files pass" 0 "$code"
run analyze_on_stop.sh "$project" '{"session_id":"s2","stop_hook_active":false}'
check "stop: nothing touched passes" 0 "$code"

# Someone else's git repo: committed formatting is respected, and only issues
# on changed lines block the turn.
repo="$tmp/repo"
mkdir -p "$repo/lib"
printf 'name: repo\nenvironment:\n  sdk: ^3.5.0\n' >"$repo/pubspec.yaml"
printf 'void legacy(){final a=1;}\n' >"$repo/lib/legacy.dart"
printf 'void clean() {}\n' >"$repo/lib/clean.dart"
printf 'void old() {\n  final c = 3;\n}\n\nvoid other() {}\n' >"$repo/lib/old.dart"
(cd "$repo" && git init -q && git add -A &&
  git -c user.name=test -c user.email=test@example.com commit -qm init && dart pub get >/dev/null 2>&1)
edit() { run format_dart.sh "$repo" "$(jq -nc --arg f "$repo/lib/$1" '{session_id: "s3", tool_name: "Edit", tool_input: {file_path: $f}}')"; }
stop() { run analyze_on_stop.sh "$repo" '{"session_id":"s3","stop_hook_active":false}'; }

printf 'void clean(){print(1);}\n' >"$repo/lib/clean.dart"
edit clean.dart
check "format: formatted file stays formatted" "3" "$(wc -l <"$repo/lib/clean.dart" | tr -d ' ')"

printf 'void legacy(){final a=1;}\nvoid added() {\n  final b = 2;\n}\n' >"$repo/lib/legacy.dart"
edit legacy.dart
check "format: unformatted committed file left alone" "void legacy(){final a=1;}" "$(head -n 1 "$repo/lib/legacy.dart")"
stop
check "stop: new issue blocks" 2 "$code"
check "stop: only the new issue is listed" "1" "$(grep -c 'unused_local_variable' <<<"$out")"
check "stop: pre-existing issue mentioned" yes "$(grep -q '1 pre-existing' <<<"$out" && echo yes)"

printf 'void old() {\n  final c = 3;\n}\n\nvoid other() {}\n\n// Touched.\n' >"$repo/lib/old.dart"
edit old.dart
stop
check "stop: pre-existing issues alone don't block" 0 "$code"

# session_context
run session_context.sh "$project" '{"session_id":"s1"}'
check "session: stack detected" yes "$(grep -q 'state=Bloc; routing=go_router' <<<"$out" && echo yes)"
check "session: hot reload rule" yes "$(grep -q 'hot reload through the Dart MCP server' <<<"$out" && echo yes)"
check "session: official plugin suggested when missing" yes "$(grep -q 'dart-flutter@dart-flutter' <<<"$out" && echo yes)"
printf '{"enabledPlugins": {"dart-flutter@dart-flutter": true}}\n' >"$CLAUDE_CONFIG_DIR/settings.json"
run session_context.sh "$project" '{"session_id":"s1"}'
check "session: no suggestion when official plugin enabled" no "$(grep -q 'dart-flutter@dart-flutter' <<<"$out" && echo yes || echo no)"
rm -f "$CLAUDE_CONFIG_DIR/settings.json"
mkdir -p "$project/.claude"
printf '{"enabledPlugins": {"dart-flutter@dart-flutter": true}}\n' >"$project/.claude/settings.json"
run session_context.sh "$project" '{"session_id":"s1"}'
check "session: project-level enablement counts" no "$(grep -q 'dart-flutter@dart-flutter' <<<"$out" && echo yes || echo no)"
run session_context.sh "$tmp/not_dart" '{"session_id":"s1"}'
check "session: silent outside Dart projects" "" "$out"

echo "hooks: $passed passed, $failed failed"
[[ $failed -eq 0 ]]
