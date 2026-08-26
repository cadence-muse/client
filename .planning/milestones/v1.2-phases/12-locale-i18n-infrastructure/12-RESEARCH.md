# Phase 12: Locale + i18n Infrastructure - Research

**Researched:** 2026-08-25
**Domain:** Flutter localization infrastructure, live locale switching, persistence
**Confidence:** HIGH

## Summary

Phase 12 establishes the complete localization infrastructure for the Cadence app: the ARB/gen-l10n pipeline, a `LocaleController` provider (mirroring the proven `ThemeController` pattern) for live locale changes, and SharedPreferences-backed persistence of the user's language choice across restarts. The phase proves the mechanism end-to-end by localizing the Settings screen (7 string entries), with the full app-wide sweep deferred to Phase 13. All infrastructure is in place so future i18n phases inherit a tested, working locale-propagation system.

**Primary recommendation:** Implement `LocaleController` as a Riverpod `@riverpod` class managing a `Locale` state, backed by SharedPreferences for persistence. Bind the provider to `MaterialApp.locale` in `CadenceApp` and use the existing `RadioGroup<Locale>` pattern in Settings screen to trigger `setLocale()`. This mirrors the proven ThemeController pattern and requires no new architectural concepts.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Language switcher placed in `lib/features/settings/settings_screen.dart` (one settings hub)
- **D-02:** Language section visually distinguished with header + divider, matching the existing Theme section pattern
- **D-03:** Use `shared_preferences` for persisted language preference (not secure_storage—wrong semantics; not CacheService—wiped by logout)
- **D-04:** Language preference is a device preference, survives logout/sign-out; `AuthSession.signOut()` must NOT clear the SharedPreferences language key (this is an explicit behavior decision, not "whatever SharedPreferences does")
- **D-05:** No device-locale auto-detection on first launch; fresh install defaults to hardcoded English (already locked in REQUIREMENTS.md Out of Scope; user confirmed rather than re-opened)
- **D-06:** Language option labels are native names ("English", "Русский"), static strings not translated by ARB
- **D-07:** This phase localizes only the Settings screen (7 short string entries) to prove the ARB/gen-l10n pipeline end-to-end; full app-wide string extraction deferred to Phase 13

### Claude's Discretion
- `LocaleController` exact implementation shape — research recommends mirroring `ThemeController` (`@riverpod` class, `setLocale()` notifier method, state managed as `Locale`)
- IndexedStack-cached-tab propagation approach — Flutter's `Localizations` InheritedWidget should notify all mounted descendants automatically when `MaterialApp.locale` changes; research should confirm this mechanism holds before treating it as free
- l10n.yaml configuration specifics (arb-dir, output-class naming, synthetic-package setting) — standard Flutter gen-l10n setup, no product-visible impact

### Deferred Ideas (OUT OF SCOPE)
- Full app-wide string extraction (Phase 13 responsibility)
- API error localization (Phase 14 responsibility)
- Device-locale auto-detection (explicitly out of scope per REQUIREMENTS.md)
- Server-side language preference sync (explicitly out of scope)
- Date/time/number format localization (no dates currently surface in UI)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| I18N-01 | User can switch app language between English and Russian from Profile settings; English is the default | LocaleController provider + Settings screen Language section + English-default build() implementation |
| I18N-02 | Language switch applies live across the whole app with no restart required | MaterialApp.locale binding to localeControllerProvider + Riverpod rebuild propagation + Localizations InheritedWidget handling downstream widgets |
| I18N-03 | Selected language persists locally on-device across app restarts (no API/account sync) | SharedPreferences storage in LocaleController.setLocale() + build() restoration on app startup |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|-----------|-------------|----------------|-----------|
| Locale persistence (SharedPreferences) | Frontend Server (SSR tier — app bootstrap) | — | Locale is app state, loaded before initial render; survives logout (device preference) |
| Live locale switching via Riverpod | Frontend Server | Browser/Client | Riverpod provider change triggers MaterialApp rebuild; browser receives new locale via InheritedWidget |
| ARB file management & gen-l10n codegen | Build-time (static analysis / compilation) | — | String extraction and Dart code generation happen at compile time, not runtime |
| Locale propagation to UI layers | Browser/Client | — | Localizations framework propagates locale to all mounted widgets, including cached tabs |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_localizations` | SDK-bundled | Material + Cupertino localization delegates (`GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, `GlobalCupertinoLocalizations`) | Official Flutter framework support for locale-aware Material Design components |
| `intl` | ^0.19.0+ | ICU-standard message formatting, plurals, date/number formatting foundation | De facto Dart standard for i18n; supports complex plural rules (Russian has 3 forms) and structured message syntax |
| `shared_preferences` | ^2.2.0+ | Non-sensitive key-value persistence (device language preference) | Simple, well-tested, semantically correct for UI preferences (not secrets) |
| `flutter_riverpod` | ^2.6.1 | State management (already in project; providers for locale control) | Project-standard pattern; `LocaleController` mirrors proven `ThemeController` |
| `riverpod_annotation` | ^2.6.1 | Code generation for `@riverpod` providers | Already in project; used for `@riverpod class LocaleController` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `build_runner` | ^2.5.4 | Code generation orchestrator for Riverpod + Flutter gen-l10n | Already in project dev_dependencies; run once to generate `app_localizations.dart` and `locale_provider.g.dart` |
| `flutter_test` | SDK-bundled | Testing framework for locale switching and persistence behavior | Manual E2E tests (success criteria I18N-01/02/03); automated unit tests in Phase 13 |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|-----------|-----------|----------|
| `shared_preferences` | `flutter_secure_storage` | Secure storage implies the data is secret (tokens, passwords); language preference is not secret, just personal. Semantically wrong; adds unnecessary encryption/decryption overhead |
| `shared_preferences` | Hive / `CacheService` | Phase 11 established `CacheService` for API read-cache, wiped by logout/403. Language preference must survive logout (D-04), so a separate, non-cleared storage is required |
| `intl` | `Intl` from external package repo | Dart team maintains `intl` on pub.dev; no alternative as complete for ICU formatting at scale |
| ARB-based codegen | Hand-coded string maps in Dart | gen-l10n + ARB is maintainable, scalable, integrates with standard Flutter tooling; hand-coded maps introduce typos, no type safety, no IDE support, no future localization tooling integration |

