---
name: perf-audit
description: Audit Flutter app performance (rebuilds, jank, lists, images, isolates, startup, app size) with static heuristics plus profiling guidance, and propose ranked fixes. Use when the app feels slow or janky, before a release, or when asked about performance.
argument-hint: "[path | 'size' | 'startup']"
---

# Performance audit

Measure before optimizing. Static findings are hypotheses until confirmed.

## 1. Static scan
Run `scripts/perf_scan.sh <lib-dir>` (this skill's directory). Read each
hit in context and keep only real problems. What to look for:

| Smell | Why it matters | Fix |
|---|---|---|
| Long lists via `ListView(children:)`, `Column` + `.map`, `shrinkWrap: true` | builds every item up front | `ListView.builder`/slivers, `itemExtent`/`prototypeItem` |
| `MediaQuery.of(context)` | rebuilds on any metric change (keyboard!) | `MediaQuery.sizeOf`/`paddingOf`... |
| Watching whole objects (`ref.watch(p).field`, `context.watch<T>().x`) | rebuild on unrelated changes | `select` |
| Work in `build` (sorting, filtering, formatting, `jsonDecode`) | runs every frame it rebuilds | move to state holder / memoize |
| Large JSON or heavy compute on UI isolate | jank | `Isolate.run` / `compute` |
| `Opacity`, `ClipPath`, `BackdropFilter`, `ShaderMask` animated | saveLayer cost | `FadeTransition`, `AnimatedOpacity`, pre-clipped assets |
| `Image.network` without size | decodes full-res images | `cacheWidth`/`cacheHeight`, cached image package |
| Animations rebuilding big subtrees | jank | `AnimatedBuilder(child:)`, `RepaintBoundary` |
| `IntrinsicHeight/Width` in lists | O(n²) layout | explicit sizes / different layout |
| Missing `const` | avoidable rebuild work | `const` constructors |

## 2. Runtime (when an app or device is available)
- Profile mode only: `flutter run --profile` (never judge perf in debug).
- With the Dart MCP server: launch the app, use the widget inspector and
  runtime errors tools to inspect. Otherwise guide the user through DevTools:
  Performance view (frames > 16 ms, raster vs UI thread), "Track widget
  rebuilds", CPU profiler, Memory view for leaks (undisposed controllers).
- `debugProfileBuildsEnabled`/`debugRepaintRainbowEnabled` for quick looks.

## 3. `size`
`flutter build apk --analyze-size --target-platform android-arm64` (or
`appbundle`/`ios`), then open the generated JSON in DevTools App Size tool.
Check: unused assets, uncompressed images (prefer WebP/SVG), large fonts
(subset), heavy packages, `--split-debug-info` + `--obfuscate` for release,
deferred imports on web.

## 4. `startup`
Look for work before `runApp` (await chains in `main`), eager provider/bloc
initialization, synchronous plugin init, big first-frame trees. Measure
with `flutter run --profile --trace-startup`.

## Report
Ranked table: impact (high/med/low) · `path:line` · problem · fix · how to
verify. Apply fixes only when asked, one category at a time, verifying
behavior with tests.
