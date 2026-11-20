#!/usr/bin/env bash
# Static heuristics for common Flutter performance smells. Prints
# `category | file:line | code` rows, capped per category. Candidates only:
# every hit must be confirmed by reading the code.
#
# Usage: perf_scan.sh [lib_dir]
set -o pipefail
dir="${1:-lib}"
cap=15

scan() {
  local category="$1" pattern="$2"
  grep -rnE --include='*.dart' --exclude='*.g.dart' --exclude='*.freezed.dart' \
    "$pattern" "$dir" 2>/dev/null | head -n "$cap" |
    while IFS= read -r hit; do
      printf '%s | %s\n' "$category" "$(cut -c1-160 <<<"$hit" | sed -E 's/:([0-9]+):[[:space:]]*/:\1 | /')"
    done
}

scan "shrinkWrap list"        'shrinkWrap:[[:space:]]*true'
scan "non-lazy list"          'ListView\(|GridView\(|Column\([^)]*children:.*\.map\('
scan "children from map"      'children:[[:space:]]*[a-zA-Z_.]+\.map\('
scan "MediaQuery.of"          'MediaQuery\.of\(context\)'
scan "Opacity widget"         '(^|[^a-zA-Z])Opacity\('
scan "saveLayer-heavy"        'ClipPath\(|BackdropFilter\(|ShaderMask\('
scan "unsized network image"  'Image\.network\('
scan "sync I/O"               'readAsStringSync|readAsBytesSync|writeAsStringSync|existsSync\('
scan "jsonDecode on UI"       'jsonDecode\('
scan "setState in loop/timer" 'Timer\.periodic|Stream\.periodic'
scan "IntrinsicHeight/Width"  'Intrinsic(Height|Width)\('
scan "GlobalKey"              'GlobalKey<'
scan "watch whole provider"   'ref\.watch\([a-zA-Z_]+Provider\)\.[a-zA-Z_]+'
scan "context.watch whole"    'context\.watch<[A-Za-z_]+>\(\)\.[a-zA-Z_]+'
scan "AnimationController"    'AnimationController\('

echo "---"
echo "missing const candidates: $(dart analyze "$dir" 2>/dev/null | grep -c 'prefer_const')"