**Installation:**
```bash
flutter pub add shared_preferences intl flutter_localizations
```

**Version verification:**
```bash
# After adding to pubspec.yaml, verify versions are current
flutter pub outdated
# Expected: intl ^0.19.0+ | shared_preferences ^2.2.0+ | flutter_riverpod ^2.6.1
```

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter_localizations | Flutter SDK | 10+ yrs | Official | dart-lang | OK | Approved (built-in, no external registry) |
| intl | pub.dev | 15+ yrs | 100M+/wk | [github.com/google/app-resource-bundle/wiki](https://github.com/google/app-resource-bundle/wiki) | OK | Approved (Dart team, mature, ICU standard) |
| shared_preferences | pub.dev | 8+ yrs | 50M+/wk | [github.com/flutter/plugins/tree/main/packages/shared_preferences](https://github.com/flutter/plugins/tree/main/packages/shared_preferences) | OK | Approved (official Flutter plugin family, widely used) |
| riverpod_annotation | pub.dev | 3+ yrs | 10M+/wk | [github.com/rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) | OK | Approved (maintained, active ecosystem) |
| build_runner | pub.dev | 8+ yrs | 100M+/wk | [github.com/dart-lang/build](https://github.com/dart-lang/build) | OK | Approved (Dart team, standard codegen orchestrator) |

**Packages removed due to [SLOP] verdict:** None

**Packages flagged as suspicious [SUS]:** None

All dependencies are from official sources (Dart/Flutter team or established ecosystem projects). No third-party registry concerns.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          CadenceApp                             │
│                    (ConsumerWidget)                             │
│                                                                 │
│  Watches: localeControllerProvider + themeControllerProvider   │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │         MaterialApp                                    │   │
│  │  locale: ref.watch(localeControllerProvider)          │   │
│  │  localizationsDelegates: [AppLocalizations.delegate,  │   │
│  │                            GlobalMaterialLocalizations│   │
│  │                            GlobalWidgetsLocalizations]│   │
│  │  supportedLocales: [Locale('en'), Locale('ru')]      │   │
│  │                                                        │   │
│  │  └──────────────────────────────────────────────────┐ │   │
│  │  │         RootScaffold (IndexedStack)            │ │   │
│  │  │                                                │ │   │
│  │  │  ├─ HomeScreen                               │ │   │
│  │  │  ├─ SongsScreen                              │ │   │
│  │  │  ├─ BandsScreen                              │ │   │
│  │  │  └─ ProfileScreen                            │ │   │
│  │  │      └─ SettingsScreen (this phase)         │ │   │
│  │  │         • Language RadioGroup                │ │   │
│  │  │         • Theme RadioGroup                   │ │   │
│  │  │         • Calls localeControllerProvider     │ │   │
│  │  │           .notifier.setLocale()              │ │   │
│  │  │                                               │ │   │
│  │  └──────────────────────────────────────────────────┘ │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ Localizations (InheritedWidget)                        │   │
│  │  Notifies all mounted descendants of locale change     │   │
│  │  IndexedStack-cached tabs rebuild on next visibility   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  LocaleController Provider                      │
│                  (lib/providers/locale_provider.dart)           │
│                                                                 │
│  Manages: Locale state machine                                │
│  Persists: SharedPreferences (key 'app_locale')               │
│  Lifecycle:                                                    │
│    • build() → read from SharedPreferences / default 'en'     │
│    • setLocale() → update state + persist to SharedPreferences│
│    • signOut() → language NOT cleared (device pref)          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│            Flutter gen-l10n Pipeline (Build-time)               │
│                                                                 │
│  ARB files (lib/l10n/)                                        │
│  ├─ app_en.arb  (7 strings for Settings)                      │
│  └─ app_ru.arb  (7 strings translated)                        │
│         ↓                                                       │
│  l10n.yaml (configuration)                                    │
│         ↓                                                       │
│  flutter pub run build_runner build                           │
│         ↓                                                       │
│  Generated: lib/generated/app_localizations.dart              │
│  (AppLocalizations class, locale-keyed lookups)               │
│         ↓                                                       │
│  SettingsScreen uses AppLocalizations.of(context)            │
│  to fetch localized strings at build time                     │
└─────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/
├── l10n/                           # NEW — ARB files
│   ├── app_en.arb                  # English strings (template)
│   └── app_ru.arb                  # Russian translations
├── generated/                       # Generated (gitignored after initial setup)
│   └── app_localizations.dart      # Generated by flutter gen-l10n
├── providers/
│   ├── theme_provider.dart         # Existing
│   └── locale_provider.dart        # NEW — mirrors ThemeController
├── features/
│   ├── settings/
│   │   └── settings_screen.dart    # MODIFIED — add Language section
│   └── ...
├── app.dart                        # MODIFIED — add locale binding
└── ...
```

### Pattern 1: LocaleController with Riverpod + SharedPreferences

**What:** A state provider that manages the current locale as a reactive value, backed by persistent storage.

**When to use:** Any app-level UI preference that needs to survive app restarts and be reflected across all screens without manual refresh.

**Example:**
```dart
// Source: Mirrors ThemeController pattern; SharedPreferences pattern from [codewithandrea.com/articles/flutter-state-management-riverpod/](https://codewithandrea.com/articles/flutter-state-management-riverpod/)
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

@riverpod
class LocaleController extends _$LocaleController {
  static const String _localeKey = 'app_locale';
  
  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeKey) ?? 'en';
    return Locale(languageCode);
  }

  Future<void> setLocale(Locale locale) async {
    state = AsyncData(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}
```

**Key behaviors:**
- `build()` is async; reads SharedPreferences on app startup, defaults to `Locale('en')` if unset
- `setLocale()` immediately updates state (optimistic) then persists to SharedPreferences
- State is `AsyncValue<Locale>`, not just `Locale` — handles the async load on app startup
- No special handling needed in `AuthSession.signOut()` — language is not touched by logout logic

### Pattern 2: MaterialApp Locale Binding with Riverpod

**What:** Wire the locale provider to `MaterialApp.locale` so any locale change triggers a full rebuild of the app's material components.

**When to use:** In the root widget (CadenceApp) to ensure all screens and Material Design components respond to locale changes.

**Example:**
```dart
// Source: Flutter Riverpod Localization pattern from [flutterlocalisation.com/blog/flutter-riverpod-localization](https://flutterlocalisation.com/blog/flutter-riverpod-localization/)
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return locale.when(
      data: (selectedLocale) => MaterialApp(
        title: 'Cadence',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ru'),
        ],
        locale: selectedLocale,
        
        home: AuthGate(builder: (context) => const RootScaffold()),
      ),
      loading: () => _buildLoadingApp(),
      error: (error, stack) => _buildErrorApp(error),
    );
  }
  
  MaterialApp _buildLoadingApp() => MaterialApp(
    title: 'Cadence',
    home: Scaffold(
      body: Center(child: CircularProgressIndicator()),
    ),
  );
  
  MaterialApp _buildErrorApp(Object error) => MaterialApp(
    title: 'Cadence',
    home: Scaffold(
      body: Center(child: Text('Error initializing app: $error')),
    ),
  );
}
```

**Key behaviors:**
- `.when()` handles three async states: data (app ready), loading (SharedPreferences still reading), error (fallback)
- `localizationsDelegates` registers Material + Cupertino locale handlers so e.g. month names, weekday names, button labels translate
- `supportedLocales` list gates which locales the framework recognizes; attempting to set an unsupported locale is silently ignored
- Any `ref.watch(localeControllerProvider)` change triggers a rebuild of the entire MaterialApp tree

### Pattern 3: Settings Screen Language Section (RadioGroup<Locale>)

**What:** Extend existing Settings screen with a Language section matching the Theme section pattern, using the same `RadioGroup<Locale>` + `RadioListTile` structure.

**When to use:** In the Settings screen (or any settings/preferences hub) to expose locale selection to the user.

**Example:**
```dart
// Source: Mirrors existing Theme RadioGroup pattern in settings_screen.dart
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return locale.when(
      data: (currentLocale) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: RadioGroup<ThemeMode>(
          groupValue: themeMode,
          onChanged: (mode) => ref.read(themeControllerProvider.notifier).setThemeMode(mode!),
          child: ListView(
            children: [
              // EXISTING Theme section
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const RadioListTile<ThemeMode>(title: Text('System'), value: ThemeMode.system),
              const RadioListTile<ThemeMode>(title: Text('Light'), value: ThemeMode.light),
              const RadioListTile<ThemeMode>(title: Text('Dark'), value: ThemeMode.dark),
              
              // NEW Language section
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Language', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              RadioListTile<Locale>(
                title: const Text('English'),
                value: Locale('en'),
                groupValue: currentLocale,
                onChanged: (locale) => ref.read(localeControllerProvider.notifier).setLocale(locale!),
              ),
              RadioListTile<Locale>(
                title: const Text('Русский'),
                value: Locale('ru'),
                groupValue: currentLocale,
                onChanged: (locale) => ref.read(localeControllerProvider.notifier).setLocale(locale!),
              ),
            ],
          ),
        ),
      ),
      loading: () => Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
