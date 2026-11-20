---
name: l10n-audit
description: Audits a localized Flutter app for i18n defects - hardcoded user-facing strings, ARB keys missing or extra across locales, mismatched placeholders, and RTL-unsafe layout. Adapts to gen-l10n, slang or easy_localization. Use when adding UI text to a localized app, before a release, or when asked about hardcoded strings or translations. Do not use to set up localization from scratch; the official flutter-setup-localization skill covers that.
argument-hint: "[lib-dir]"
---

# L10n audit

## 1. Detect the setup
- `l10n.yaml` or `flutter_localizations` + ARB files → gen-l10n (template
  file from `template-arb-file`, folder from `arb-dir`).
- `slang` → its JSON/YAML folder. `easy_localization` → `assets/translations`.
- None → suggest the official `flutter-setup-localization` skill and stop.

## 2. Checks (scripts in this skill's directory)
| Check | How |
|---|---|
| Hardcoded strings | `scripts/find_hardcoded_strings.sh <lib-dir>`; confirm each candidate and keep only user-facing ones (not logs, keys, routes, semantics identifiers) |
| Key parity (gen-l10n) | `scripts/arb_parity.sh <arb-dir> [template.arb]`: keys missing or extra per locale, placeholders a translation doesn't use |
| Unused keys | grep each template key in `lib/`; generated accessors use the same name |
| RTL | `EdgeInsets.only(left:/right:)` → `EdgeInsetsDirectional`; `Alignment.centerLeft` → `AlignmentDirectional.centerStart`; `Positioned(left:)` → `PositionedDirectional`; directional icons with `matchTextDirection` |

## 3. Fixing (when asked)
- New strings go into **every** locale in the same change, with real
  translations, an `@key` `description` and typed `placeholders`.
- Plurals and selects with ICU syntax, never string concatenation; dates and
  numbers through `intl` with the current locale.
- Regenerate (`flutter gen-l10n`, `dart run slang`) and use the project's
  accessor (`context.l10n.key`, `AppLocalizations.of(context)`).

## Report
Findings by check with `path:line`, most user-visible first.
