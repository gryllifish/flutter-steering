#!/usr/bin/env bash
# Tests for the triage log extractor: runs it on real logs (flutter test,
# pub get) and synthetic ones (logcat, Gradle, Xcode/CocoaPods, analyzer)
# and checks the signal is kept and the noise dropped.
#
# Usage: tests/triage_test.sh        (requires dart on PATH)
set -o pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
extractor="$root_dir/skills/triage/scripts/extract_errors.dart"
fixtures="$root_dir/tests/fixtures/logs"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

project="$tmp/logapp"
mkdir -p "$project"
printf 'name: logapp\n' >"$project/pubspec.yaml"

passed=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "✗ $1"
}

# extract <fixture>: runs the extractor with the fixture's __ROOT__ pointing
# at the temp project; sets $out, $code and $fixture.
extract() {
  fixture="$1"
  sed "s|__ROOT__|$project|g" "$fixtures/$fixture" >"$tmp/$fixture"
  out="$(dart "$extractor" --root "$project" "$tmp/$fixture")"
  code=$?
}
has() {
  if grep -qF -- "$1" <<<"$out"; then passed=$((passed + 1)); else fail "$fixture: missing '$1'"; fi
}
lacks() {
  if grep -qF -- "$1" <<<"$out"; then fail "$fixture: unexpected '$1'"; else passed=$((passed + 1)); fi
}
at_most_lines() {
  local lines
  lines="$(grep -c . <<<"$out")"
  if [[ $lines -le $1 ]]; then passed=$((passed + 1)); else fail "$fixture: $lines lines (max $1)"; fi
}
exit_code() {
  if [[ $code -eq $1 ]]; then passed=$((passed + 1)); else fail "$fixture: exit $code (expected $1)"; fi
}

extract flutter_test.log
has "A RenderFlex overflowed by 617 pixels on the right."
has "widget: Row at lib/src/profile_card.dart:12:14"
has "Null check operator used on a null value"
has "at lib/src/profile_card.dart:15:29  ProfileCard.build"
has "Expected: exactly one matching candidate"
has "at test/profile_card_test.dart:10:5"
has "at lib/src/profile_card.dart:22:35  parseTotal"
has "test/profile_card_test.dart: parses totals"
lacks "package:flutter/"
lacks "framework.dart"
lacks "Multiple exceptions"
lacks "dart:core"
lacks "$project"
at_most_lines 30
exit_code 1

extract pub_get.log
has "version solving failed"
has "flutter pub add intl:^0.20.3"

extract device_android.log
has "unhandled exception: DioException [bad response]"
has "at lib/data/auth_repository.dart:42:22  AuthRepository.refresh"
has "at lib/application/session_controller.dart:18:5"
has "(x3): A RenderFlex overflowed by 12 pixels on the bottom."
lacks "dio_mixin"
lacks "EGL"
lacks "Observatory"

extract build_android.log
has "kotlin: Unresolved reference 'FlutterFragmentActivity'."
has "at android/app/src/main/kotlin/com/example/logapp/MainActivity.kt:12:5"
has "gradle: Execution failed for task ':app:checkDebugAarMetadata'."
has "is greater than this module's compileSdkVersion (android-34)."
lacks "--stacktrace"

extract build_ios.log
has 'cocoapods: CocoaPods could not find compatible versions for pod "FirebaseCore":'
has "xcode: Cannot find 'GeneratedPluginRegistrant' in scope"
has "at ios/Runner/AppDelegate.swift:10:5"

extract analyze.log
has "analyzer error: The method 'fetchAll' isn't defined"
has "at lib/clients/clients_controller.dart:21:30"
has "analyzer warning"
lacks "prefer_const_constructors"

printf '00:02 +12: All tests passed!\n' >"$tmp/clean.log"
fixture=clean.log
out="$(dart "$extractor" --root "$project" "$tmp/clean.log")"
code=$?
has "No errors recognized"
exit_code 0

echo "triage: $passed passed, $failed failed"
[[ $failed -eq 0 ]]