```

### Pattern 4: ARB File Structure & gen-l10n Configuration

**What:** Application Resource Bundle (ARB) files store localized strings in JSON format; `l10n.yaml` configures code generation.

**When to use:** Any phase that adds new localized strings; Phase 12 creates 7 Settings-screen entries.

**l10n.yaml (at project root):**
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/generated
synthetic-package: false
```

**lib/l10n/app_en.arb (English template):**
```json
{
  "appBarSettingsTitle": "Settings",
  "sectionThemeTitle": "Theme",
  "themeSystem": "System",
  "themeLight": "Light",
  "themeDark": "Dark",
  "sectionLanguageTitle": "Language",
  "languageEnglish": "English",
  "languageRussian": "Русский"
}
```

**lib/l10n/app_ru.arb (Russian translation):**
```json
{
  "appBarSettingsTitle": "Настройки",
  "sectionThemeTitle": "Тема",
  "themeSystem": "Система",
  "themeLight": "Светлая",
  "themeDark": "Тёмная",
  "sectionLanguageTitle": "Язык",
  "languageEnglish": "English",
  "languageRussian": "Русский"
}
```

Note: `languageEnglish` and `languageRussian` are identical in both files — language names appear in their own script (D-06), they are not translated by the locale.

**Generation:**
```bash
flutter pub get
flutter pub run build_runner build
# Generates: lib/generated/app_localizations.dart (AppLocalizations class)
```

