#!/usr/bin/env bash
# Compares every ARB file in a folder against the template: message keys
# missing or extra per locale, and placeholders that differ for a key.
# Prints nothing but a summary line when all locales match.
#
# Usage: arb_parity.sh <arb-dir> [template-file-name]   (requires jq)
set -o pipefail
dir="${1:?usage: arb_parity.sh <arb-dir> [template.arb]}"
template="${2:-}"
if [[ -z "$template" ]]; then
  template="$(sed -nE 's/^template-arb-file:[[:space:]]*["'"'"']?([^"'"'"' ]+).*/\1/p' l10n.yaml 2>/dev/null)"
fi
template="${template:-app_en.arb}"
[[ -f "$dir/$template" ]] || { echo "template $dir/$template not found"; exit 1; }

keys() { jq -r 'keys[] | select(startswith("@") | not)' "$1" | sort; }
placeholders() { jq -r --arg k "$2" '.["@" + $k].placeholders // {} | keys | join(",")' "$1"; }

issues=0
for arb in "$dir"/*.arb; do
  [[ "$(basename "$arb")" == "$template" ]] && continue
  name="$(basename "$arb")"
  missing="$(comm -23 <(keys "$dir/$template") <(keys "$arb"))"
  extra="$(comm -13 <(keys "$dir/$template") <(keys "$arb"))"
  for k in $missing; do echo "$name: missing $k"; issues=$((issues + 1)); done
  for k in $extra; do echo "$name: extra $k (not in $template)"; issues=$((issues + 1)); done
  # Placeholders are declared in the template; a translation must use the same
  # ones in its message text.
  for k in $(comm -12 <(keys "$dir/$template") <(keys "$arb")); do
    expected="$(placeholders "$dir/$template" "$k")"
    [[ -n "$expected" ]] || continue
    message="$(jq -r --arg k "$k" '.[$k]' "$arb")"
    for p in ${expected//,/ }; do
      if [[ "$message" != *"{$p"* ]]; then
        echo "$name: $k does not use placeholder {$p}"
        issues=$((issues + 1))
      fi
    done
  done
done
echo "arb parity: $issues issue(s) against $template"
[[ $issues -eq 0 ]]
