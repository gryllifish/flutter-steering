#!/usr/bin/env bash
# Readiness check for running an unfamiliar Flutter project: SDK version vs
# what the project expects, dependencies, codegen and l10n outputs, env
# files, flavors and Firebase config. Read-only: it never installs or
# generates anything, it prints what to do.
#
# Output: one line per check, `✓` ok, `⚠` action needed, `·` info.
# Usage: env_check.sh [project_dir]
set -o pipefail
root="${1:-$PWD}"
cd "$root" 2>/dev/null || exit 1
if [[ ! -f pubspec.yaml ]]; then
  found="$(find . -maxdepth 3 -name pubspec.yaml -not -path '*/.dart_tool/*' -not -path '*/build/*' 2>/dev/null |
    sed -E 's|^\./||; s|/?pubspec\.yaml$||' | paste -sd, - | sed 's/,/, /g')"
  echo "⚠ no pubspec.yaml at the root; Dart packages found in: ${found:-none}. Re-run with the app's folder."
  exit 1
fi

ok() { echo "✓ $*"; }
todo() { echo "⚠ $*"; }
info() { echo "· $*"; }
has_dep() { grep -qE "^[[:space:]]+$1:" pubspec.yaml; }

# First x.y.z in a constraint (`^3.5.0`, `>=3.5.0 <4.0.0`, `^3.14.0-0`).
lower_bound() { grep -oE '[0-9]+\.[0-9]+\.[0-9]+' <<<"$1" | head -n 1; }
# version_lt A B: A < B, comparing major.minor.patch numerically.
version_lt() {
  local a b i
  read -r -a a <<<"${1//./ }"
  read -r -a b <<<"${2//./ }"
  for i in 0 1 2; do
    ((${a[i]:-0} < ${b[i]:-0})) && return 0
    ((${a[i]:-0} > ${b[i]:-0})) && return 1
  done
  return 1
}

# --- SDK -------------------------------------------------------------------
wanted=""
fvm_pin="$(grep -oE '"flutter"[[:space:]]*:[[:space:]]*"[^"]+"' .fvmrc 2>/dev/null | grep -oE '"[^"]+"$' | tr -d '"')"
[[ -z "$fvm_pin" ]] && fvm_pin="$(grep -oE '"flutterSdkVersion"[[:space:]]*:[[:space:]]*"[^"]+"' .fvm/fvm_config.json 2>/dev/null | grep -oE '"[^"]+"$' | tr -d '"')"
[[ -n "$fvm_pin" ]] && wanted="$wanted FVM=$fvm_pin"
pub_flutter="$(sed -nE '/^environment:/,/^[^[:space:]]/ s/^[[:space:]]+flutter:[[:space:]]*["'"'"']?([^"'"'"']+)["'"'"']?.*/\1/p' pubspec.yaml | head -n 1)"
[[ -n "$pub_flutter" ]] && wanted="$wanted pubspec=$pub_flutter"
ci_flutter="$(grep -rhoE 'flutter-version:[[:space:]]*["'"'"']?[0-9][0-9.x]*' .github/workflows 2>/dev/null | head -n 1 | grep -oE '[0-9][0-9.x]*$')"
[[ -n "$ci_flutter" ]] && wanted="$wanted CI=$ci_flutter"
pub_dart="$(sed -nE '/^environment:/,/^[^[:space:]]/ s/^[[:space:]]+sdk:[[:space:]]*["'"'"']?([^"'"'"']+)["'"'"']?.*/\1/p' pubspec.yaml | head -n 1)"

installed="$(flutter --version --machine 2>/dev/null | grep -oE '"frameworkVersion"[[:space:]]*:[[:space:]]*"[^"]+"' | grep -oE '[0-9][^"]*')"
installed_dart="$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
info "installed: Flutter ${installed:-?} / Dart ${installed_dart:-?}; project expects:${wanted:- (no pin)} Dart=${pub_dart:-?}"
need_dart="$(lower_bound "$pub_dart")"
if [[ -n "$need_dart" && -n "$installed_dart" ]] && version_lt "$installed_dart" "$need_dart"; then
  todo "pubspec needs Dart >= $need_dart but you have $installed_dart: \`pub get\` will fail. Use the project's pin, a newer stable, or the channel it targets (a -0 suffix means a pre-release SDK)"
fi
need_flutter="$(lower_bound "$pub_flutter")"
if [[ -n "$need_flutter" && -n "$installed" ]] && version_lt "$installed" "$need_flutter"; then
  todo "pubspec needs Flutter >= $need_flutter but you have $installed"
fi
if [[ -n "$fvm_pin" ]]; then
  if ! command -v fvm >/dev/null; then
    todo "project pins Flutter $fvm_pin with FVM but fvm is not installed"
  elif [[ -d "${FVM_CACHE_PATH:-$HOME/fvm}/versions/$fvm_pin" ]]; then
    ok "FVM version $fvm_pin is installed (use \`fvm flutter\`)"
  else
    todo "install the pinned SDK: \`fvm install $fvm_pin\`"
  fi
elif [[ -n "$ci_flutter" && -n "$installed" && "$installed" != "$ci_flutter"* ]]; then
  todo "CI uses Flutter $ci_flutter, you have $installed: expect analyzer/lint differences"
fi

# --- Dependencies ----------------------------------------------------------
if [[ -f melos.yaml ]]; then
  todo "melos monorepo: run \`melos bootstrap\` (or \`dart pub get\` at the root for pub workspaces)"
elif [[ -f .dart_tool/package_config.json ]]; then
  ok "dependencies resolved (.dart_tool present)"
else
  todo "run \`flutter pub get\`"
fi

# --- Codegen ---------------------------------------------------------------
if has_dep build_runner; then
  tracked="$(git ls-files '*.g.dart' '*.freezed.dart' '*.gr.dart' '*.config.dart' 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$tracked" -gt 0 ]]; then
    ok "build_runner outputs are committed ($tracked files)"
  else
    todo "build_runner is used but its outputs are not committed: run \`dart run build_runner build --delete-conflicting-outputs\` before building"
  fi