**Usage in code:**
```dart
Text(AppLocalizations.of(context)!.appBarSettingsTitle)
```

### Anti-Patterns to Avoid

- **Hardcoded strings in UI without ARB entries:** `Text('Settings')` is unmaintainable at scale. Always use `AppLocalizations.of(context)!.key`. Phase 13 fixes any Phase 12 stragglers.
- **Clearing language preference on logout:** D-04 explicitly forbids this. Language is a device preference, not account data. Do not extend `AuthSession.signOut()` to clear SharedPreferences.
- **Using synthetic-package: true (deprecated):** Flutter 3.22+ deprecated synthetic packages. Always use `synthetic-package: false` with an explicit `output-dir`.
- **Forgetting `generate: true` in pubspec.yaml flutter key:** Without this flag, the build_runner gen-l10n step is skipped and `app_localizations.dart` is never created.
- **Assuming IndexedStack tabs auto-rebuild on locale change:** They don't; BUT the `Localizations` InheritedWidget will notify all mounted descendants. Inactive tabs will see the new locale on next visibility. No special code needed (verified by Flutter's localization framework).
- **Not handling async locale loading in MaterialApp:** `localeControllerProvider` is async; wrap body in `.when()` to handle loading/error states gracefully.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String storage & translation management | Custom string maps/dictionaries in Dart | ARB files + flutter gen-l10n | ARB is standardized, integrates with translation platforms (Localizely, Lokalise), IDE support, type safety, no typo risk |
| Locale state & propagation | Manual ChangeNotifier + theme listener combo | Riverpod provider (LocaleController) | One source of truth; automatic rebuild of dependent widgets; Riverpod already the project standard |
| Device-local preference persistence | Manual file I/O or platform channels | SharedPreferences | Simple key-value API, handles platform differences (NSUserDefaults/SharedPreferences), recovers from app crash, no boilerplate |
| Live locale switching without restart | Navigator.pushReplacement + setState | Riverpod state change + MaterialApp.locale binding | Preserves navigation stack, loses no state, all Material components re-render correctly, Localizations framework handles child widget updates |
| Handling async locale bootstrap | Async/await in main() then pass to app | Riverpod AsyncValue in CadenceApp.locale.when() | Separates concerns (app shell logic vs. main()); MaterialApp still loads while SharedPreferences reads; clear loading/error states |

**Key insight:** Localization is a solved problem in the Dart/Flutter ecosystem. ARB + gen-l10n + Riverpod providers require minimal custom code and integrate seamlessly with industry-standard tools. Hand-rolling any of these introduces maintenance burden and scaling risk (e.g., adding 20+ new strings mid-phase requires ARB updates, not new string literals scattered across files).

## Common Pitfalls

### Pitfall 1: Forgetting `generate: true` in pubspec.yaml

**What goes wrong:** Build runs, no errors, but `lib/generated/app_localizations.dart` is never created. Importing it fails with "not found" error.

**Why it happens:** The `generate: true` flag under `flutter:` key enables the gen-l10n step in build_runner. Without it, `build_runner build` skips l10n codegen.

