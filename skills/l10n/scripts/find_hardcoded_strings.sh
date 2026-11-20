#!/usr/bin/env bash
# Finds likely hardcoded user-facing strings in Flutter widgets: string
# literals passed to Text, tooltips, labels, hints, titles and messages.
# Candidates only; logs, keys, routes and asset paths are filtered out.
#
# Usage: find_hardcoded_strings.sh [lib_dir]
set -o pipefail
dir="${1:-lib}"

grep -rnE --include='*.dart' \
  --exclude='*.g.dart' --exclude='*.freezed.dart' --exclude='*_test.dart' \
  "(Text|SelectableText|Tooltip)\([[:space:]]*['\"]|(tooltip|label|labelText|hintText|helperText|errorText|title|semanticLabel|message|content):[[:space:]]*(const[[:space:]]+)?(Text\()?['\"]" \
  "$dir" 2>/dev/null |
  grep -vE '/(generated|l10n)/' |
  grep -vE "['\"](/|assets/|https?:|[a-z_]+\.[a-z_.]+['\"])" |
  grep -vE "['\"]['\"]|['\"]\\\$[a-zA-Z_{]" |
  cut -c1-180