fi

# --- L10n ------------------------------------------------------------------
if [[ -f l10n.yaml ]]; then
  out_dir="$(sed -nE 's/^output-dir:[[:space:]]*["'"'"']?([^"'"'"' ]+).*/\1/p' l10n.yaml)"
  if [[ -n "$out_dir" && ! -d "$out_dir" ]]; then
    todo "l10n output ($out_dir) missing: run \`flutter gen-l10n\`"
  else
    ok "l10n configured (gen-l10n)"
  fi
fi
has_dep slang && info "slang: \`dart run slang\` regenerates translations"

# --- Environment and secrets -------------------------------------------------
for example in .env.example .env.sample .env.template .env.dist; do
  if [[ -f "$example" ]]; then
    if [[ -n "$(find . -maxdepth 1 -name '.env*' ! -name "$example" -print -quit)" ]]; then
      ok "env file present (template: $example)"
    else
      todo "create .env from $example; ask the team for real values (the agent can't read them)"
    fi
  fi
done
define_files="$(grep -rhoE 'dart-define-from-file[= ]+[^] "'"'"'`,)]+' .vscode README.md Makefile scripts 2>/dev/null |
  sed -E 's/.*from-file[= ]+//; s/[.:;]+$//' | sort -u | tr '\n' ' ')"
for f in $define_files; do
  if [[ -f "$f" ]]; then
    ok "define file $f present"
  elif [[ -f "$f.example" ]]; then
    todo "missing $f (--dart-define-from-file): copy $f.example and fill in values"
  else
    todo "missing $f (--dart-define-from-file): ask the team for it"
  fi
done

# --- How the team runs it ----------------------------------------------------
entrypoints="$(find lib -maxdepth 1 -name 'main*.dart' 2>/dev/null | sort | tr '\n' ' ')"
[[ -n "$entrypoints" ]] && info "entrypoints: $entrypoints"
flavors="$(sed -nE '/productFlavors/,/^[[:space:]]*}[[:space:]]*$/ s/^[[:space:]]*(create\("|register\(")?([A-Za-z0-9_]+)("\))?[[:space:]]*\{.*/\2/p' android/app/build.gradle* 2>/dev/null | grep -v productFlavors | sort -u | tr '\n' ' ')"
[[ -n "$flavors" ]] && todo "Android flavors: $flavors→ run with \`--flavor <name>\` (and \`-t lib/main_<name>.dart\` if per-flavor entrypoints exist)"
if [[ -f .vscode/launch.json ]]; then
  info "VS Code launch configs (how the team runs it): $(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' .vscode/launch.json | sed -E 's/.*"([^"]+)"$/\1/' | tr '\n' ',' | sed 's/,$//')"
fi

# --- Firebase / native config -------------------------------------------------
if has_dep firebase_core; then
  if [[ -d android ]] && [[ -z "$(find android/app -name google-services.json -print -quit 2>/dev/null)" ]]; then
    todo "firebase_core used but android google-services.json is missing (gitignored?): ask the team or run \`flutterfire configure\`"
  fi
  if [[ -d ios ]] && [[ -z "$(find ios -name GoogleService-Info.plist -print -quit 2>/dev/null)" ]]; then
    todo "firebase_core used but iOS GoogleService-Info.plist is missing"
  fi
  [[ -f lib/firebase_options.dart ]] || info "no lib/firebase_options.dart (FlutterFire CLI output) found"
fi
[[ -f ios/Podfile ]] && info "iOS: CocoaPods runs on first \`flutter run\`; slow the first time"
exit 0