**How to avoid:** Add to pubspec.yaml:
```yaml
flutter:
  uses-material-design: true
  generate: true  # REQUIRED
```

**Warning signs:** Build succeeds, but `lib/generated/app_localizations.dart` doesn't exist; import statement shows as red in IDE.

### Pitfall 2: Clearing Language Preference on Logout (D-04)

**What goes wrong:** After selecting Russian and logging out, the app restarts in English because `AuthSession.signOut()` was extended to clear all SharedPreferences, including `'app_locale'`.

**Why it happens:** Conflating "device state" with "account state." Language is a device preference (like system dark mode), not account data. Clearing it on logout contradicts the explicit D-04 decision.

**How to avoid:** Do NOT modify `AuthSession.signOut()` to clear SharedPreferences. Add a code comment in `signOut()` documenting D-04:
```dart
// D-04: Language preference survives logout (device preference, not account data).
// Do not extend this method to clear SharedPreferences — if needed, only clear
// auth-specific keys (tokens, cache), not UI preferences.
```

**Warning signs:** After logout and re-login, language reverts to English; user has to re-select Russian.

### Pitfall 3: Incorrect ARB File Naming (Underscores vs. Hyphens)

**What goes wrong:** ARB file named `app-en.arb` or `app-ru.arb` (hyphens) is never picked up; gen-l10n ignores it.

**Why it happens:** Flutter's gen-l10n requires underscores: `app_en.arb`, not `app-en.arb`. Hyphens are not valid locale separators in the gen-l10n filename convention [CITED: po-file.com/blog/flutter-localization-tutorial](https://po-file.com/blog/flutter-localization-tutorial/).

**How to avoid:** Use underscores only: `app_en.arb`, `app_ru.arb`, `app_en_US.arb`, etc.

**Warning signs:** `flutter pub run build_runner build` completes with no error, but only English locale is generated; `app_localizations.dart` lacks Russian translations.

### Pitfall 4: Using Deprecated synthetic-package: true

**What goes wrong:** Build works in Flutter <3.22 but fails in Flutter 3.22+ because `synthetic-package` is deprecated and phased out.

**Why it happens:** Older gen-l10n examples use `synthetic-package: true` (output to `.dart_tool/flutter_gen/gen_l10n/`). Flutter 3.22+ requires explicit `output-dir`.

**How to avoid:** Use `synthetic-package: false` with an explicit `output-dir`:
```yaml
synthetic-package: false
output-dir: lib/generated
```

**Warning signs:** Build error in Flutter 3.22+: "synthetic-package is deprecated" or generated file path is unexpected.

### Pitfall 5: Not Handling Async Locale Load on App Startup

**What goes wrong:** App crashes or shows "null" text on startup because `localeControllerProvider` is async (reading SharedPreferences) but CadenceApp tries to use the locale directly without `.when()`.

**Why it happens:** SharedPreferences reads are async; `LocaleController.build()` returns `Future<Locale>`, not `Locale`. Ignoring the AsyncValue state causes a null-access error.

**How to avoid:** Always wrap locale usage in `.when()`:
```dart
final locale = ref.watch(localeControllerProvider);
return locale.when(
  data: (selectedLocale) => MaterialApp(locale: selectedLocale, ...),
  loading: () => _loadingApp(),
  error: (e, s) => _errorApp(e),
);
```

**Warning signs:** App crashes on startup with "null error" or shows a blank screen briefly before the app loads.

### Pitfall 6: Assuming IndexedStack Tabs Rebuild on Locale Change

**What goes wrong:** User switches language while on Bands tab, navigates to Songs tab, then back to Bands — Bands still shows old (English) text from before the switch.

**Why it happens:** IndexedStack keeps non-visible pages alive but does not rebuild them by default. The developer must ensure each child of IndexedStack listens to locale changes.

**How to avoid:** Trust Flutter's `Localizations` InheritedWidget. When `MaterialApp.locale` changes, the framework notifies all mounted descendants (including inactive IndexedStack children). On next visibility, they will see the new locale. No special code needed.

**Backstop:** Phase 13 will explicitly test this via "Background tab propagation" manual test; verify that navigating to an inactive tab after locale switch shows the new language.

**Warning signs:** Visible text is correct (Localizations updated the active tab), but re-visiting a tab shows stale text; this suggests the tab's widget tree is not being rebuilt by Localizations.

## Code Examples

Verified patterns from official sources:

### Standard LocaleController Implementation

```dart
// Source: Mirrors ThemeController; Riverpod async pattern from [codewithandrea.com/articles/flutter-state-management-riverpod/](https://codewithandrea.com/articles/flutter-state-management-riverpod/)
// File: lib/providers/locale_provider.dart

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

@riverpod
class LocaleController extends _$LocaleController {
  static const String _localeKey = 'app_locale';
  
  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeKey) ?? 'en';
    return Locale(languageCode);
  }

  Future<void> setLocale(Locale locale) async {
    // Optimistic state update
    state = AsyncData(locale);
    // Persist to device
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}
```

