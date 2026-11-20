#!/usr/bin/env bash
# Tests for the l10n-audit scripts: ARB key/placeholder parity and the
# hardcoded-string finder, on small generated fixtures.
#
# Usage: tests/l10n_test.sh        (requires jq)
set -o pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root_dir/skills/l10n-audit/scripts"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

passed=0
failed=0
check() {
  if [[ "$2" == "$3" ]]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "✗ $1: expected '$2', got '$3'"
    [[ -n "$out" ]] && head -n 5 <<<"$out" | sed 's/^/    /'
  fi
}
contains() { grep -qF -- "$1" <<<"$out" && echo yes || echo no; }

# --- arb_parity.sh -----------------------------------------------------------
arb="$tmp/arb"
mkdir -p "$arb"
cat >"$arb/app_en.arb" <<'EOF'
{
  "title": "Clients",
  "@title": {"description": "App bar title"},
  "greeting": "Hello {name}",
  "@greeting": {"placeholders": {"name": {"type": "String"}}},
  "retry": "Retry"
}
EOF
cat >"$arb/app_es.arb" <<'EOF'
{
  "title": "Clientes",
  "greeting": "Hola",
  "legacyKey": "Viejo"
}
EOF
out="$("$scripts/arb_parity.sh" "$arb" app_en.arb)"
code=$?
check "parity: missing key reported" yes "$(contains 'app_es.arb: missing retry')"
check "parity: extra key reported" yes "$(contains 'app_es.arb: extra legacyKey')"
check "parity: unused placeholder reported" yes "$(contains 'app_es.arb: greeting does not use placeholder {name}')"
check "parity: issues fail the run" 1 "$code"

cat >"$arb/app_es.arb" <<'EOF'
{"title": "Clientes", "greeting": "Hola {name}", "retry": "Reintentar"}
EOF
out="$("$scripts/arb_parity.sh" "$arb" app_en.arb)"
code=$?
check "parity: matching locales pass" 0 "$code"
check "parity: summary line" yes "$(contains 'arb parity: 0 issue(s)')"

# --- find_hardcoded_strings.sh -----------------------------------------------
lib="$tmp/lib"
mkdir -p "$lib/l10n/generated"
cat >"$lib/screen.dart" <<'EOF'
Widget build(BuildContext context) => Column(children: [
  Text('Welcome back'),
  Text(context.l10n.title),
  IconButton(tooltip: 'Delete client', onPressed: null, icon: Icon(Icons.delete)),
  Image.asset('assets/logo.png'),
]);
EOF
printf "String t() => Text('Generated');\n" >"$lib/l10n/generated/app_localizations.dart"
out="$("$scripts/find_hardcoded_strings.sh" "$lib")"
check "hardcoded: Text literal found" yes "$(contains "Text('Welcome back')")"
check "hardcoded: tooltip literal found" yes "$(contains "tooltip: 'Delete client'")"
check "hardcoded: l10n accessor ignored" no "$(contains 'l10n.title')"
check "hardcoded: generated l10n ignored" no "$(contains 'Generated')"

echo "l10n: $passed passed, $failed failed"
[[ $failed -eq 0 ]]
