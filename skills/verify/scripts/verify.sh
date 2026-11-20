#!/usr/bin/env bash
# Adaptive Definition of Done gate for any Dart/Flutter project.
#
# If the project ships its own gate (scripts/verify.sh, scripts/check.sh,
# a Makefile `verify` target or melos `verify` script), that one wins.
# Otherwise runs the steps the project needs: pub get, codegen (only with
# build_runner), l10n (only with l10n.yaml), format, analyze, test.
#
# Output: one ✓/✗ line per step; failing steps print only their last 40
# lines. Exit code is non-zero if any step fails.
#
# Usage: verify.sh [--skip-codegen] [--no-test] [project_dir]
set -o pipefail

skip_codegen=false
no_test=false
root=""
for arg in "$@"; do
  case "$arg" in
    --skip-codegen) skip_codegen=true ;;
    --no-test) no_test=true ;;
    *) root="$arg" ;;
  esac
done
root="${root:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$root" || exit 1
[[ -f pubspec.yaml ]] || { echo "✗ no pubspec.yaml in $root"; exit 1; }

# 1. Project-owned gate.
for own in scripts/verify.sh scripts/check.sh tool/verify.sh; do
  if [[ -x "$own" ]]; then
    echo "→ using project gate: $own"
    args=()
    $skip_codegen && args+=(--skip-codegen)
    exec "$own" "${args[@]}"
  fi
done
if [[ -f melos.yaml ]] && grep -qE '^[[:space:]]+verify:' melos.yaml && command -v melos >/dev/null; then
  echo "→ using project gate: melos run verify"
  exec melos run verify
fi
if [[ -f Makefile ]] && grep -qE '^verify:' Makefile; then
  echo "→ using project gate: make verify"
  exec make verify
fi

# 2. Inferred gate.
prefix=()
[[ -f .fvmrc || -f .fvm/fvm_config.json ]] && command -v fvm >/dev/null && prefix=(fvm)
is_flutter=false
grep -qE 'sdk:[[:space:]]*flutter' pubspec.yaml && is_flutter=true
if $is_flutter; then tool=flutter; else tool=dart; fi

failed=0
run() {
  local name="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    echo "✓ $name"
  else
    echo "✗ $name"
    grep -v '^[[:space:]]*$' <<<"$output" | tail -n 40
    failed=1
  fi
}

dirs=()
for d in lib bin test integration_test tool packages apps; do [[ -d $d ]] && dirs+=("$d"); done

run "pub get" "${prefix[@]}" $tool pub get
if ! $skip_codegen && grep -qE '^[[:space:]]+build_runner:' pubspec.yaml; then
  run "codegen" "${prefix[@]}" dart run build_runner build --delete-conflicting-outputs
fi
if $is_flutter && [[ -f l10n.yaml ]]; then
  run "l10n" "${prefix[@]}" flutter gen-l10n
fi
[[ ${#dirs[@]} -gt 0 ]] && run "format" "${prefix[@]}" dart format "${dirs[@]}"
if $is_flutter; then
  run "analyze" "${prefix[@]}" flutter analyze --no-pub
else
  run "analyze" "${prefix[@]}" dart analyze
fi
if ! $no_test && [[ -d test ]]; then
  if $is_flutter; then
    run "test" "${prefix[@]}" flutter test --no-pub --reporter failures-only
  else
    run "test" "${prefix[@]}" dart test --reporter failures-only
  fi
fi

exit $failed