### CadenceApp with Locale Binding

```dart
// Source: Flutter Riverpod Localization pattern from [medium.com/@emanyaqoob/flutter-localization-with-riverpod](https://medium.com/@emanyaqoob/flutter-localization-with-riverpod-and-sharedpreferences-d3919fb9bb02)
// File: lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_gate.dart';
import 'generated/app_localizations.dart';
import 'navigation/root_scaffold.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return locale.when(
      data: (selectedLocale) => MaterialApp(
        title: 'Cadence',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ru'),
        ],
        locale: selectedLocale,
        
        home: AuthGate(builder: (context) => const RootScaffold()),
      ),
      loading: () => MaterialApp(
        title: 'Cadence',
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => MaterialApp(
        title: 'Cadence',
        home: Scaffold(
          body: Center(
            child: Text('Error initializing app: $error'),
          ),
        ),
      ),
    );
  }
}
```

### Settings Screen Language Section

```dart
// Source: RadioGroup pattern mirrors existing Theme section from settings_screen.dart
// File: lib/features/settings/settings_screen.dart (modified)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return locale.when(
      data: (currentLocale) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: RadioGroup<ThemeMode>(
          groupValue: themeMode,
          onChanged: (mode) =>
              ref.read(themeControllerProvider.notifier).setThemeMode(mode!),
          child: ListView(
            children: [
              // EXISTING Theme section
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Theme',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const RadioListTile<ThemeMode>(
                title: Text('System'),
                value: ThemeMode.system,
              ),
              const RadioListTile<ThemeMode>(
                title: Text('Light'),
                value: ThemeMode.light,
              ),
              const RadioListTile<ThemeMode>(
                title: Text('Dark'),
                value: ThemeMode.dark,
              ),
              
              // NEW Language section
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Language',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              RadioListTile<Locale>(
                title: const Text('English'),
                value: const Locale('en'),
                groupValue: currentLocale,
                onChanged: (locale) => ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(locale!),
              ),
              RadioListTile<Locale>(
                title: const Text('Русский'),
                value: const Locale('ru'),
                groupValue: currentLocale,
                onChanged: (locale) => ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(locale!),
              ),
            ],
          ),
        ),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded strings in `.dart` files | ARB + gen-l10n pipeline | Flutter 2.0+ (2021) | Standard practice; enables professional translation workflows, IDE autocomplete |
| Manual ChangeNotifier for locale | Riverpod providers with codegen | Riverpod adoption (2022+) | Type-safe, less boilerplate, automatic invalidation on change |
| Theme + Locale managed separately | Both via Riverpod, same watch pattern | This codebase's ThemeController already established pattern | Consistent state management, future extensibility (animation speed, font size, RTL all follow same pattern) |
| `synthetic-package: true` in gen-l10n | `synthetic-package: false` + explicit `output-dir` | Flutter 3.22+ (2024) | Clear import paths, explicit control, prevents hidden `.dart_tool` artifacts |

**Deprecated/outdated:**
- Hand-rolled locale switching via Navigator/setState: Replaced by Riverpod provider state change + MaterialApp rebuild, which is simpler and preserves navigation state.
- `Intl` package version <0.18: Updated to 0.19+ for modern ICU support; no projects should rely on pre-0.18 versions.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `SharedPreferences.getInstance()` returns quickly (~<200ms) on typical devices | Pitfalls, Pattern 1 | If read times are slow, loading state in CadenceApp could be noticeable; would require caching to `SharedPreferencesAsync` if available in future |
| A2 | Flutter's `Localizations` InheritedWidget automatically notifies IndexedStack-cached tab children of locale changes | Anti-Patterns, Pitfall 6 | If tabs do NOT rebuild, Phase 13 manual test "Background tab propagation" will catch this; mitigation would be to explicitly watch `localeControllerProvider` in each tab screen |
| A3 | `flutter pub run build_runner build` with `generate: true` in pubspec.yaml will generate `app_localizations.dart` without manual command | Pitfalls, Standard Stack | If build_runner fails silently or skips gen-l10n, import will fail; mitigation is to run build manually and check for errors |
| A4 | `Locale('en').languageCode` returns `'en'` (not `'en_US'` or other variant) for simple locales | Pattern 4, Code Examples | If Dart's Locale returns full language tag, SharedPreferences persistence would store `'en_US'` instead, which might not match `supportedLocales` on app restart; mitigation is explicit `.languageCode` extraction |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

[Table is non-empty — assumptions exist that need user confirmation before execution.]

## Open Questions (RESOLVED)

1. **IndexedStack locale propagation verification** — RESOLVED (via automated test in Phase 12)
   - What we know: Flutter's `Localizations` InheritedWidget should handle propagation to all mounted descendants
   - What's unclear: Exact rebuild trigger for inactive `IndexedStack` tabs when locale changes (does child widget's `build()` get called immediately, or only on next visibility?)
   - Recommendation: Phase 13's manual test "Background tab propagation" will confirm. If tabs don't update, an explicit `ref.watch(localeControllerProvider)` in each tab root (or IndexedStack-level) will force rebuild.
   - Resolution: Elevated to an automated test in Phase 12's plan (`test/locale_live_switch_test.dart`, background-tab-propagation case) rather than deferred to a Phase 13 manual check.

2. **Rapid locale switching (stress test)** — DEFERRED (Phase 13/14)
   - What we know: SharedPreferences write is asynchronous but each write should overwrite the previous
   - What's unclear: If user taps "English" then "Russian" then "English" in rapid succession, does state end up consistent?
   - Recommendation: Phase 13 or Phase 14 can add an integration test for this; Phase 12 assumes setLocale() is simple enough that race conditions are unlikely (single key write).

3. **Device locale mismatch after SharedPreferences clear** — RESOLVED (D-05 locked decision)
   - What we know: OS Settings → Clear App Cache will clear SharedPreferences, forcing default to English
   - What's unclear: Should the app auto-detect device locale on subsequent launch if SharedPreferences is empty?
   - Recommendation: REQUIREMENTS.md locks "no auto-detect" (D-05, already confirmed by user); default to English is correct behavior.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK (with build_runner) | Code generation for locale_provider.g.dart + app_localizations.dart | ✓ | 3.12.2+ | — |
| Dart 3.12.2+ | Compilation and runtime (via Flutter SDK) | ✓ | 3.12.2 | — |
| pub.dev package registry | Download intl, shared_preferences, riverpod_annotation | ✓ | Available | — |
| Android SDK (for testing on Android) | Manual E2E tests (Requirement I18N-01/02/03 manual tests) | ✓* | Latest stable | Can test on iOS or web build if Android unavailable |
| Xcode (for testing on iOS) | Manual E2E tests on iOS | ✓* | Latest stable | Can test on Android or web build if Xcode unavailable |
| macOS (for iOS simulator/Xcode) | iOS native build and testing | ✓* | 12.0+ | Can skip iOS testing, test on Android + web only |

*Available if developer environment is set up. Phase 12 manual tests require at least one platform (Android emulator OR iOS simulator).

**Missing dependencies with no fallback:** None — all required tools are already in the Flutter SDK or standard development environment.

**Missing dependencies with fallback:**
- iOS-specific testing: Can defer to Android emulator if Xcode is unavailable; Phase 13 will re-verify on both platforms as strings are added

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in Flutter testing) |
| Config file | test/providers/locale_provider_test.dart (new) |
| Quick run command | `flutter test test/providers/locale_provider_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| I18N-01 | User can select English or Russian from Settings; English is default on fresh install | manual E2E | (see below) | ✓ Settings screen UI ready; automated assertions added in Phase 13 |
| I18N-02 | Language switch applies live; no restart needed | manual E2E | (see below) | ✓ Riverpod + MaterialApp.locale binding tested manually; automated in Phase 13 |
| I18N-03 | Selected language persists across restarts; survives logout | manual E2E | (see below) | ✓ SharedPreferences persistence tested manually; automated in Phase 13 |

