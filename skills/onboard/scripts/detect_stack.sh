#!/usr/bin/env bash
# Detects the stack and conventions of a Dart/Flutter project from its
# pubspecs and files, without running Flutter. Fast and token-cheap.
#
# Usage: detect_stack.sh [--brief] [project_dir]
#   --brief  one line, used by the SessionStart hook
#   default  a compact report, used by the onboard skill
set -o pipefail

brief=false
if [[ "${1:-}" == "--brief" ]]; then
  brief=true
  shift
fi
root="${1:-$PWD}"
cd "$root" 2>/dev/null || exit 1

find_pubspecs() {
  find . -maxdepth 4 -name pubspec.yaml -not -path '*/.dart_tool/*' \
    -not -path '*/build/*' -not -path '*/ephemeral/*' -not -path '*/.symlinks/*' "$@" 2>/dev/null
}
pubspecs="$(find_pubspecs | sort)"
[[ -n "$pubspecs" ]] || exit 1
all_deps="$(find_pubspecs -exec cat {} +)"

# Prints the basenames of the existing paths among its (glob-expanded) args.
names() {
  local path out=""
  for path in "$@"; do
    [[ -e "$path" ]] && out="$out${path##*/} "
  done
  printf '%s' "$out"
}

has() { grep -qE "^[[:space:]]+$1:" <<<"$all_deps"; }
# Prints the first matching label for each "pkg=label" pair.
pick() {
  local out="" pair
  for pair in "$@"; do
    has "${pair%%=*}" && out="${out:+$out, }${pair#*=}"
  done
  echo "$out"
}

state="$(pick riverpod_annotation='Riverpod (codegen)' flutter_riverpod=Riverpod \
  hooks_riverpod='Riverpod (hooks)' flutter_bloc=Bloc provider=Provider get=GetX \
  mobx=MobX signals=Signals flutter_redux=Redux stacked=Stacked)"
# Riverpod codegen implies flutter_riverpod; keep the most specific label.
state="$(sed -E 's/^Riverpod \(codegen\), Riverpod(, |$)/Riverpod (codegen)\1/' <<<"$state")"
routing="$(pick go_router=go_router auto_route=auto_route beamer=beamer)"
models="$(pick freezed=freezed json_serializable=json_serializable built_value=built_value dart_mappable=dart_mappable equatable=equatable)"
di="$(pick get_it=get_it injectable=injectable)"
network="$(pick dio=dio http=http retrofit=retrofit chopper=chopper graphql_flutter=graphql ferry=ferry grpc=grpc)"
storage="$(pick drift=drift isar=isar hive=hive hive_ce=hive_ce sqflite=sqflite objectbox=objectbox shared_preferences=shared_preferences flutter_secure_storage=secure_storage)"
lints="$(pick very_good_analysis=very_good_analysis flutter_lints=flutter_lints lints=lints)"
testing="$(pick mocktail=mocktail mockito=mockito bloc_test=bloc_test alchemist=alchemist golden_toolkit=golden_toolkit patrol=patrol integration_test=integration_test)"
l10n="$(pick slang=slang easy_localization=easy_localization flutter_localizations=gen-l10n)"
[[ -f l10n.yaml ]] && l10n="${l10n:-gen-l10n} (l10n.yaml)"
firebase="$(grep -qE '^[[:space:]]+firebase_core:' <<<"$all_deps" && echo yes)"
codegen="$(has build_runner && echo build_runner)"

type="Dart package"
grep -qE 'sdk:[[:space:]]*flutter' pubspec.yaml 2>/dev/null && type="Flutter package"
[[ -d lib && -f lib/main.dart || -n "$(ls lib/main_*.dart 2>/dev/null)" ]] && type="Flutter app"
monorepo=""
[[ -f melos.yaml ]] && monorepo="melos"
grep -qE '^workspace:' pubspec.yaml 2>/dev/null && monorepo="${monorepo:+$monorepo + }pub workspace"
sdk="$(cat .fvmrc 2>/dev/null | grep -oE '"flutter"[[:space:]]*:[[:space:]]*"[^"]+"' | grep -oE '[0-9][^"]*')"
[[ -n "$sdk" ]] && sdk="Flutter $sdk via FVM"

if $brief; then
  line="$type"
  for part in "state=$state" "routing=$routing" "models=$models" "di=$di" \
    "lints=$lints" "tests=$testing" "l10n=$l10n" "monorepo=$monorepo" "sdk=$sdk"; do
    [[ -n "${part#*=}" ]] && line="$line; $part"
  done
  echo "$line"
  exit 0
fi

row() { [[ -n "$2" ]] && printf '%-13s %s\n' "$1:" "$2"; return 0; }

echo "## Stack"
row "Type" "$type"
row "Name" "$(grep -m1 -E '^name:' pubspec.yaml 2>/dev/null | awk '{print $2}')"
row "Dart SDK" "$(grep -m1 -E '^[[:space:]]+sdk:[[:space:]]*["'"'"']?[\^>]' pubspec.yaml 2>/dev/null | sed 's/^[[:space:]]*sdk:[[:space:]]*//')"
row "Pinned SDK" "$sdk"
row "Monorepo" "$monorepo"
row "State" "$state"
row "Routing" "$routing"
row "Models" "$models"
row "Codegen" "$codegen"
row "DI" "$di"
row "Network" "$network"
row "Storage" "$storage"
row "L10n" "$l10n"
row "Firebase" "$firebase"
row "Lints" "$lints"
row "Testing" "$testing"

echo
echo "## Project"
row "Pubspecs" "$(wc -l <<<"$pubspecs" | tr -d ' ')"
row "Dart files" "lib $(find lib -name '*.dart' 2>/dev/null | grep -vcE '\.(g|freezed|gr|mocks|config|gen)\.dart$') (hand-written), test $(find test -name '*_test.dart' 2>/dev/null | wc -l | tr -d ' ') test files"
row "Platforms" "$(for p in android ios web macos windows linux; do [[ -d $p ]] && printf '%s ' "$p"; done)"
row "Entrypoints" "$(names lib/main*.dart)"
flavors="$(grep -hoE 'productFlavors|flavorDimensions' android/app/build.gradle* 2>/dev/null | head -1)"
row "Flavors" "${flavors:+android productFlavors}"
row "CI" "$(names .github/workflows/*.yml .github/workflows/*.yaml)$( [[ -f codemagic.yaml ]] && echo 'codemagic ')$( [[ -d fastlane || -d android/fastlane || -d ios/fastlane ]] && echo 'fastlane')"
row "Scripts" "$(names scripts/*)"
row "AI steering" "$(for f in CLAUDE.md AGENTS.md .claude/steering .cursor/rules .github/copilot-instructions.md GEMINI.md; do [[ -e $f ]] && printf '%s ' "$f"; done)"

echo
echo "## lib/ layout (depth 3, directories)"
find lib -mindepth 1 -maxdepth 3 -type d 2>/dev/null | sort | sed 's|^lib/||' | head -n 40
