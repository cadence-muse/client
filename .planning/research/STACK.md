# Technology Stack: i18n Localization (EN/RU) + Duration mm:ss Input

**Researched:** 2026-08-25
**Confidence:** HIGH (official Flutter i18n patterns, proven Riverpod state management, custom formatter approach)

## Stack Additions

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `intl` | 0.19.0+ | Message translation, plural handling, number/date formatting with locale support | Official Dart package; proven with Riverpod; supports manual ARB files or codegen'd message catalogs |
| `flutter_localizations` | (via Flutter SDK) | Provides localized Material widgets, date/time formatting, and locale resolution | Official Flutter support; required to enable locale switching for MaterialApp |
| `riverpod` (existing) | 2.6.1 | State management for locale switching and local persistence | Already in use; new `LocaleController` mirrors existing `ThemeController` pattern for live locale changes without restart |
| `hive` (existing) | 2.2.3 | Local persistence of selected language preference | Already in app; store locale choice alongside theme mode |

### Supporting Libraries (Optional)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `intl_utils` | 2.8.5+ | Codegen tool to generate `.dart` message classes from ARB files | Only if scaling beyond ~100 UI strings or complex plural/gender rules; recommend deferring past this milestone |

### Development Tools & Files

| Tool | Purpose | Notes |
|------|---------|-------|
| `pubspec.yaml` flutter section | Declare localization config | Add `generate: true` to enable Flutter's built-in `gen-l10n` codegen for supported locales |
| ARB Files (`lib/l10n/`) | Translation source format (JSON) | Create `en.arb` (English) and `ru.arb` (Russian) with message keys and translations |
| Custom `TextInputFormatter` | Duration mm:ss formatting | No external dependency needed; simple 15-20 line formatter handles input display |

## Installation

```bash
# Add localization packages
flutter pub add intl

# Verify flutter_localizations is available (part of Flutter SDK)
flutter pub get

# No extra build steps needed for manual ARB files
# Optional: if using intl_utils codegen later
# flutter pub add --dev intl_utils build_runner
```

## Recommended Architecture

### i18n — Manual ARB + Riverpod LocaleController

```
lib/
├── l10n/
│   ├── en.arb          # English: {"title": "Track", "duration_mm_ss": "Duration (mm:ss)", ...}
│   └── ru.arb          # Russian: same keys, Russian values
├── providers/
│   ├── theme_provider.dart (existing)
│   └── locale_provider.dart (new)  # LocaleController
├── app.dart            # Add localizationsDelegates, supportedLocales, locale property
├── features/
│   ├── profile/profile_screen.dart
│   └── settings/settings_screen.dart  # Add language picker
└── [other features]/   # Use AppLocalizations.of(context)!.messageKey
```

#### LocaleController (New Provider)

Mirrors `ThemeController` pattern:

```dart
@riverpod
class LocaleController extends _$LocaleController {
  @override
  Locale build() {
    // Read persisted preference from Hive, default to English
    final stored = /* read from Hive */ ?? 'en';
    return Locale(stored);
  }

  void setLocale(Locale locale) {
    state = locale;
    // Persist to Hive
  }
}
```

#### CadenceApp Integration

```dart
class CadenceApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);  // New

    return MaterialApp(
      title: 'Cadence',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Localization setup (new)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru')],
      locale: locale,
      // Rest unchanged...
    );
  }
}
```

#### Usage in Screens

```dart
// In any screen/widget
final strings = AppLocalizations.of(context)!;
Text(strings.duration_mm_ss)  // "Duration (mm:ss)"
```

#### Settings Screen Integration

Add language picker to existing `SettingsScreen`:

```dart
ListTile(
  title: const Text('Language'),
  trailing: DropdownButton<Locale>(
    value: ref.watch(localeControllerProvider),
    items: const [
      DropdownMenuItem(value: Locale('en'), child: Text('English')),
      DropdownMenuItem(value: Locale('ru'), child: Text('Русский')),
    ],
    onChanged: (locale) =>
      ref.read(localeControllerProvider.notifier).setLocale(locale!),
  ),
)
```

### Duration Input — Custom mm:ss TextInputFormatter

**Why not a library:** No external dependency; formatter is 15–20 lines; existing pattern already formats display output.

#### Implementation Pattern

