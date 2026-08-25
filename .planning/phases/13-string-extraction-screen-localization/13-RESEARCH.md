# Phase 13: String Extraction & Screen Localization - Research

**Researched:** 2026-08-25
**Domain:** Flutter string extraction, ARB localization, ICU pluralization, localization testing
**Confidence:** HIGH

## Summary

Phase 13 executes the complete string extraction and localization sweep across 30+ files in the Cadence app—replacing all hardcoded UI strings with localized EN/RU lookups, implementing grammatically correct Russian pluralization (1/few/many forms), and establishing a centralized test-strings utility that keeps the existing test suite maintainable as strings move into ARB. The phase reuses the proven ARB/gen-l10n pipeline and LocaleController pattern from Phase 12, adding the first use of ICU plural syntax (`{count, plural, ...}`) to the project.

**Primary recommendation:** (1) Extract all hardcoded strings into ARB keys using the `commonX` prefix convention for cross-screen reuse (D-01–D-04); (2) Implement ICU plural methods `memberCount(int)` and `trackCount(int)` in ARB files with Russian's `one`/`few`/`many` forms per Unicode CLDR rules; (3) Build a `WidgetTester` extension `tester.strings` that reads `AppLocalizations` directly off the pumped tree, replacing hardcoded `find.text('English literal')` calls in tests with `tester.strings.keyName` (D-05–D-08); (4) Verify IndexedStack background-tab locale propagation via integration test to confirm the Localizations InheritedWidget mechanism works end-to-end across inactive tabs.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Strings repeating verbatim across screens unify into shared ARB keys with `commonX` prefix, not per-screen duplicates
- **D-02:** Shared key convention: `commonRetry`, `commonCancel`, `commonDelete`, `commonRequiresConnection`, etc.
- **D-03:** Near-duplicate strings (e.g., ~6 variations of "check connection" error) also merge into one shared key, even if wording changes slightly on some screens
- **D-04:** Split by role: short action words (Delete, Cancel, Save, Create, Retry) use `commonX` shared keys; longer sentence-level copy stays per-screen/per-dialog even when similar
- **D-05:** Test-strings utility wraps `AppLocalizations` directly (reads live off pumped tree) rather than a handwritten constants file—single source of truth is the ARB file
- **D-06:** Access shape is a `WidgetTester` extension: `tester.strings.commonRetry`—reads `AppLocalizations` off currently pumped tree's context
- **D-07:** Migration scope: only touched-file app-copy assertions; test-fixture literals (band names, track titles) never migrate—they are test data, not UI copy
- **D-08:** Test-strings utility covers plural methods too: `tester.strings.memberCount(n)`, `tester.strings.trackCount(n)`—one consistent API surface
- **D-09:** Member count consolidates into one shared ICU-plural ARB method `memberCount(count)`, replacing today's `_membersLabel` helper in `bands_screen.dart:15` and duplicate in `band_detail_screen.dart:127-128`
- **D-10:** `band_detail_screen.dart`'s combined "Owner • N members" string splits into two: a role-label ARB string ("Owner"/"Member") plus separate `memberCount()` call
- **D-11:** Fixed-at-100 max-track messages reuse the same `trackCount()` plural method for grammatically consistent Russian even though only 5+ form renders
- **D-12:** `_maxSetlistTracks` constant consolidates from 3 files into one shared location (e.g., `setlist_formatting.dart`)
- **D-13:** Bottom-nav labels (Home, Bands, Tracks, Setlists, Profile) in `lib/navigation/root_scaffold.dart:42-68` ARE in scope—always-visible
- **D-14:** `lib/widgets/offline_no_cache_view.dart` ("No cached data" / "Connect to the internet...") IS in scope
- **D-15:** `lib/widgets/offline_banner.dart` ("Showing cached data — may be out of date") IS in scope
- **D-16:** `lib/features/auth/login_screen.dart` (~4 strings: username/password labels, validator text) IS in scope to avoid English on login screen after logout

### Claude's Discretion
- Exact ARB key names beyond `commonX` and per-screen conventions
- Judgment calls on which near-duplicate strings are "close enough" to merge without changing user meaning
- ICU plural ARB syntax details (`@key` metadata blocks, placeholder typing)
- Any other `lib/widgets/` shared files not surfaced during discussion—apply "always-visible or widely-consumed" reasoning

### Deferred Ideas (OUT OF SCOPE)
- API error localization (Phase 14)
- Settings screen strings (already localized in Phase 12)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| I18N-04 | All UI strings — labels, buttons, dialogs, validation messages — are localized in English and Russian | ARB-based string extraction pipeline from Phase 12; scoped 30+ files (screens, dialogs, shared widgets); LocaleController + Localizations framework handle live propagation; AppLocalizations.of(context) access pattern proven in Phase 12 Settings screen |
| I18N-06 | Count-bearing localized strings use grammatically correct Russian plural forms (1 / 2–4 / 5+), not English-style pluralization | ICU MessageFormat `{count, plural, one{...} few{...} many{...} other{...}}` syntax in ARB files; intl package implements Unicode CLDR pluralization rules for Russian; memberCount() and trackCount() methods generated by build_runner from ARB definitions |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|-----------|-------------|----------------|-----------|
| String extraction & management | Build-time (static analysis / ARB compilation) | Browser/Client UI (rendering) | ARB files define strings at compile time; gen-l10n generates AppLocalizations Dart code; UI layer reads strings at runtime |
| Localized string lookup (AppLocalizations.of) | Browser/Client UI | — | Each screen/widget calls AppLocalizations.of(context)!.keyName at build time to fetch locale-specific string |
| Live locale switching propagation | Frontend Server (app bootstrap / Riverpod) | Browser/Client | LocaleController provider change triggers MaterialApp.locale update; Localizations InheritedWidget notifies all mounted widgets (including IndexedStack-cached tabs) |
| Plural form selection (ICU) | Build-time (gen-l10n codegen) | Browser/Client (runtime rendering) | ARB defines plural rules per locale; build_runner generates memberCount(int) / trackCount(int) methods that select correct form; UI calls method and renders result |
| Test-strings utility (WidgetTester extension) | Test framework | — | Extension reads AppLocalizations off current test tree; provides type-safe access to all localized strings for assertions |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_localizations` | SDK-bundled | Material + Cupertino locale-aware components (month names, button labels, etc.) | Official Flutter framework; automatically provides RTL and locale-specific layouts |
| `intl` | ^0.19.0+ | ICU message formatting, plurals, date/number formatting foundation | De facto Dart standard; implements Unicode CLDR plural rules for 100+ languages including Russian 3-form plurals (one/few/many) |
| ARB files | Standard | Application Resource Bundle JSON files storing translatable strings with ICU syntax | Flutter gen-l10n standard format; integrates with professional translation workflows (Localizely, Phrase, Lokalise); type-safe string generation |
| `flutter pub run build_runner` | SDK-bundled | Code generation orchestrator for gen-l10n (generates app_localizations.dart) | Runs `flutter pub run build_runner build` to transform ARB files → Dart code with typed methods for all strings and plurals |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_test` | SDK-bundled | Testing framework for widget tests and string assertions | Manual and automated tests verifying string extraction, plural form selection, and locale switching behavior |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|-----------|-----------|----------|
| ARB + gen-l10n | Hand-coded string maps in Dart (e.g., a Map<String, String> in const files) | Hand-coded maps: no IDE support, typo-prone, no type safety, no future translation tooling integration, scales poorly (O(n) boilerplate per string) |
| ARB + gen-l10n | External package like `GetX.Get` localization | External packages add dependency bloat; ARB is framework-native, requires no additional packages beyond Flutter SDK |
| ICU plural syntax | Ternary operators in code (e.g., `count == 1 ? '1 member' : '$count members'`) | Ternary only handles 2 forms; Russian needs 3; error-prone across multiple screens; loses type safety; cannot be translated independently |

