# Widgets, layout and UI

## Composition
- Extract widgets as **classes**, not helper methods returning widgets
  (`_buildHeader()`): classes get their own element, `const` and rebuild
  boundaries.
- Small widgets with one responsibility; screens compose them. A file with
  more than ~300 lines or a `build` that needs scrolling is a smell.
- `const` constructors everywhere possible; pass only the data a widget
  needs, not whole state objects.
- Public, reusable widgets live in `shared/widgets` or the design system and
  have a widget test.

## Layout
- Responsive via `LayoutBuilder` / `MediaQuery.sizeOf(context)` and
  breakpoints from constants; never hardcoded device sizes.
- Use `MediaQuery.sizeOf`/`paddingOf`/`textScalerOf` instead of
  `MediaQuery.of` to avoid unnecessary rebuilds.
- Lists: `ListView.builder`/`SliverList.builder` for anything unbounded;
  no `shrinkWrap: true` inside scrollables for long lists; slivers for
  complex scroll layouts.
- Respect safe areas, keyboard insets and text scaling (test at 2.0x).

## Theming
- Colors from `Theme.of(context).colorScheme`, text from `textTheme`; custom
  tokens via `ThemeExtension`. Material 3 by default.
- Light and dark themes both work; no color literals in widgets.

## Animations
- Prefer implicit animations (`AnimatedContainer`, `AnimatedSwitcher`,
  `TweenAnimationBuilder`) before explicit controllers.
- Explicit: `AnimationController` with `vsync`, disposed in `dispose`;
  `AnimatedBuilder` with the static subtree as `child`.
- Durations and curves from constants; respect
  `MediaQuery.disableAnimationsOf(context)`.
- Hero tags unique and stable (use ids, not indexes).

## Forms and input
- `Form` + validators that return localized messages; validation logic that
  matters for the business lives in domain/value objects and is unit tested.
- Text controllers and focus nodes are owned and disposed by the widget that
  creates them.

## Images and assets
- Network images cached and sized (`cacheWidth`/`cacheHeight` or a sized
  container); placeholder and error builders.
- Asset paths from generated constants (flutter_gen) or a single constants
  file.

## Platform adaptation
- `Theme.of(context).platform` / `.adaptive` constructors where behavior
  should follow the platform; web and desktop get hover, focus and keyboard
  shortcuts when they are targets.