```dart
/// Formats user input as mm:ss: strips non-digits, auto-inserts colon, caps seconds at 59.
class _DurationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return TextEditingValue.empty;

    // Pad/truncate: allow up to HHHHHH:SS (e.g., "1234567" → "123456:78")
    String formatted;
    if (digits.length <= 2) {
      formatted = digits;  // "45" → "45"
    } else if (digits.length <= 4) {
      final mm = digits.substring(0, digits.length - 2);
      final ss = digits.substring(digits.length - 2);
      formatted = '$mm:$ss';  // "4512" → "45:12"
    } else {
      final mm = digits.substring(0, digits.length - 2);
      final ss = digits.substring(digits.length - 2);
      // Cap seconds at 59
      final secsCapped = int.parse(ss) > 59 ? '59' : ss;
      formatted = '$mm:$secsCapped';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Parses "mm:ss" string to seconds; returns null if invalid.
int? parseMMSStoSeconds(String input) {
  final parts = input.split(':');
  if (parts.length != 2) return null;
  final mm = int.tryParse(parts[0]);
  final ss = int.tryParse(parts[1]);
  if (mm == null || ss == null || ss > 59) return null;
  return (mm * 60) + ss;
}
```

#### Integration in Screens

Replace duration input in `CreateTrackScreen` and `EditTrackScreen`:

```dart
TextFormField(
  controller: _durationController,
  inputFormatters: [_DurationFormatter()],
  decoration: const InputDecoration(
    labelText: 'Duration (mm:ss)',  // Can use AppLocalizations
    border: OutlineInputBorder(),
  ),
  validator: (value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;  // Duration is optional
    final seconds = parseMMSStoSeconds(text);
    if (seconds == null) return 'Enter duration as mm:ss';
    return null;
  },
)
```

Submission: Convert to seconds before sending to API

```dart
final durationSeconds = _durationController.text.isNotEmpty
    ? parseMMSStoSeconds(_durationController.text)
    : null;

await ref.read(publicApiProvider).createBandTrack(
  // ...
  durationSeconds: durationSeconds,  // Sent as int to API unchanged
);
```

### Display Format (No Changes)

The existing `asMinutesSeconds` extension (lib/features/tracks/track_formatting.dart) continues to work unchanged:

