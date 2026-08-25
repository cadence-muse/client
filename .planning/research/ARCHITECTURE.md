# Architecture Research: i18n and Duration Input

**Domain:** Flutter mobile app state management and input formatting  
**Researched:** 2026-08-25  
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────┐
│                      MaterialApp Layer                         │
├────────────────────────────────────────────────────────────────┤
│  locale: [Locale from LocaleController]                        │
│  localizationsDelegates: [GlobalMaterialLocalizations, ...]    │
│  themeMode: [ThemeMode from ThemeController]                   │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│              Riverpod State Management Layer                    │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────┐  ┌──────────────────────┐            │
│  │ ThemeController      │  │ LocaleController     │            │
│  │ (already exists)     │  │ (NEW: like Theme)    │            │
│  │ - ThemeMode state    │  │ - Locale state       │            │
│  │ - setThemeMode()     │  │ - setLocale()        │            │
│  └──────────────────────┘  └──────────────────────┘            │
│                                                                │
│  ┌──────────────────────┐                                      │
│  │ StringLocalizer      │                                      │
│  │ (NEW: error codes)   │                                      │
│  │ - localize(code)     │                                      │
│  │ - watches Locale     │                                      │
│  └──────────────────────┘                                      │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│               Widget Tree & UI Components                       │
├────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ SettingsScreen (watches both providers)                 │  │
│  │ - Theme section  [already exists]                       │  │
│  │ - Language section [NEW]                                │  │
│  └─────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ Track Create/Edit Screens (Locale-aware)                │  │
│  │ - Duration field: mm:ss input (NEW TextInputFormatter)  │  │
│  │ - Form labels: localized strings (gen_l10n)             │  │
│  │ - Error messages: localized via StringLocalizer         │  │
│  └─────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **LocaleController** (Riverpod) | Holds current `Locale` state; persists language preference to `flutter_secure_storage` | `@riverpod class LocaleController extends _$LocaleController { Locale build() { ... return _loadPersistedLocale(); } void setLocale(Locale) { ... await _persist(); } }` |
| **StringLocalizer** (Riverpod) | Maps error codes to localized strings; watches `localeControllerProvider` to recompute strings when language changes | `@riverpod String localizeErrorCode(Locale locale, String code) { ... }` or class-based for richer logic |
| **DurationInputFormatter** (TextInputFormatter) | Converts mm:ss input ↔ validates as mm:ss before submit; stores as seconds on the model | `_DurationFormatter extends TextInputFormatter { ... formatEditUpdate(...) { ... convert mm:ss to seconds on blur } }` |
| **LocalizationStringsFacade** (manual or gen_l10n) | Generated or manually-maintained accessor for all UI strings (duplicates existing theme labels, adds new i18n strings) | `.arb` files → `flutter_gen` or similar gen_l10n integration |

## Recommended Project Structure

```
lib/
├── app.dart                          # ROOT: adds Locale to MaterialApp (existing)
├── main.dart                         # Entry point (no changes)
├── providers/
│   ├── theme_provider.dart           # EXISTING: ThemeMode state
│   ├── locale_provider.dart          # NEW: Locale state (mirrors theme pattern)
│   ├── error_localizer_provider.dart # NEW: Error code → string mapping
│   └── [others...]
├── l10n/
│   ├── app_en.arb                    # NEW: English strings (all UI + error codes)
│   ├── app_ru.arb                    # NEW: Russian translations
│   └── l10n.yaml                     # NEW: gen_l10n config (enable codegen)
├── generated/
│   └── l10n/
│       ├── app_localizations.dart    # GENERATED: MainBundle → locale-specific strings
│       ├── app_localizations_en.dart # GENERATED
│       └── app_localizations_ru.dart # GENERATED
├── features/
│   ├── tracks/
│   │   ├── create_track_screen.dart  # MODIFIED: locale-aware, duration input formatting
│   │   ├── edit_track_screen.dart    # MODIFIED: same
│   │   ├── duration_formatter.dart   # NEW: TextInputFormatter for mm:ss
│   │   ├── duration_widget.dart      # NEW: reusable duration field widget
│   │   └── track_formatting.dart     # EXISTING: already has asMinutesSeconds extension
│   ├── settings/
│   │   └── settings_screen.dart      # MODIFIED: add Language section alongside Theme
│   └── [others...]
├── theme/
│   └── app_theme.dart                # EXISTING: theme data (no changes needed)
└── [other layers...]
```

### Structure Rationale

- **`lib/providers/locale_provider.dart`:** Mirrors the existing `theme_provider.dart` pattern exactly — Riverpod-codegen'd controller class, persistent state, single interface. Keeps all reactive state in one layer.
- **`lib/l10n/`:** Standard Flutter conventions for `.arb` files (source of truth for strings). `l10n.yaml` tells Flutter's code generator where to find them.
- **`lib/generated/l10n/`:** Ignored in git. Auto-generated by `flutter gen-l10n` on build. Provides type-safe `AppLocalizations.of(context)` accessor.
- **`lib/providers/error_localizer_provider.dart`:** Stateless or watching-based provider that maps error codes (enum-like or string keyed) to localized messages. Called from catch blocks in screens.
- **`lib/features/tracks/duration_formatter.dart`:** Single-responsibility TextInputFormatter; reusable across create/edit screens.

## Key Integration Points

**With Existing ThemeController Pattern:**
- LocaleController mirrors ThemeController exactly (Riverpod-codegen'd, persistent, single mutator)
- Both watch in MaterialApp via `ref.watch(localeControllerProvider)` and `ref.watch(themeControllerProvider)`
- SettingsScreen extended with Language section, same RadioListTile pattern as Theme

**Locale State → MaterialApp:**
- `MaterialApp.locale` bound to `localeControllerProvider` state
- `localizationsDelegates` includes Material + Cupertino delegates
- `supportedLocales: [Locale('en'), Locale('ru')]`
- Change is reactive; no restart needed

**Duration Input (mm:ss) ↔ API (seconds):**
- TextInputFormatter enforces mm:ss in the field
- Form validator checks format before submit
- `_parseDurationToSeconds()` converts "3:45" → 225 at submit boundary
- API sends/receives `durationSeconds: int` (unchanged)
- Display via existing `asMinutesSeconds` extension

**Error Localization:**
- `ApiException` has `.code` and `.message` fields (already exists)
- `localizeErrorCodeProvider` watches locale and maps codes to localized strings
- Screens use `ref.read(localizeErrorCodeProvider(e.code, e.message))` in catch blocks
- Falls back to server message if code is unknown

**String Localization (gen_l10n):**
- `.arb` files are source of truth
- `flutter gen-l10n` generates `AppLocalizations` class
- Access via `AppLocalizations.of(context)!.stringKey`
- Type-safe; prevents typos and missing translations

## Build Order for Implementation

1. **LocaleController** → Locale persistence to secure storage
2. **.arb files + l10n.yaml** → Run `flutter gen-l10n`
3. **app.dart** → Wire locale to MaterialApp
4. **SettingsScreen** → Add Language section
5. **ErrorLocalizerProvider** → Error code → string mapping
6. **DurationFormatter** → mm:ss input validation
7. **Screen conversions** → Replace hardcoded strings, update error handling, add duration formatting

---

*Architecture research for: Flutter i18n (EN/RU) localization + mm:ss duration input*  
*Researched: 2026-08-25*  
*Status: Ready for downstream planning*