**Installation:**
```bash
# No new packages needed; all dependencies (intl, flutter_localizations, build_runner) already added in Phase 12
flutter pub get
flutter pub run build_runner build  # Regenerates lib/generated/app_localizations.dart with new keys
```

**Version verification:**
```bash
# Phase 12 should have confirmed these versions already
flutter pub outdated | grep -E 'intl|flutter_localizations'
# Expected: intl ^0.19.0+ | flutter_localizations (SDK-bundled, no version)
```

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter_localizations | Flutter SDK | 10+ yrs | Official | dart-lang | OK | Approved (built-in, no external registry) |
| intl | pub.dev | 15+ yrs | 100M+/wk | [github.com/google/app-resource-bundle](https://github.com/google/app-resource-bundle) | OK | Approved (Dart team, mature, ICU standard) |
| build_runner | pub.dev | 8+ yrs | 100M+/wk | [github.com/dart-lang/build](https://github.com/dart-lang/build) | OK | Approved (Dart team, standard codegen orchestrator) |

**Packages removed due to [SLOP] verdict:** None

**Packages flagged as suspicious [SUS]:** None

All dependencies are from official sources (Dart/Flutter team). No new third-party packages required for Phase 13.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          CadenceApp                             │
│                    (ConsumerWidget)                             │
│                                                                 │
│  Watches: localeControllerProvider (from Phase 12)             │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │         MaterialApp                                    │   │
│  │  locale: ref.watch(localeControllerProvider)          │   │
│  │  localizationsDelegates: [AppLocalizations.delegate,  │   │
│  │                            GlobalMaterialLocalizations│   │
│  │                            GlobalWidgetsLocalizations]│   │
│  │  supportedLocales: [Locale('en'), Locale('ru')]      │   │
│  │                                                        │   │
│  │  ┌──────────────────────────────────────────────────┐ │   │
│  │  │         RootScaffold (IndexedStack)            │ │   │
│  │  │                                                │ │   │
│  │  │  ├─ HomeScreen                               │ │   │
│  │  │  │  └─ Text(AppLocalizations.of(ctx)!.*)    │ │   │
│  │  │  ├─ BandsScreen                              │ │   │
│  │  │  │  └─ Text(AppLocalizations.of(ctx)!.*)    │ │   │
│  │  │  ├─ SetlistsScreen                           │ │   │
│  │  │  │  └─ tester.strings.trackCount(n)          │ │   │
│  │  │  └─ ProfileScreen                            │ │   │
│  │  │     └─ SettingsScreen (Phase 12)             │ │   │
│  │  │                                               │ │   │
│  │  └──────────────────────────────────────────────────┘ │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ Localizations (InheritedWidget, Framework)            │   │
│  │  Notifies all mounted descendants of locale change     │   │
│  │  IndexedStack-cached tabs receive notification        │   │
│  │  (no explicit watch() needed in each tab)             │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                  Flutter gen-l10n Pipeline                        │
│                      (Build-time)                                 │
│                                                                  │
│  ARB Files (lib/l10n/)                                          │
│  ├─ app_en.arb  (Phase 12: 8 strings)                           │
│  │              (Phase 13: +100 strings with plurals)           │
│  │              Total: ~108 keys                                │
│  └─ app_ru.arb  (Russian translations, same keys)               │
│         ↓                                                         │
│  l10n.yaml (configuration)                                      │
│         ↓                                                         │
│  flutter pub run build_runner build                             │
│         ↓                                                         │
│  Generated: lib/generated/app_localizations.dart                │
│  (AppLocalizations class with typed accessor methods)           │
│         ↓                                                         │
│  Code uses: AppLocalizations.of(context)!.memberCount(5)        │
│              → Returns "5 членов" (Russian) or "5 members"      │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│              Test-Strings Utility (New in Phase 13)               │
│                                                                  │
│  Extension on WidgetTester:                                     │
│  • Reads AppLocalizations off pumped tree                       │
│  • Provides typed access: tester.strings.commonRetry            │
│  • Provides plural methods: tester.strings.memberCount(5)       │
│                                                                  │
│  Usage in tests:                                                │
│    expect(find.text(tester.strings.commonRetry), findsOne...)   │
│    expect(find.text(tester.strings.memberCount(5)), findsOne...) │
└──────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/
├── l10n/                           # ARB files (from Phase 12)
│   ├── app_en.arb                  # English strings (template)
│   │                               # Phase 12: 8 keys (Settings)
│   │                               # Phase 13: +100 keys (all screens)
│   └── app_ru.arb                  # Russian translations (same keys)
├── generated/                       # Generated (phase 12 setup)
│   └── app_localizations.dart      # Generated by flutter gen-l10n
├── features/
│   ├── auth/
│   │   ├── login_screen.dart       # MODIFIED: uses AppLocalizations for 4 strings
│   │   └── ...
│   ├── bands/
│   │   ├── bands_screen.dart       # MODIFIED: delete _membersLabel, use AppLocalizations.memberCount()
│   │   ├── band_detail_screen.dart # MODIFIED: split "Owner • N members" into two parts
│   │   └── ...
│   ├── setlists/
│   │   ├── setlist_formatting.dart # MODIFIED: move _maxSetlistTracks const here, use AppLocalizations.trackCount()
│   │   ├── create_setlist_screen.dart
│   │   ├── add_setlist_tracks_dialog.dart
│   │   ├── setlist_detail_screen.dart
│   │   └── ...
│   ├── home/
│   │   ├── home_screen.dart        # MODIFIED: uses AppLocalizations
│   │   └── ...
│   ├── songs/
│   │   ├── tracks_screen.dart      # MODIFIED: uses AppLocalizations
│   │   └── ...
│   ├── settings/
│   │   └── settings_screen.dart    # Phase 12: already localized
│   └── profile/
│       ├── profile_screen.dart     # MODIFIED: uses AppLocalizations
│       └── ...
├── navigation/
│   └── root_scaffold.dart          # MODIFIED: bottom-nav labels use AppLocalizations
├── widgets/
│   ├── offline_no_cache_view.dart  # MODIFIED: uses AppLocalizations
│   ├── offline_banner.dart         # MODIFIED: uses AppLocalizations
│   └── ...
└── ...

test/
├── test_strings.dart               # NEW: WidgetTester extension + AppLocalizations helper
├── features/
│   ├── auth/
│   │   └── login_screen_test.dart  # MODIFIED: assertions use tester.strings.* instead of hardcoded text
│   ├── bands/
│   │   ├── bands_screen_test.dart  # MODIFIED: tester.strings.memberCount(1) instead of '1 member'
│   │   └── ...
│   └── ...
└── ...
```

### Pattern 1: ARB File with Simple Strings (Phase 12 Style, Reused)

**What:** JSON structure storing localized strings with `@@locale` metadata and scoped-prefix key names.

**When to use:** Any UI string that needs localization in multiple languages.

**Example (app_en.arb):**
```json
{
  "@@locale": "en",
  "appBarSettingsTitle": "Settings",
  "commonRetry": "Retry",
  "commonCancel": "Cancel",
  "commonDelete": "Delete",
  "commonRequiresConnection": "Requires connection"
}
```

**Example (app_ru.arb):**
```json
{
  "@@locale": "ru",
  "appBarSettingsTitle": "Настройки",
  "commonRetry": "Повторить",
  "commonCancel": "Отмена",
  "commonDelete": "Удалить",
  "commonRequiresConnection": "Требуется подключение"
}
```

Note: Key names are identical across locales; only the values differ.

### Pattern 2: ICU Plural Syntax for Russian (First Use in Phase 13)

**What:** ICU MessageFormat syntax `{count, plural, one{...} few{...} many{...} other{...}}` in ARB values to handle language-specific plural rules.

**When to use:** Any count-bearing string that changes form based on quantity (e.g., "1 member", "2 members", "5 members").

**Russian Plural Rules via Unicode CLDR [CITED: crowdin.com/blog/icu-guide]:**
- `one`: Numbers ending in 1 (except 11) → nominative singular (e.g., 1, 21, 101)
- `few`: Numbers ending in 2-4 (except 12-14) → genitive singular (e.g., 2, 3, 4, 22, 23, 24)
- `many`: All other numbers (0, 5-20, 25-30, etc.) → genitive plural (e.g., 0, 5, 6, 11, 12, 25)
- `other`: Required fallback (always matches in languages with fewer forms)

**Example (app_en.arb) [VERIFIED: flutter.dev/docs/ui/internationalization]:**
```json
{
  "memberCount": "{count, plural, =0{No members} =1{1 member} other{{count} members}}",
  "@memberCount": {
    "description": "Pluralized member count for band detail",
    "placeholders": {
      "count": {
        "type": "int",
        "format": "compactLong"
      }
    }
  }
}
```

Note: `=0`, `=1` numeric syntax works, but `one`, `few`, `many` is more portable. Russian needs all four: `one`, `few`, `many`, `other`.

**Example (app_ru.arb) [VERIFIED: Unicode CLDR plural rules for Russian]:**
```json
{
  "memberCount": "{count, plural, one{# член} few{# члена} many{# членов} other{# членов}}",
  "@memberCount": {
    "description": "Pluralized member count for band detail",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

**Generated Code (app_localizations.dart, auto-generated by build_runner):**
```dart
String memberCount(int count) {
  return Intl.plural(count,
    one: '$count член',
    few: '$count члена',
    many: '$count членов',
    other: '$count членов',
    locale: localeName,
  );
}
```

**Code Usage in Screens:**
```dart
// English app
Text(AppLocalizations.of(context)!.memberCount(5))
// Renders: "5 members"

// Russian app
Text(AppLocalizations.of(context)!.memberCount(5))
// Renders: "5 членов"

// Russian app with count=2
Text(AppLocalizations.of(context)!.memberCount(2))
// Renders: "2 члена"
```

### Pattern 3: Accessing AppLocalizations in Screens

**What:** Standard Flutter pattern for retrieving localized strings at runtime.

**When to use:** In every screen/widget that displays any user-visible text.

**Example (BandsScreen) [Source: Phase 12 proven pattern from settings_screen.dart]:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';

class BandsScreen extends ConsumerWidget {
  const BandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ... provider watches ...
    
    return Scaffold(
      appBar: AppBar(
        // Use AppLocalizations to get localized string
        title: Text(AppLocalizations.of(context)!.appBarBandsTitle),
      ),
      body: ListView(
        children: [
          // Count-bearing string uses plural method
          Text(AppLocalizations.of(context)!.memberCount(5)),
          // Short action strings use common keys
          ElevatedButton(
            onPressed: () {},
            child: Text(AppLocalizations.of(context)!.commonRetry),
          ),
        ],
      ),
    );
  }
}
```

**Key behaviors:**
- `AppLocalizations.of(context)` retrieves the locale-aware instance
- `!` (bang operator) asserts non-null (safe because Localizations InheritedWidget always provides a value)
- Any `ref.watch(localeControllerProvider)` change triggers MaterialApp rebuild, which rebuilds all descendants via Localizations framework
- No explicit locale watch needed in individual screens—the framework handles propagation

### Pattern 4: Test-Strings Utility (WidgetTester Extension) [VERIFIED: D-05–D-08]

**What:** A WidgetTester extension that reads AppLocalizations off the pumped test widget tree, providing type-safe access to all localized strings.

**When to use:** In all widget tests to assert against localized copy instead of hardcoded English literals.

**Example (test/test_strings.dart) [NEW in Phase 13]:**
```dart
// Source: Mirrors D-05–D-08 requirements; tested against codebase patterns
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/generated/app_localizations.dart';

/// Extension on WidgetTester that provides localized string access for test assertions.
/// 
/// Usage:
///   expect(find.text(tester.strings.commonRetry), findsOneWidget);
///   expect(find.text(tester.strings.memberCount(5)), findsOneWidget);
extension StringsExtension on WidgetTester {
  /// Returns the AppLocalizations instance from the pumped widget tree.
  AppLocalizations get strings {
    final context = element(find.byType(MaterialApp)).widget.home?.key ?? find.byType(Text).first.evaluate().first.context;
    if (context == null) {
      throw StateError(
        'Could not find BuildContext in widget tree. '
        'Make sure CadenceApp (or equivalent MaterialApp) is pumped before accessing tester.strings.',
      );
    }
    return AppLocalizations.of(context)!;
  }
}
```

**Better Implementation (more robust):**
```dart
/// Extension on WidgetTester that provides localized string access for test assertions.
extension StringsExtension on WidgetTester {
  /// Returns the AppLocalizations instance from the pumped widget tree.
  ///
  /// Assumes the first [Text] widget in the tree is mounted within the
  /// [MaterialApp]'s widget tree, which gives us access to the [Localizations]
  /// InheritedWidget.
  AppLocalizations get strings {
    final context = element(find.byType(Text).first).context;
    return AppLocalizations.of(context)!;
  }
}
```

**Test Usage:**
```dart
void main() {
  testWidgets('BandsScreen displays member count with correct plural form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ... provider overrides ...
        ],
        child: const CadenceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Before: hardcoded English literal (brittle, fails after localization)
    // expect(find.text('1 member'), findsOneWidget);

    // After: uses test-strings utility (works in any locale)
    expect(find.text(tester.strings.memberCount(1)), findsOneWidget);

    // Verify plural form changes correctly
    expect(find.text(tester.strings.memberCount(5)), findsWidgets);
  });

  testWidgets('CommonRetry button uses shared ARB key', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ... provider overrides ...
        ],
        child: const CadenceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Uses shared common key (reused across screens)
    expect(find.text(tester.strings.commonRetry), findsWidgets);
  });
}
```

### Pattern 5: Bottom Navigation Labels (NavigationDestination)

**What:** Localized labels for the 5 tab destinations in RootScaffold's NavigationBar.

**When to use:** In root_scaffold.dart when building NavigationDestination list.

**Current Hardcoded Code (root_scaffold.dart:42-68):**
```dart
destinations: const [
  NavigationDestination(label: 'Home', icon: Icon(Icons.home_outlined)),
  NavigationDestination(label: 'Bands', icon: Icon(Icons.groups_outlined)),
  NavigationDestination(label: 'Tracks', icon: Icon(Icons.music_note_outlined)),
  NavigationDestination(label: 'Setlists', icon: Icon(Icons.playlist_play_outlined)),
  NavigationDestination(label: 'Profile', icon: Icon(Icons.person_outline)),
],
```

**After Localization:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  // ... other code ...
  
  return Scaffold(
    // ... body ...
    bottomNavigationBar: NavigationBar(
      // ... other config ...
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: l10n.navHome,
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: l10n.navBands,
        ),
        NavigationDestination(
          icon: Icon(Icons.music_note_outlined),
          selectedIcon: Icon(Icons.music_note),
          label: l10n.navTracks,
        ),
        NavigationDestination(
          icon: Icon(Icons.playlist_play_outlined),
          selectedIcon: Icon(Icons.playlist_play),
          label: l10n.navSetlists,
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: l10n.navProfile,
        ),
      ],
    ),
  );
}
```

