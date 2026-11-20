---
name: l10n
description: Internationalization for Flutter apps - add or change translated strings in every locale, find hardcoded strings, handle plurals/placeholders/dates/numbers/RTL. Adapts to gen-l10n, slang or easy_localization. Use when adding UI text, adding a locale, or auditing hardcoded strings.
argument-hint: "['audit' | 'add <key> <text>' | 'locale <code>']"
---

# L10n

## Detect the setup
- `l10n.yaml` / `flutter_localizations` + ARB files → **gen-l10n**
  (template ARB from `l10n.yaml` `template-arb-file`; output is generated,
  never edited).
- `slang` → JSON/YAML in the configured folder, `dart run slang`.
- `easy_localization` → JSON in `assets/translations`, keys via
  `LocaleKeys` (codegen) if present.
- None and the app has user-facing text → propose gen-l10n to the user
  before adding it.

## Adding strings (gen-l10n)
- Key: lowerCamelCase, scoped by feature/screen: `clientsEmptyTitle`,
  `paymentsRetryButton`. Reuse an existing key only if the meaning is
  identical, not just the text.
- Add to **every** ARB locale in the same change, with a real translation
  (not a copy of English). Add `@key` metadata with `description` and
  typed `placeholders`.
- Plurals/genders with ICU: `{count, plural, =0{No clients} =1{1 client} other{{count} clients}}`.
- Dates, numbers and currency formatted with `intl` (`DateFormat.yMMMd(locale)`,
  `NumberFormat.currency`) using the current locale, never string
  concatenation.
- Regenerate: `flutter gen-l10n` (or via `flutter pub get`, depending on the
  config), then use through the project's accessor (`context.l10n.key` or
  `AppLocalizations.of(context)`).

## `audit`
Run `scripts/find_hardcoded_strings.sh <lib-dir>` (this skill's directory),
confirm each candidate by reading it, and report/fix only user-facing ones.
Also check: ARB key parity across locales (missing/extra keys), unused keys
(grep each key in `lib/`), and RTL issues (`EdgeInsets.only(left:)` →
`EdgeInsetsDirectional`, `Alignment.centerLeft` → `AlignmentDirectional`,
directional icons).

## `locale <code>`
Add the ARB file with every key translated, add the locale to
`supportedLocales` if it is not derived automatically, iOS
`CFBundleLocalizations` in `Info.plist`, and test one screen with the new
locale (including long strings for layout overflow).
