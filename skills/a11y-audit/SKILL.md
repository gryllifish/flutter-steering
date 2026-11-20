---
name: a11y-audit
description: Audits and fixes Flutter accessibility (semantics labels, tap targets, contrast, text scaling, focus and keyboard, screen readers) with static checks and meetsGuideline widget tests. Use when finishing UI work, before a release, or when asked about accessibility. Do not use for general UI building or layout errors (use triage or the official flutter-fix-layout-issues skill).
argument-hint: "[path | screen]"
---

# Accessibility audit

## 1. Static review (read the widgets in scope)
| Check | Rule |
|---|---|
| Icon-only buttons | `tooltip:` on `IconButton` or a `Semantics(label:)` |
| Images | meaningful → `semanticLabel`; decorative → `excludeFromSemantics: true` |
| Custom tappables (`GestureDetector`, `InkWell`) | wrapped with `Semantics(button: true, label:)` or replaced by a real button; min 48×48 dp |
| Grouping | related text/values merged (`MergeSemantics`) so a card reads as one sentence |
| State | toggles/selections expose `checked`/`selected`/`toggled`; errors announced (`SemanticsService.announce` or live regions) |
| Text scaling | no fixed heights around text; no `textScaler: TextScaler.noScaling`; layouts survive 2.0× |
| Contrast | 4.5:1 normal text, 3:1 large text and UI components, in light and dark |
| Color only | information isn't conveyed by color alone (add icon/text) |
| Focus & keyboard (web/desktop) | logical traversal (`FocusTraversalGroup`), visible focus, `Shortcuts`/`Actions` for key actions |
| Motion | respect `MediaQuery.disableAnimationsOf` |
| Labels | localized (through l10n), not hardcoded |

## 2. Automated guidelines
Add (or run) a widget test per screen in scope:
```dart
testWidgets('meets accessibility guidelines', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpApp(const ClientsScreen()); // project's helper
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
});
```
Also pump at `textScaler: TextScaler.linear(2)` and assert no overflow.

## 3. Manual (tell the user how)
TalkBack/VoiceOver pass on the main flow; Flutter's semantics debugger
(`showSemanticsDebugger: true`); Accessibility Scanner (Android) /
Accessibility Inspector (iOS).

## Report
Findings by severity (blocks a user / degrades / polish) with `path:line`
and fix. Apply fixes when asked; add the guideline test to prevent
regressions.