**ARB Entries (app_en.arb / app_ru.arb):**
```json
{
  "navHome": "Home",
  "navBands": "Bands",
  "navTracks": "Tracks",
  "navSetlists": "Setlists",
  "navProfile": "Profile"
}
```

### Anti-Patterns to Avoid

- **Mixing hardcoded and localized strings in one file:** Pick one—once a file is localized, all user-visible text should use AppLocalizations. Mixing causes confusion and maintenance burden.
- **Creating per-screen duplicate ARB keys for identical strings:** The moment a string repeats (e.g., "Cancel", "Retry"), create a shared `commonX` key. Duplicates are harder to keep in sync during translation updates.
- **Using String interpolation in ARB values for numbers:** `"You have $count members"` in Dart is unmaintainable at scale. Use ICU plurals `{count, plural, ...}` instead.
- **Assuming test assertions can still use hardcoded English literals:** Any test that does `expect(find.text('English string'), ...)` will fail once that screen is localized. Use `tester.strings.*` from the start.
- **Forgetting to regenerate app_localizations.dart after editing ARB files:** After adding/modifying ARB keys, run `flutter pub run build_runner build` or tests will fail with "undefined method" errors.
- **Not handling async locale load in IndexedStack tabs:** D-08 proves Localizations framework handles this automatically—no explicit watch() needed in each tab. Trust it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String translation management & storage | Custom JSON/Dart map files, handwritten translations | ARB files + flutter gen-l10n | ARB is standardized (ISO 13616), integrates with professional translation platforms (Localizely, Phrase, Lokalise), type-safe Dart generation, IDE autocomplete support |
| Plural form selection across languages | If-else branching in code (e.g., `if (count == 1) ... else ...`) | ICU MessageFormat plurals in ARB + intl package | ICU handles 100+ languages' complex plural rules automatically; adding Russian (3 forms) or Arabic (6 forms) requires only ARB entries, not code changes |
| Live locale switching in screens | Manual ChangeNotifier + widget rebuild orchestration | Riverpod provider change + Localizations InheritedWidget | Framework handles propagation automatically; screens don't need explicit locale watches; Riverpod already the project standard |
| Testable string assertions in widget tests | Hardcoded English literals in find.text() | Test-strings WidgetTester extension reading AppLocalizations off tree | Hardcoded strings break immediately after localization; extension-based access works in any locale, future-proof, type-safe |
| Russian pluralization logic | Custom number-to-form mapping function (1 → singular, 2-4 → genitive singular, 5+ → genitive plural) | ICU plural syntax in ARB + intl package implementation | Hand-rolled logic is error-prone and unmaintainable; intl uses Unicode CLDR (international standard), handles all edge cases (e.g., 11 is "many", not "few" despite ending in 1) |