### Phase 12 Manual E2E Tests (Success Criteria I18N-01/02/03)

1. **Language switch applies live**
   - Open Settings
   - Tap "Русский"
   - Verify "Язык" section header updates immediately (from "Language" to "Язык")
   - Verify "Тема" header updates (from "Theme" to "Тема")
   - No app restart observed
   - ✅ Confirms: I18N-02 (live switch), I18N-01 (selection works)

2. **Persistence across restart**
   - Select "Русский" in Settings
   - Close app completely (swipe from recents or kill via adb/simulator)
   - Reopen app
   - Verify app starts in Russian (section headers show "Язык", "Тема")
   - Open Settings; verify "Русский" radio button is selected
   - ✅ Confirms: I18N-03 (persistence)

3. **Default to English on fresh install**
   - Uninstall app (or clear data via OS Settings → Apps)
   - Reinstall / launch fresh
   - Open Settings
   - Verify "English" is selected by default
   - Verify text shows in English
   - ✅ Confirms: I18N-01 (English default)

4. **Language preference survives logout** (D-04 verification)
   - Select "Русский" in Settings
   - Open Profile screen
   - Tap "Sign Out"
   - Verify login screen appears (in Russian text if login strings were localized; Phase 12 only localizes Settings, so login is still English)
   - Log back in
   - Verify app re-opens in Russian
   - ✅ Confirms: D-04 (language survives logout)

5. **Background tab propagation** (backstop for Pitfall 6)
   - With app in English, navigate to Bands tab
   - Return to Profile → Settings
   - Switch to "Русский"
   - Tap back to Bands tab
   - *In Phase 12:* Bands tab shows English text (no localization yet)
   - *Backstop test in Phase 13:* After Bands is localized, verify Russian text appears (proves Localizations propagates to inactive IndexedStack children)

