---
phase: 12-locale-i18n-infrastructure
reviewed: 2026-08-25T00:00:00Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - lib/providers/locale_provider.dart
  - lib/providers/locale_provider.g.dart
  - l10n.yaml
  - lib/l10n/app_en.arb
  - lib/l10n/app_ru.arb
  - lib/generated/app_localizations.dart
  - lib/generated/app_localizations_en.dart
  - lib/generated/app_localizations_ru.dart
  - test/providers/locale_provider_test.dart
  - test/features/settings/settings_screen_test.dart
  - test/locale_live_switch_test.dart
  - pubspec.yaml
  - lib/app.dart
  - lib/features/settings/settings_screen.dart
  - lib/providers/auth_provider.dart
  - test/providers/auth_provider_test.dart
  - test/widget_test.dart
  - test/offline_cross_tab_test.dart
findings:
  critical: 0
  warning: 3
  info: 0
  total: 3
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-08-25T00:00:00Z
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

Reviewed the locale/i18n infrastructure (`LocaleController`, generated `AppLocalizations`, ARB resources, `SettingsScreen` language section) plus the surrounding files pulled in for cross-check (`app.dart`, `auth_provider.dart` and their tests). No critical/security-relevant defects were found — the D-04 invariant (locale key must survive sign-out) is correctly enforced and covered by a regression test, and the live-locale-switch/persistence flows are exercised by `locale_provider_test.dart` and `locale_live_switch_test.dart`.

Three quality/robustness gaps were found, all in `lib/providers/locale_provider.dart` and its only consumer, `lib/features/settings/settings_screen.dart`: `setLocale()` doesn't enforce the same supported-locale invariant that `build()` enforces, it has no error handling if the persistence write fails after the in-memory state has already been optimistically updated, and two ARB-defined/generated localization keys (`languageEnglish`, `languageRussian`) are dead — the settings screen hardcodes the same literal strings instead of using them, creating a second, un-synchronized source of truth for those labels.

## Warnings

### WR-01: `setLocale()` does not validate the locale against `_supportedCodes`

**File:** `lib/providers/locale_provider.dart:22-26`
**Issue:** `build()` treats `_supportedCodes = {'en', 'ru'}` as the invariant for what's a legal locale and falls back to `Locale('en')` for anything else (line 16-18). `setLocale()` has no equivalent check — it accepts and persists *any* `Locale`, including unsupported ones:
```dart
Future<void> setLocale(Locale locale) async {
  state = AsyncData(locale);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_localeKey, locale.languageCode);
}
```
Today the only call site (`settings_screen.dart:56-58`) only ever passes `Locale('en')`/`Locale('ru')`, so this isn't currently reachable, but the class's own public contract is inconsistent: one method enforces the supported-locale invariant, the other silently accepts anything, including locales `AppLocalizations`/`supportedLocales` in `app.dart` don't declare support for (which would leave `MaterialApp.locale` pointing at an unsupported locale until Flutter's locale resolution kicks in, and would persist that unsupported code to disk for the next cold start).
**Fix:**
```dart
Future<void> setLocale(Locale locale) async {
  if (!_supportedCodes.contains(locale.languageCode)) {
    throw ArgumentError.value(locale, 'locale', 'Unsupported locale');
  }
  state = AsyncData(locale);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_localeKey, locale.languageCode);
}
```

### WR-02: `setLocale()` optimistically updates state with no rollback if persistence fails

**File:** `lib/providers/locale_provider.dart:22-26`
**Issue:** `state` is set to the new locale *before* the `SharedPreferences` write is attempted or confirmed. If `prefs.setString()` throws (write failure, plugin exception, etc.), the exception propagates up uncaught, but `state` has already been changed — the UI now shows the new locale while disk still holds the old one. The next cold start will silently revert to the old locale, with no error surfaced to the user explaining why their choice "didn't stick."
**Fix:** Persist first, then update state (or catch-and-revert on failure):
```dart
Future<void> setLocale(Locale locale) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_localeKey, locale.languageCode);
  state = AsyncData(locale);
}
```

### WR-03: `languageEnglish`/`languageRussian` ARB keys are dead — settings screen hardcodes the same strings instead

**File:** `lib/l10n/app_en.arb:9-10`, `lib/l10n/app_ru.arb:9-10`, `lib/features/settings/settings_screen.dart:61-68`
**Issue:** Both ARB files define `languageEnglish`/`languageRussian` (identically, "English"/"Русский", in both locale files — clearly intended as the always-native-form language names for the picker). `AppLocalizations` generates getters for both. But `settings_screen.dart` never calls `AppLocalizations.of(context)!.languageEnglish` / `.languageRussian` — it hardcodes the same literal strings directly:
```dart
RadioListTile<Locale>(
  title: const Text('English'),
  value: const Locale('en'),
),
RadioListTile<Locale>(
  title: const Text('Русский'),
  value: const Locale('ru'),
),
```
This leaves two sources of truth for the same two labels (grep confirms `languageEnglish`/`languageRussian` are referenced nowhere in `lib/` outside the generated localization files themselves). Every other label in this screen is threaded through `AppLocalizations.of(context)!...`; these two are the only exception, with no explanatory comment. If a third language is ever added, or one of these two names needs a tweak, there are now two places to update and no compiler/test signal tying them together (the ARB keys could drift from the widget without either failing).
**Fix:** Route the labels through the existing generated getters instead of duplicating the literals:
```dart
RadioListTile<Locale>(
  title: Text(AppLocalizations.of(context)!.languageEnglish),
  value: const Locale('en'),
),
RadioListTile<Locale>(
  title: Text(AppLocalizations.of(context)!.languageRussian),
  value: const Locale('ru'),
),
```

---

_Reviewed: 2026-08-25T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