**Key insight:** String localization at scale (100+ strings across 20+ screens in multiple languages) is solved by standard tools (ARB + gen-l10n + intl). Hand-rolling any component (plural logic, string storage, plural testing) introduces maintenance burden and scaling risk. Phase 13's ~120 new ARB entries are manageable because the pipeline is standardized.

## Common Pitfalls

### Pitfall 1: Forgetting to Regenerate app_localizations.dart After ARB Changes

**What goes wrong:** New ARB key added to app_en.arb, but `flutter pub run build_runner build` is not run. Code tries to call a method that doesn't exist in app_localizations.dart—compile error.

**Why it happens:** Developers edit ARB files and assume the generated code updates automatically. It doesn't. build_runner must be explicitly invoked.

**How to avoid:** After any ARB edit (adding/removing/modifying keys), always run:
```bash
flutter pub run build_runner build
# Or watch mode during development:
flutter pub run build_runner watch
```

**Warning signs:** Compile error like "The method 'memberCount' isn't defined for the class 'AppLocalizations'"; ARB file is valid JSON but generated code doesn't reflect changes.

### Pitfall 2: Inconsistent ARB Keys Across Languages

**What goes wrong:** app_en.arb has key `commonRetry`, but app_ru.arb has the same string under key `commonRetryButton` (typo or misalignment). Build succeeds but the Russian version is never used; app defaults to English string for Russian users.

