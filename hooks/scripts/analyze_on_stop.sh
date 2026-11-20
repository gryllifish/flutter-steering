#!/usr/bin/env bash
# Stop: before Claude ends its turn, analyzes the Dart files it touched in
# this session. Issues on lines Claude added or changed (vs git HEAD; every
# line for new or untracked files) block the turn once and are fed back to
# Claude. Issues on untouched lines are pre-existing debt: they are
# mentioned but never block, so work in someone else's codebase doesn't
# sprawl into fixing unrelated lints.
#
# Trade-off: an issue that a change causes on an untouched line (e.g. an
# import that becomes unused) doesn't block here; the verify gate's full
# analysis still catches it.
#
# A second stop in a row is always allowed, so this can never loop.
source "$(dirname "$0")/lib.sh"

list="$(touched_list)"
[[ -s "$list" ]] || exit 0

if [[ "$(json .stop_hook_active)" == "true" ]]; then
  rm -f "$list"
  exit 0
fi

files=()
while IFS= read -r f; do
  [[ -f "$f" ]] && files+=("$f")
done < <(sort -u "$list")
rm -f "$list"
[[ ${#files[@]} -gt 0 ]] || exit 0

# Machine format: SEVERITY|TYPE|CODE|/abs/path|LINE|COL|LENGTH|MESSAGE
issues="$(dart_cmd analyze --format=machine "${files[@]}" 2>&1 | grep -E '^(ERROR|WARNING|INFO)\|')"
[[ -n "$issues" ]] || exit 0

# Absolute path with symlinks resolved, as the analyzer reports it.
canonical() { echo "$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"; }
root="$(cd "$PROJECT_DIR" && pwd -P)"

# "<path>:<line>" for every added/changed line, "<path>:*" for new files.
changed="$(mktemp)"
trap 'rm -f "$changed"' EXIT
for f in "${files[@]}"; do
  path="$(canonical "$f")"
  rel="$(git -C "$PROJECT_DIR" ls-files --full-name -- "$f" 2>/dev/null | head -n 1)"
  if [[ -z "$rel" ]] || ! git -C "$PROJECT_DIR" cat-file -e "HEAD:$rel" 2>/dev/null; then
    echo "$path:*" >>"$changed"
    continue
  fi
  git -C "$PROJECT_DIR" diff -U0 HEAD -- "$f" |
    sed -nE 's/^@@ -[0-9,]+ \+([0-9]+)(,([0-9]+))? @@.*/\1 \3/p' |
    while read -r start count; do
      count="${count:-1}"
      for ((i = start; i < start + count; i++)); do echo "$path:$i"; done
    done >>"$changed"
done

new=""
old_count=0
while IFS='|' read -r severity _ code path line col _ message; do
  if grep -qxF -e "$path:$line" -e "$path:*" "$changed"; then
    entry="$(tr '[:upper:]' '[:lower:]' <<<"$severity") - ${path#"$root"/}:$line:$col - $message - $(tr '[:upper:]' '[:lower:]' <<<"$code")"
    new="${new:+$new$'\n'}$entry"
  else
    old_count=$((old_count + 1))
  fi
done <<<"$issues"

[[ -n "$new" ]] || exit 0

{
  echo "flutter-steering: dart analyze found $(grep -c . <<<"$new") issue(s) on lines you changed. Fix them (or explain why not) before finishing:"
  head -n 30 <<<"$new"
  [[ $old_count -gt 0 ]] &&
    echo "($old_count pre-existing issue(s) on lines you didn't touch: leave them unless the user asks.)"
} >&2
exit 2
