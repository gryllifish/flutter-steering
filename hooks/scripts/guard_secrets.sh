#!/usr/bin/env bash
# PreToolUse (Read|Edit|Write|MultiEdit|Grep|Bash):
# - denies access to credentials and signing material (.env, keystores,
#   key.properties, service accounts, Apple keys);
# - asks the user before destructive or outward-facing commands
#   (force push, hard reset, clean, recursive delete, pub publish).
source "$(dirname "$0")/lib.sh"
is_dart_project || exit 0

secret_reason="contains secrets or signing material and is off-limits to the agent. Ask the user for the specific non-secret value you need, or use the committed template (.env.example, key.properties.example)."

tool="$(json .tool_name)"

if [[ "$tool" != "Bash" ]]; then
  for path in "$(json .tool_input.file_path)" "$(json .tool_input.path)"; do
    [[ -n "$path" ]] && is_secret "$path" && deny "$(basename "$path") $secret_reason"
  done
  exit 0
fi

cmd="$(json .tool_input.command)"
[[ -n "$cmd" ]] || exit 0

# Any token of the command that names a secret file. Globbing is disabled so
# tokens like `*` are inspected literally instead of expanded.
set -f
for token in $(tr -s " \t\n;|&<>()'\"=" '\n' <<<"$cmd"); do
  is_secret "$token" && deny "The command touches $(basename -- "$token"), which $secret_reason"
done

ere() { grep -qE -e "$1" <<<"$cmd"; }

if ere 'git[[:space:]]+push' && ere '(--force([[:space:]]|$)|[[:space:]]-[a-zA-Z]*f([[:space:]]|$))' &&
  ! ere '--force-with-lease'; then
  ask "Force push rewrites remote history."
fi
ere 'git[[:space:]]+reset[[:space:]].*--hard' && ask "git reset --hard discards uncommitted work."
ere 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f' && ask "git clean deletes untracked files."
ere 'git[[:space:]]+(checkout|restore)[[:space:]]+(--[[:space:]]+)?\.([[:space:]]|$)' &&
  ask "This discards all local changes in the working tree."
ere 'git[[:space:]]+branch[[:space:]]+-D' && ask "Force-deleting a branch can lose unmerged commits."
# shellcheck disable=SC2016 # `$HOME` is matched literally in the command text.
ere 'rm[[:space:]]+-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+(/|~|\$HOME|\.\.|\*|\.)([[:space:]]|/?$)' &&
  ask "Recursive delete on a broad path."
if ere '(flutter|dart)[[:space:]]+pub[[:space:]]+publish' && ! ere '--dry-run'; then
  ask "Publishing to pub.dev is public and permanent."
fi

exit 0