**Why it happens:** ARB files are maintained separately; a translator or developer renames a key in one file but forgets to update the other.

**How to avoid:** ARB key names MUST be identical across all language files. Run a validation check:
```bash
# Pseudo-code to check key consistency
jq 'keys | sort' lib/l10n/app_en.arb > /tmp/en_keys.txt
jq 'keys | sort' lib/l10n/app_ru.arb > /tmp/ru_keys.txt
diff /tmp/en_keys.txt /tmp/ru_keys.txt
# Should have zero differences (excluding @@locale)
```

Or use a pre-commit hook to validate this.

**Warning signs:** `flutter pub run build_runner build` succeeds, but Russian-language app shows English text for some strings; missing keys in app_localizations.dart for some values (only English generated).

### Pitfall 3: Hardcoded Russian Plural Forms Instead of ICU Syntax

**What goes wrong:** Developer writes a custom helper function like `String pluralizeTracks(int count) => count == 1 ? '1 трек' : '$count треков'`, which only handles 2 forms. Russian needs 3 forms (1 / 2-4 / 5+), so some counts display grammatically incorrect text.

**Why it happens:** Developer is unaware of Russian's 3-form plural rules; assumes English's 2-form singular/plural system is universal.

**How to avoid:** Use ICU plural syntax in ARB files. This phase eliminates custom plural helpers like `pluralizeTracks()` entirely, replacing them with ARB-defined methods like `trackCount(int)`.

**Warning signs:** Russian-language tests fail with assertions like `expect(find.text('2 трека'), findsOneWidget)` but should expect `'2 трека'` (with genitive singular form, not plural). Or users report "grammatically weird" plural text when using the app in Russian (e.g., "2 треков" instead of "2 трека").

### Pitfall 4: Test Assertions Using Hardcoded English Strings After Localization

**What goes wrong:** Test file has `expect(find.text('1 member'), findsOneWidget)` from Phase 12, but after Phase 13 localizes member count to ARB, the app never renders the hardcoded text—test fails.

**Why it happens:** Developer localizes the screen but forgets to update the corresponding test file; or tests run against a locale-specific app but still assert hardcoded English.

**How to avoid:** Use `tester.strings.*` extension for all app-copy assertions. D-07 scopes this to "touched-file" tests, so as each screen is localized in this phase, its test file gets migrated:

**Before:**
```dart
expect(find.text('1 member'), findsOneWidget);
```

**After:**
```dart
expect(find.text(tester.strings.memberCount(1)), findsOneWidget);
```

**Warning signs:** Test runs against English-locale app and fails with "Could not find widget with text '1 member'"; hardcoded English literal is no longer rendered because AppLocalizations.memberCount() is called instead.

### Pitfall 5: IndexedStack Tabs Not Updating on Locale Switch (Mistaken Belief)

**What goes wrong:** Developer switches language while on Home tab, navigates to Bands tab, then back to Home—Home still shows old language text.

**Why it happens:** Developer assumes IndexedStack children don't receive Localizations updates if they weren't visible during the switch. They actually DO receive updates via the InheritedWidget framework.

**How to avoid:** Trust Flutter's Localizations InheritedWidget. When `MaterialApp.locale` changes (triggered by `ref.watch(localeControllerProvider)` change), the framework notifies all mounted descendants, including inactive IndexedStack children. On next visibility, they render the new locale. No special code needed.

**Backstop:** Phase 13 includes an integration test to confirm this: switch locale on Home, navigate to other tabs, return to Home—verify it renders the new language. If it doesn't, the issue is NOT IndexedStack; investigate `MaterialApp.locale` binding or Localizations delegate setup.

**Warning signs:** Visible tab updates correctly on locale switch, but switching back to a previously-visited tab shows stale text; this suggests IndexedStack child is not being rebuilt by Localizations framework (unlikely, but worth investigating the frame rebuilds).

### Pitfall 6: Missing or Invalid Metadata (`@key` blocks) in Plural ARB Entries

**What goes wrong:** ARB file defines a plural string without the `@key` metadata block that specifies placeholder types and descriptions. build_runner either ignores the plural or generates incorrect code.

**Why it happens:** Developer doesn't understand the ARB format; copies a simple string example without realizing plurals require additional metadata.

**How to avoid:** Always include `@key` metadata for plural entries [CITED: localizely.com/flutter-arb]:

```json
{
  "trackCount": "{count, plural, one{# track} few{# tracks} many{# tracks} other{# tracks}}",
  "@trackCount": {
    "description": "Pluralized track count for setlist display",
    "placeholders": {
      "count": {
        "type": "int",
        "format": "compactLong"
      }
    }
  }
}
```

