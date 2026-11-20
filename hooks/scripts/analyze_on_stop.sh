#!/usr/bin/env bash
# Stop: before Claude ends its turn, analyzes the Dart files it touched in
# this session. If the analyzer reports anything (errors, warnings or lints),
# the turn is blocked once and the issues are fed back to Claude to fix.
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

issues="$(dart_cmd analyze "${files[@]}" 2>&1 | grep -E '^[[:space:]]*(error|warning|info) -')"
[[ -n "$issues" ]] || exit 0

count="$(grep -c . <<<"$issues")"
{
  echo "flutter-steering: dart analyze found $count issue(s) in files you changed. Fix them (or explain why not) before finishing:"
  head -n 30 <<<"$issues"
} >&2
exit 2