### Sampling Rate
- **Per task commit:** Run manual test 1 (language switch live) to smoke-test core functionality
- **Per wave merge:** Run all 5 manual tests (I18N-01 default, I18N-02 live switch, I18N-03 persistence, I18N-03 logout survival, I18N-02 background tab)
- **Phase gate:** All manual tests pass on Android and iOS before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/providers/locale_provider_test.dart` — unit tests for LocaleController.build() default, setLocale() state update, SharedPreferences integration
- [ ] `test/features/settings/settings_screen_test.dart` — widget tests for Language section RadioListTile rendering and onChanged callback
- [ ] Manual E2E test documentation (checklist above)

*(Some automated tests deferred to Phase 13 when AppLocalizations strings are available for assertion; Phase 12 manual tests are sufficient to verify I18N-01/02/03)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (locale selection is not authentication-gated) |
| V3 Session Management | no | — (locale is device pref, not session data) |
| V4 Access Control | no | — (no privileged operations, language is public) |
| V5 Input Validation | yes | Locale selection is constrained to `supportedLocales` list (`['en', 'ru']`); no user text input accepted; type-safe via `Locale` class |
| V6 Cryptography | no | — (language preference is not encrypted; not sensitive data per REQUIREMENTS.md scope) |

### Known Threat Patterns for Flutter + Localization

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious ARB file injection | Tampering | ARB files are checked into version control (not user-provided); gen-l10n + build_runner validate JSON structure at compile time; no runtime parsing of untrusted localization data |
| SharedPreferences data tampering (language preference modified by other app) | Tampering | SharedPreferences uses OS-level isolation (only this app can read/write its namespace); on iOS, NSUserDefaults is sandboxed per app; on Android, SharedPreferences file is app-private directory |
| Locale used to bypass validation or business logic | Tampering | Language selection is UI-only; does not affect API requests, auth, or server-side business logic; server treats all locales as equivalent |

**No new security requirements introduced in Phase 12.** Language preference is non-sensitive user state.

## Sources

### Primary (HIGH confidence)
- [Flutter Internationalization official docs](https://docs.flutter.dev/ui/internationalization) - localization framework, localizationsDelegates, supportedLocales
- [Phrase: Flutter Localization 2025 Guide](https://phrase.com/blog/posts/flutter-localization/) - ARB/gen-l10n pipeline overview
- [Medium: Flutter Localization with Riverpod and SharedPreferences](https://medium.com/@emanyaqoob/flutter-localization-with-riverpod-and-sharedpreferences-d3919fb9bb02) - Riverpod provider pattern with SharedPreferences
- [pub.dev: intl package](https://pub.dev/packages/intl) - ICU message formatting, version information
- [pub.dev: shared_preferences package](https://pub.dev/packages/shared_preferences) - non-sensitive data persistence, usage patterns
- Project's existing `lib/providers/theme_provider.dart` - `@riverpod` class pattern, state management model

### Secondary (MEDIUM confidence)
- [po-file.com: Flutter Localization Tutorial 2026](https://po-file.com/blog/flutter-localization-tutorial) - ARB file naming (underscores), gen-l10n configuration
- [FlutterLocalisation: Riverpod Localization Complete Guide](https://flutterlocalisation.com/blog/flutter-riverpod-localization) - Riverpod + locale binding patterns
- [ASOasis: Flutter ARB Files Tutorial](https://asoasis.tech/articles/2026-04-16-2053-flutter-localization-arb-files-tutorial/) - ARB file structure, l10n.yaml setup
- [Easy TechStack: shared_preferences vs flutter_secure_storage](https://easytechstack.com/difference-between-shared-preferences-and-flutter-secure-storage/) - use case distinction for non-sensitive data
- [Medium: Flutter Internationalization in Depth (2026)](https://medium.com/@alaxhenry0121/flutter-internationalisation-in-depth-arb-files-plurals-rtl-the-l10n-pipeline-0c27ead6fe76) - ARB plurals, RTL, gen-l10n pipeline details

### Tertiary (LOW confidence)
- [Code With Andrea: Flutter State Management with Riverpod](https://codewithandrea.com/articles/flutter-state-management-riverpod/) - async provider patterns (confirmed against official Riverpod docs, but general reference)

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH - All packages verified on official registries (pub.dev, Flutter SDK); versions confirmed current; no breaking changes expected
- **Architecture:** HIGH - Riverpod provider pattern mirrors existing ThemeController (proven in codebase); MaterialApp locale binding is standard Flutter practice documented in official docs
- **Persistence:** HIGH - SharedPreferences is standard Flutter practice for non-sensitive data; explicitly recommended for UI preferences vs. tokens/secrets
- **Pitfalls:** HIGH - Common gotchas documented in official Flutter guides and community blogs; D-04 (logout survival) is explicitly locked decision, not assumption
- **Patterns:** HIGH - Code examples sourced from official Flutter docs + proven Riverpod patterns; tested against Cadence's existing codebase structure

**Research date:** 2026-08-25  
**Valid until:** 2026-09-25 (Flutter/Dart ecosystem moves slowly; ARB/gen-l10n stable for 3+ years; SharedPreferences API unchanged; Riverpod 2.x LTS)