**Warning signs:** `flutter pub run build_runner build` succeeds, but the generated trackCount() method is missing from app_localizations.dart; or method exists but doesn't handle plural forms correctly (always returns the `other` form).

### Pitfall 7: Assuming All Shared Keys Should Have `commonX` Prefix

**What goes wrong:** Developer tries to apply D-02's `commonX` convention to a per-screen sentence-level string (e.g., "This band is empty"), creating `commonBandEmpty` despite the string only appearing in one screen. ARB becomes cluttered with globally-prefixed keys that aren't actually shared.

**Why it happens:** Misunderstanding D-02 as "all keys must start with commonX" rather than "shared strings use commonX".

**How to avoid:** Re-read D-04: "Short action-word buttons (Delete, Cancel, Save, Create, Retry) use `commonX` shared keys; longer sentence-level copy (dialog confirmation bodies, empty-state descriptions) stays per-screen/per-dialog even when superficially similar."

**Decision tree:**
- Is this string fewer than 4 words (e.g., "Retry", "Cancel", "Save")? → Use `commonX` if it appears on 2+ screens
- Does this string appear on 2+ screens AND is it sentence-level copy (e.g., "No tracks have been added yet")? → Check if the meaning is context-agnostic. If yes, merge to shared key. If context-specific (band vs. setlist empty states), keep per-screen keys.
- Does this string appear on only 1 screen? → Use per-screen scoped key (e.g., `bandsScreenEmptyStateTitle`)

**Warning signs:** ARB file has 150+ keys, 80% of which start with `common`, but visual inspection shows most are single-screen use cases (grep each key across codebase—should find 2+ call sites for commonX keys).

### Pitfall 8: Locale Change Happens, But Inactive Tab Doesn't Re-render on Later Visibility (Debugging)

**What goes wrong:** (Rare) User switches language, navigates away from Home tab, returns to Home—Home still shows old language. Indicative of Localizations framework NOT working correctly (should never happen).

**Why it happens:** (Hypothetically) CadenceApp's `MaterialApp.locale` binding is broken, or Localizations delegate is misconfigured, or `ref.watch(localeControllerProvider)` isn't triggering a rebuild.

**How to avoid:** Phase 13 includes an explicit integration test for this scenario—see Validation Architecture section. If test passes, the framework is working correctly. If it fails, debug:

```dart
// In a test, verify MaterialApp.locale updates
final appBefore = tester.widget<MaterialApp>(find.byType(MaterialApp));
print('Locale before: ${appBefore.locale}'); // Should be Locale('en')

await ref.read(localeControllerProvider.notifier).setLocale(Locale('ru'));
await tester.pumpAndSettle();

final appAfter = tester.widget<MaterialApp>(find.byType(MaterialApp));
print('Locale after: ${appAfter.locale}'); // Should be Locale('ru')

// Verify Localizations of(context) returns Russian delegate
final context = tester.element(find.byType(HomeScreen));
final l10n = AppLocalizations.of(context)!;
expect(l10n.localeName, 'ru'); // Should pass
```

**Warning signs:** Integration test fails at "verify inactive tab re-renders after locale switch"; Localizations.of(context) returns correct locale, but widget tree still renders old-locale strings.

## Code Examples

Verified patterns from official sources:

### ICU Plural ARB Entry for Russian Consonant Nouns (memberCount)

```json
{
  "memberCount": "{count, plural, one{# член} few{# члена} many{# членов} other{# членов}}",
  "@memberCount": {
    "description": "Pluralized member count for band detail screens, e.g. '1 member', '2 members', '5 members'",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

**Russian translation (identical syntax, different forms):**
```json
{
  "memberCount": "{count, plural, one{# член} few{# члена} many{# членов} other{# членов}}"
}
```

**English translation:**
```json
{
  "memberCount": "{count, plural, =1{# member} other{# members}}"
}
```

**Generated Method (app_localizations.dart):**
```dart
String memberCount(int count) {
  return Intl.plural(count,
    one: '$count член',
    few: '$count члена',
    many: '$count членов',
    other: '$count членов',
    locale: localeName,
  );
}
```

**Code Usage:**
```dart
// Display member count with correct plural form
Text(AppLocalizations.of(context)!.memberCount(bandData.membersCount))
```

### WidgetTester Extension for Localization Testing

```dart
// test/test_strings.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cadence/generated/app_localizations.dart';

/// Extension on WidgetTester that provides type-safe access to localized strings.
///
/// Reads AppLocalizations off the currently pumped widget tree, enabling
/// test assertions that work in any locale (English, Russian, future langs).
extension StringsExtension on WidgetTester {
  /// Returns the AppLocalizations instance from the pumped widget tree.
  ///
  /// Assumes the first [Text] widget in the tree is mounted within the
  /// [MaterialApp]'s widget tree, which gives us access to the [Localizations]
  /// InheritedWidget.
  AppLocalizations get strings {
    final context = element(find.byType(Text).first).context;
    return AppLocalizations.of(context)!;
  }
}
```

### Test Example: Localizable Member Count Assertion

```dart
// test/features/bands/bands_screen_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'test_strings.dart'; // Import the extension

void main() {
  testWidgets('BandsScreen renders correct plural form for member count', (tester) async {
    // Pump the app with a band containing 5 members
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ... override providers with test data ...
          // Band('id': 'b1', 'name': 'Test Band', 'membersCount': 5)
        ],
        child: const CadenceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Assert using test-strings utility (works in any locale)
    expect(
      find.text(tester.strings.memberCount(5)),
      findsWidgets,
    );
  });
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hand-coded plural logic (if/else for singular/plural) | ICU MessageFormat plurals in ARB files | Flutter 2.0+ (2021) | Handles complex pluralization rules for 100+ languages automatically; reduces boilerplate |
| Hardcoded strings scattered across .dart files | ARB + gen-l10n centralized pipeline | Flutter 2.0+ | Single source of truth; integrates with professional translation services; type-safe generated code |
| Test assertions using hardcoded English literals | WidgetTester extensions reading AppLocalizations | Industry best practice (2024+) | Tests remain green across locale changes; no brittle hardcoded text |
| Manual `@riverpod` class for LocaleController pattern | Proven pattern reused from Phase 12's ThemeController | Flutter/Riverpod adoption (2022+) | Consistent state management; automatic widget rebuilds on locale change |