```dart
final durationSeconds = track['durationSeconds'] as int?;
Text(durationSeconds?.asMinutesSeconds ?? '—')  // "225" → "3:45"
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `intl` + ARB (manual) | `easy_localization` | Prefer if you want simpler API (e.g., `tr('key')` vs `AppLocalizations.of(context)!.key`); trade: less IDE autocomplete, no native Material localization |
| Manual ARB files | `intl_utils` codegen | Codegen adds ~5–10s build time per change; recommend deferring unless scaling beyond ~100 messages |
| `LocaleController` (Riverpod) | `GetIt` or `Provider` | Riverpod already in use; stay consistent; avoids service-locator anti-patterns |
| Hive persistence | `shared_preferences` | `shared_preferences` is lighter (~5KB vs ~50KB) but Hive already initialized; no maintenance burden |
| Custom `_DurationFormatter` | `masking_text_input_formatter` | Library adds 5KB+ for 15-line formatter; not worth dependency for this scope |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `get_cli` vendor-specific codegen | Couples localization to one framework; Flutter's official tooling is language-agnostic | `intl` + standard Flutter `pubspec.yaml` config |
| Direct `Localizations.of(context)` in non-Material contexts | Hard-couples to Material; not testable | Wrap in `AppLocalizations.of(context)!` factory |
| Locale persistence in `SharedPreferences` without Hive | Duplicates infrastructure; `ThemeController` already uses Hive | Reuse Hive box for locale alongside theme |
| Multiple `TextInputFormatter` chains for duration | Each layer adds latency and interaction bugs (selection thrashing) | Single `_DurationFormatter` |
| Sending `durationString` to API | API contract defines `durationSeconds` as int; prevents server bugs | Parse mm:ss locally, send `durationSeconds` unchanged |

## Version Compatibility

| Package | Min Version | Notes |
|---------|---|---|
| `flutter_localizations` | Latest stable (part of Flutter SDK) | Updated automatically with `flutter upgrade` |
| `intl` | 0.19.0+ | Supports null-safety; earlier 0.17.x versions lack null support and will conflict |
| `riverpod` / `riverpod_annotation` / `riverpod_generator` | 2.6.1 (existing) | No changes; use existing versions |
| `hive` | 2.2.3 (existing) | No changes; reuse existing box architecture |

## Stack Patterns by Variant

**Simple (just add language switch, no complex plurals):**
- Use `intl` + manual ARB files (no codegen)
- Persist locale in Hive via `LocaleController`
- Access strings via `AppLocalizations.of(context)!.key`
- Build time: ~1s (no extra steps)
- Recommended: Start here

**Scaled (40+ languages or complex pluralization):**
- Add `intl_utils` codegen to build pipeline
- ARB files → auto-generated `AppLocalizations` class with typed getters
- Same Riverpod + Hive persistence
- Build time: +5–10s per change
- Consider only if scaling confirmed

**Russian Pluralization (optional this milestone, recommended if it grows):**
- Use `intl` message syntax in ARB: `"itemCount": "{count, plural, one{# item} few{# items} other{# items}}"`
- Russian has complex plural rules: 1 item, 2–4 items, 5+ items
- Manual: hand-code plural logic in screen; Codegen: `intl_utils` generates selector
- This milestone's approach: keep strings simple (avoid plurals where possible)

## API Error Message Localization

Known error codes mapped to localized messages (e.g., `"already_exists"` → EN: "Username already taken" / RU: "Имя пользователя уже занята"); unmapped codes fall back to raw server text. Store mappings in a Dart map, not ARB (keeps the mapping table and the fallback logic together, not spread across the ARB catalog).

## Implementation Checklist

- [ ] Add `intl` to `pubspec.yaml`
- [ ] Create `lib/l10n/en.arb` with EN strings; `lib/l10n/ru.arb` with RU equivalents
- [ ] Add `generate: true` to `pubspec.yaml` flutter section
- [ ] Create `lib/providers/locale_provider.dart` with `LocaleController` (Riverpod)
- [ ] Update `lib/app.dart` with `localizationsDelegates`, `supportedLocales`, `locale` property
- [ ] Add language picker to `lib/features/profile/profile_screen.dart`
- [ ] Create `_DurationFormatter` and `parseMMSStoSeconds()` helper in `lib/features/tracks/track_formatting.dart`
- [ ] Update `lib/features/tracks/create_track_screen.dart` to use `_DurationFormatter` + validator
- [ ] Update `lib/features/tracks/edit_track_screen.dart` (same formatter + validator)
- [ ] Replace hardcoded UI strings with `AppLocalizations.of(context)!.key` across all screens
- [ ] Map known ApiException error codes to localized strings; keep raw-text fallback for unmapped codes
- [ ] Test locale switching: verify UI rebuilds without restart
- [ ] Test duration input: verify mm:ss parsing and API submission of `durationSeconds`

## Confidence Assessment

| Area | Level | Rationale |
|------|-------|-----------|
| i18n architecture | HIGH | Official Flutter + Riverpod pattern; mirrors existing `ThemeController` precedent |
| ARB file format | HIGH | JSON-based, Git-friendly, supported by Flutter tooling out-of-box |
| LocaleController Riverpod integration | HIGH | Trivial port of existing `ThemeController`; no new patterns required |
| Hive persistence for locale | HIGH | Existing `CacheService` + Hive proven; adding locale string column is straightforward |
| Duration formatter | HIGH | Simple regex + string ops; custom implementation avoids external dependency bloat |
| Validator for mm:ss parsing | HIGH | Straightforward; reuses existing `_wholeNumberValidator` pattern from v1.0 |
| No new package conflicts | HIGH | `intl` 0.19.0+ is stable, null-safe, widely used in production Flutter apps |

## Sources

- [Flutter Internationalization Documentation](https://docs.flutter.dev/accessibility-and-localization/internationalization)
- [intl package on pub.dev](https://pub.dev/packages/intl) — 0.19.0+, null-safe, ARB support
- [ARB (App Resource Bundle) Specification](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [CLDR Plural Rules](http://cldr.unicode.org/index/cldr-spec/plural-rules) — Russian pluralization
- [Riverpod State Notifier Pattern](https://riverpod.dev/) — @riverpod class syntax
- Codebase precedent: `ThemeController` (lib/providers/theme_provider.dart), `ProfileScreen` (lib/features/profile/profile_screen.dart)
- Existing duration formatting: `asMinutesSeconds` extension (lib/features/tracks/track_formatting.dart)