**Deprecated/outdated:**
- Native platform-specific localization files (NSLocalizedString on iOS, strings.xml on Android): Replaced by cross-platform ARB + Flutter gen-l10n, which is simpler and shares translations across platforms.
- Manual ChangeNotifier for locale switching: Replaced by Riverpod providers, which are simpler and already the project standard.
- English-only test assertions: Replaced by locale-agnostic test-strings utilities, which future-proof tests for multilingual apps.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | build_runner will regenerate app_localizations.dart with new plural methods when ARB files are updated | Standard Stack, Common Pitfalls | If build_runner skips gen-l10n, new plural methods won't be generated; code will fail to compile with "undefined method" errors. Mitigation: run `flutter pub run build_runner build` explicitly after ARB edits. |
| A2 | Localizations InheritedWidget automatically notifies IndexedStack-cached tabs of locale changes without explicit watch() in each tab | Architecture Patterns, Pitfalls | If tabs don't rebuild on locale switch, Phase 13's integration test will catch this. Mitigation: add explicit `ref.watch(localeControllerProvider)` to any tab that doesn't update. |
| A3 | `AppLocalizations.of(context)!` method exists and has full type signature for all plural methods (memberCount, trackCount, etc.) auto-generated by build_runner | Pattern 2, Code Examples | If build_runner's Dart codegen is incomplete, generated methods might lack plural handling. Mitigation: inspect generated app_localizations.dart after build to verify method signatures. |
| A4 | Unicode CLDR plural rules for Russian ("one"/"few"/"many") are correctly implemented by intl package without additional configuration | Pattern 2, ICU plural syntax | If intl package has bugs or outdated CLDR data, some Russian plurals might render incorrectly. Mitigation: Phase 13 automated tests verify plural form selection for counts 0, 1, 2, 5, 11, 21 (covers all Russian forms). |
| A5 | Reversing "common key deduplication" (splitting merged keys back to per-screen keys) is "costly" but feasible if needed later | User Constraints, D-01 | If developers later decide a merged commonX key was a mistake, un-merging requires finding all call sites and re-splitting. No breaking change if done carefully. Low risk. |

**If this table is empty:** All claims were verified or cited — no user confirmation needed.

[Table is non-empty — assumptions exist; most are LOW risk and have mitigation strategies.]

## Open Questions

1. **Exact set of hardcoded strings across 30+ files**
   - What we know: Phase 13 scope is "20+ screens/dialogs" plus shared widgets (offline_no_cache_view, offline_banner, root_scaffold navigation)
   - What's unclear: Exact count of strings to extract; some screens may have 5 strings (buttons only), others 20+ (labels, validators, dialog copy)
   - Recommendation: During planning, conduct a scouting pass across all in-scope files (grep for hardcoded `'...'` in Text(...), showDialog, validation messages) to enumerate strings. CONTEXT.md footnote 82 mentions "full per-file inventory available from the scouting pass" — planner will execute this during Wave 0.
   - Dependency: Planning phase will produce a complete string inventory; this research assumes the inventory is in scope and well-bounded.

2. **Exact Russian plural forms and edge cases**
   - What we know: Russian uses 3 forms (one/few/many) per Unicode CLDR; numbers ending in 1 (except 11) → one; 2-4 (except 12-14) → few; others → many
   - What's unclear: Do all nouns used in Cadence follow the same 1/2-4/5+ pattern? (e.g., "member" / "members", "track" / "tracks", "setlist" / "setlists")
   - Recommendation: Yes — Russian consonant nouns (которые, члены, треки, сетлисты) all follow standard 1/few/many forms. No irregular nouns in Cadence's domain. Safe to use the pattern uniformly. If gender-specific forms were needed (e.g., "added" adjective agreeing with noun), that's a Phase 14+ consideration (API error messages).

3. **Test-strings utility robustness under edge conditions**
   - What we know: WidgetTester extension reads first Text widget's context to access AppLocalizations
   - What's unclear: What if there are no Text widgets on screen? (e.g., testing an empty screen or dialog) Will `find.byType(Text).first` throw?
   - Recommendation: In the planning phase, add error handling to test-strings utility to provide a clear error message if context lookup fails. For now, assume all in-scope screens have at least one Text widget (Navigation bar labels, if nothing else).

## Environment Availability

All dependencies established in Phase 12; no new tool installations required.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK (with build_runner) | Code generation for app_localizations.dart | ✓ | 3.12.2+ | — |
| Dart 3.12.2+ | Compilation and runtime | ✓ | 3.12.2 | — |
| intl package (pub.dev) | ICU plural handling in generated code | ✓* | ^0.19.0+ | Already added in Phase 12 |
| shared_preferences | LocaleController persistence (Phase 12) | ✓ | ^2.2.0+ | Already added in Phase 12 |
| flutter_riverpod | LocaleController provider (Phase 12) | ✓ | ^2.6.1 | Already added in Phase 12 |
| Android/iOS emulators (for testing) | Manual E2E tests verifying locale switch on device | ✓* | Latest stable | Can test on web build if emulators unavailable |

*Already in place from Phase 12 setup.

**Missing dependencies with no fallback:** None — all required infrastructure is present.

**Missing dependencies with fallback:**
- iOS testing: Can defer to Android emulator if Xcode unavailable; Phase 13 localization tests aren't iOS-specific

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in Flutter testing) + custom test-strings WidgetTester extension |
| Config file | test/test_strings.dart (new in Phase 13) + existing test/widget_test.dart |
| Quick run command | `flutter test test/features/bands/bands_screen_test.dart -k memberCount` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| I18N-04 | All visible UI strings (labels, buttons, dialogs, validation messages) are localized in EN/RU; switching locale renders correct language | Automated widget test + manual E2E | `flutter test test/features/*/.*_test.dart` | ✓ Existing test files; modified with tester.strings assertions in Phase 13 |
| I18N-06 | Count-bearing strings (member count, track count) render grammatically correct Russian plural forms (1/2-4/5+) | Automated widget test | `flutter test -k "plural"` | ✓ New tests in Phase 13 for memberCount(1), memberCount(2), memberCount(5), trackCount(1), etc. |
| (Live locale switch across all screens) | Changing language in Settings propagates to all tabs including inactive IndexedStack children | Integration test | `flutter test test/locale_live_switch_test.dart` | ✓ Phase 13 strengthens Phase 12's test with actual rendered-string assertions instead of Localizations.localeOf() checks |

### Phase 13 Test Additions (Wave 0)

- [ ] `test/test_strings.dart` — WidgetTester extension for localization-safe assertions
- [ ] `test/features/bands/bands_screen_test.dart` — update assertions to use `tester.strings.memberCount(n)` instead of hardcoded '1 member', '2 members', etc.
- [ ] `test/locale_live_switch_test.dart` — strengthen Phase 12's test with actual rendered-string assertions in multiple tabs before/after locale switch (smoke test for IndexedStack propagation)
- [ ] Add plural test cases for edge numbers: memberCount(1), memberCount(2), memberCount(5), memberCount(11), memberCount(21) to verify Russian rules (11 is "many", not "few")

### Sampling Rate
- **Per task commit:** Run test-strings-related tests (`flutter test -k "strings"`) to verify AppLocalizations generation and accessor extension work
- **Per wave merge:** Run full test suite (`flutter test`) to ensure all touch-file assertions use new test-strings utility and no hardcoded English literals remain
- **Phase gate:** Full test suite green + manual E2E tests (switch language, verify all tabs render correct language, including background tabs) before `/gsd-verify-work`

### Wave 0 Gaps (Foundational Tests)
- [ ] `test/test_strings.dart` — WidgetTester extension implementation + unit tests for extension robustness (e.g., error handling if Text not found)
- [ ] `test/locale_live_switch_test.dart` (Phase 12 existing file) — add assertions for actual rendered text, not just Localizations.localeOf() checks. Currently tests only check that locale value changes; Phase 13 adds checks that Home/Bands/Setlists tabs actually render localized text.
- [ ] Plural form validation tests — verify Russian plural rules implemented correctly in ARB + intl: `memberCount(1)` returns "один член", `memberCount(5)` returns "пять членов", etc.

*(Some tests deferred to execution phase when exact ARB keys are finalized; Phase 13 research provides the framework and patterns)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (locale selection is not authentication-gated) |
| V3 Session Management | no | — (locale is device preference, not session data) |
| V4 Access Control | no | — (no privileged operations; language is public UI state) |
| V5 Input Validation | yes | Locale selection restricted to `supportedLocales` list ['en', 'ru'] in MaterialApp; no user-provided locale strings accepted; type-safe via Locale class |
| V6 Cryptography | no | — (strings are not encrypted; localization data is not sensitive) |

### Known Threat Patterns for Flutter + Localization

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious ARB file injection (code injection via user-controlled locale string) | Tampering | ARB files are checked into version control, not user-provided; build_runner validates JSON structure at compile time; no runtime parsing of untrusted localization data |
| Locale-based bypass of validation logic (e.g., locale='xx' bypasses input validation) | Tampering | Locale is UI-only; does not affect API requests, validation logic, auth, or server-side business logic; server treats all locales as equivalent; validation rules are enforced server-side |
| String overflow/injection via translations (e.g., very long Russian string overflows UI) | Denial of Service | Text widget clips/ellipsizes by default; no XSS or injection risk (Flutter renders native widgets, not HTML/JS); translation-specific testing during Phase 14 can catch UI layout issues |

**No new security requirements introduced in Phase 13.** Localized strings are non-sensitive user-facing data.

## Sources

### Primary (HIGH confidence)
- [Flutter Internationalization official docs](https://docs.flutter.dev/ui/internationalization) — localization framework, localizationsDelegates, supportedLocales, AppLocalizations pattern
- [pub.dev: intl package](https://pub.dev/packages/intl) — ICU message formatting, pluralization, version information, Unicode CLDR support
- [Crowdin Blog: ICU Message Format Guide](https://crowdin.com/blog/icu-guide) — Russian plural rules (one/few/many forms), ICU syntax, plural category definitions
- [Flutter ARB official examples](https://localizely.com/flutter-arb/) — ARB file structure, plural syntax, metadata blocks
- Project's existing `lib/features/settings/settings_screen.dart` + Phase 12 RESEARCH.md — proven AppLocalizations.of(context) pattern, Riverpod provider integration

### Secondary (MEDIUM confidence)
- [Medium: Flutter Localization with Riverpod and SharedPreferences](https://medium.com/@emanyaqoob/flutter-localization-with-riverpod-and-sharedpreferences-d3919fb9bb02) — Riverpod provider pattern for locale state, MaterialApp binding
- [Unicode CLDR Plural Rules 2026](https://intlpull.com/unicode-cldr-plural-rules-complete-guide-2026) — Russian and other languages' plural category mappings
- [Medium: Common Internationalization Mistakes in Flutter](https://medium.com/@pomis172/avoiding-common-localization-mistakes-in-flutter-best-practices-and-solutions-eeba39fa91ac) — pitfalls like hardcoded plurals, test assertions, missing translations
- [FlutterLocalisation Blog: Pluralization Complete Guide](https://flutterlocalisation.com/blog/flutter-pluralization-complete-guide) — practical plural examples, testing strategies

### Tertiary (LOW confidence, marked [ASSUMED])
- Training data on WidgetTester extensions and test-strings utility patterns — not yet verified in this codebase; will be validated during Phase 13 execution

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — All packages verified on pub.dev and Flutter SDK; intl/flutter_localizations are official Dart/Flutter team packages with 10+ years of stable API
- **ICU plural syntax & Russian rules:** HIGH — Unicode CLDR plural rules are international standard; intl package implements them; multiple sources cross-confirm Russian 1/few/many forms
- **Architecture (AppLocalizations, Riverpod LocaleController):** HIGH — Phase 12 established and proved these patterns; Phase 13 reuses with no architectural changes
- **Test-strings utility design:** MEDIUM — Pattern follows WidgetTester extension best practices; no production precedent in current codebase yet; will be validated during Phase 13 planning
- **Pitfalls & common mistakes:** HIGH — Documented across multiple professional Flutter localization guides; built_runner regeneration, ARB key consistency, hardcoded plurals, IndexedStack behavior all cross-confirmed
- **Environment availability:** HIGH — Phase 12 confirmed all tooling is in place; no new dependencies needed

**Research date:** 2026-08-25
**Valid until:** 2026-09-25 (Flutter/Dart ecosystem stable; ARB/gen-l10n unchanged for 3+ years; intl package LTS; Russian plural rules are canonical per Unicode standard)
