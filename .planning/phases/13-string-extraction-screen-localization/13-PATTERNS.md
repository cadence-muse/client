# Phase 13: String Extraction & Screen Localization - Pattern Map

**Mapped:** 2026-08-25
**Files analyzed:** 35+ (screens, dialogs, widgets, tests, config)
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/l10n/app_en.arb` | config | static | `lib/l10n/app_en.arb` (Phase 12) | exact |
| `lib/l10n/app_ru.arb` | config | static | `lib/l10n/app_ru.arb` (Phase 12) | exact |
| `lib/features/auth/login_screen.dart` | screen/component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/features/bands/bands_screen.dart` | screen/component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/features/bands/band_detail_screen.dart` | screen/component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/features/home/home_screen.dart` | screen/component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/features/songs/tracks_screen.dart` | screen/component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/features/profile/profile_screen.dart` | screen/component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/features/setlists/*.dart` (6 files) | screen/component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/navigation/root_scaffold.dart` | component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/widgets/offline_no_cache_view.dart` | component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/widgets/offline_banner.dart` | component | request-response | `lib/features/settings/settings_screen.dart` | exact |
| `lib/features/setlists/setlist_formatting.dart` | utility | transform | `lib/features/setlists/setlist_formatting.dart` (existing) | same-file |
| `lib/generated/app_localizations.dart` | generated | static | `lib/generated/app_localizations.dart` (Phase 12) | auto-generated |
| `test/test_strings.dart` | test-utility | request-response | (new pattern, no prior analog) | N/A |
| `test/locale_live_switch_test.dart` | test | request-response | `test/locale_live_switch_test.dart` (Phase 12) | role-match |
| `test/features/*/.*_test.dart` (29 files) | test | request-response | `test/features/bands/bands_screen_test.dart` | role-match |

## Pattern Assignments

### `lib/l10n/app_en.arb` (config, static)

**Analog:** `lib/l10n/app_en.arb` (Phase 12 existing)

**Current content** (Phase 12, lines 1-11):
```json
{
  "@@locale": "en",
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

**Phase 13 additions will follow same structure:**
- Flat namespace with scoped-prefix keys (e.g., `appBarBandsTitle`, `commonRetry`, `navHome`)
- Simple string entries for single-value strings
- ICU plural entries with `@key` metadata blocks for count-bearing strings
- Key names identical across `app_en.arb` and `app_ru.arb`

**Example ICU plural pattern (memberCount)** to add:
```json
{
  "memberCount": "{count, plural, =0{No members} =1{1 member} other{{count} members}}",
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

---

### `lib/l10n/app_ru.arb` (config, static)

**Analog:** `lib/l10n/app_ru.arb` (Phase 12 existing)

**Current content** (Phase 12, lines 1-11):
```json
{
  "@@locale": "ru",
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

**Phase 13 additions will follow same structure:**
- Identical key names to `app_en.arb`
- Russian translations in values
- ICU plural entries with Russian `one`/`few`/`many` forms per Unicode CLDR

**Example ICU plural pattern (memberCount) for Russian**:
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

---

### `lib/features/settings/settings_screen.dart` (screen, request-response)

**Analog:** `lib/features/settings/settings_screen.dart` (Phase 12 proven pattern)

**Imports pattern** (lines 1-6):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';
```

**AppLocalizations access pattern** (lines 18-20):
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final themeMode = ref.watch(themeControllerProvider);
  final locale = ref.watch(localeControllerProvider);

  return locale.when(
    data: (currentLocale) => Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appBarSettingsTitle),
      ),
```

**Core pattern for Text widgets** (lines 29-31):
```dart
Text(
  AppLocalizations.of(context)!.sectionThemeTitle,
  style: const TextStyle(fontWeight: FontWeight.w600),
),
```

**Key behaviors:**
- All screens use `AppLocalizations.of(context)!.keyName` for localized strings
- No explicit locale watching in individual screens (Localizations InheritedWidget handles propagation)
- Works with ConsumerWidget + WidgetRef (Riverpod pattern)
- `!` (bang operator) is safe because MaterialApp's Localizations InheritedWidget always provides a value

---

### `lib/features/auth/login_screen.dart` (screen, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Current hardcoded strings to replace** (lines 120, 125, 135, 139, 160, 167-168):
```dart
// BEFORE (current code):
decoration: const InputDecoration(
  labelText: 'Username',
  border: OutlineInputBorder(),
),
validator: (value) =>
    (value == null || value.trim().isEmpty)
    ? 'Enter a username'
    : null,
```

**Import addition needed** (add to existing imports):
```dart
import '../../generated/app_localizations.dart';
```

**Pattern after Phase 13 (all hardcoded strings replaced):**
```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final isSignUp = _mode == _AuthMode.signUp;
  
  return Scaffold(
    body: SafeArea(
      child: Form(
        child: Column(
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: l10n.loginUsernameLabel,  // NEW ARB key
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                  ? l10n.loginUsernameValidator  // NEW ARB key
                  : null,
            ),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(isSignUp ? l10n.commonSignUp : l10n.commonLogIn),
            ),
          ],
        ),
      ),
    ),
  );
}
```

**Error messages pattern** (lines 53, 70):
```dart
// BEFORE:
throw ApiException(
  statusCode: e.statusCode,
  code: e.code,
  message: 'This username is already taken',
);

// AFTER (Phase 14 — deferred, not Phase 13):
// Phase 13 scope: only UI-visible hardcoded strings
// Phase 14 scope: API error message localization
```

---

### `lib/features/bands/bands_screen.dart` (screen, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Current plural helper to DELETE** (line 15):
```dart
// DELETE THIS:
String _membersLabel(int count) => '$count member${count == 1 ? '' : 's'}';
```

**Import addition needed**:
```dart
import '../../generated/app_localizations.dart';
```

**Current hardcoded AppBar string** (line 36):
```dart
// BEFORE:
appBar: AppBar(
  title: const Text('Bands'),
```

**Pattern after Phase 13**:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  // ... provider watches ...
  
  return Scaffold(
    appBar: AppBar(
      title: Text(l10n.appBarBandsTitle),  // NEW ARB key
      // ... rest of appBar config ...
    ),
    body: bandsAsync.when(
      data: (bands) => _buildContent(context, bands, profileAsync),
      // ... error/loading states use l10n too ...
    ),
  );
}

Widget _buildContent(
  BuildContext context,
  List<Band> bands,
  AsyncValue<Profile> profileAsync,
) {
  final l10n = AppLocalizations.of(context)!;
  
  // Inside ListTile.trailing, replace:
  // _membersLabel(band.membersCount) 
  // with:
  // l10n.memberCount(band.membersCount)
}
```

**Key change:**
- Delete `_membersLabel()` helper (line 15)
- Replace all `_membersLabel(count)` calls with `l10n.memberCount(count)` where `memberCount(int)` is generated from ARB plural entry

---

### `lib/features/bands/band_detail_screen.dart` (screen, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Current combined "Owner • N members" string** (lines 127-128):
```dart
// BEFORE (combines role + count):
trailing: Text('${band.ownerId == profileData.id ? 'Owner' : 'Member'} • ${_membersLabel(band.membersCount)}'),
```

**Pattern after Phase 13**:
```dart
// AFTER (splits into two parts):
trailing: Text(
  '${l10n.bandRoleLabel(band.ownerId == profileData.id)} • ${l10n.memberCount(band.membersCount)}',
),

// Where ARB defines:
// "bandRoleLabel": "{isOwner, select, true{Owner} other{Member}}"
// Or simpler (using state logic in Dart):
trailing: Text(
  '${band.ownerId == profileData.id ? l10n.bandRoleOwner : l10n.bandRoleMember} • ${l10n.memberCount(band.membersCount)}',
),
```

**ARB keys for D-10**:
```json
{
  "bandRoleOwner": "Owner",
  "bandRoleMember": "Member",
  "memberCount": "{count, plural, ...}"
}
```

---

### `lib/features/home/home_screen.dart` (screen, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Same pattern** as settings_screen:
1. Import `app_localizations.dart`
2. Call `AppLocalizations.of(context)!.keyName` for all hardcoded strings
3. Works in ConsumerWidget without explicit locale watching

---

### `lib/features/songs/tracks_screen.dart` (screen, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Same pattern** as settings_screen. Replace all hardcoded strings with `l10n.keyName` calls.

---

### `lib/features/profile/profile_screen.dart` (screen, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Same pattern** as settings_screen.

---

### `lib/features/setlists/*.dart` (6 files: create_setlist_screen.dart, setlist_detail_screen.dart, add_setlist_tracks_dialog.dart, etc.)

**Analog:** `lib/features/settings/settings_screen.dart`

**Same pattern** as settings_screen for all UI strings.

**Special handling for trackCount() plural**:
- `lib/features/setlists/setlist_formatting.dart:5` has `pluralizeTracks(int)` helper
- Replace all calls to `pluralizeTracks(count)` with `l10n.trackCount(count)`
- Delete the helper function after replacement

**Max-track-ceiling messages** (D-11, D-12):
```dart
// BEFORE (duplicated in 3 files):
static const int _maxSetlistTracks = 100;
// Used in error messages like: "Maximum 100 tracks per setlist"

// AFTER (consolidated in setlist_formatting.dart):
const int maxSetlistTracks = 100;

// ARB:
{
  "maxTracksExceeded": "Maximum {count} tracks per setlist",
  "@maxTracksExceeded": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}

// Usage:
Text(l10n.maxTracksExceeded(maxSetlistTracks))
```

---

### `lib/navigation/root_scaffold.dart` (component, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Current hardcoded navigation labels** (lines 42-68):
```dart
destinations: const [
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.groups_outlined),
    selectedIcon: Icon(Icons.groups),
    label: 'Bands',
  ),
  // ... Tracks, Setlists, Profile ...
],
```

**Import addition needed**:
```dart
import '../generated/app_localizations.dart';
```

**Pattern after Phase 13** (make RootScaffold a ConsumerWidget):
```dart
class RootScaffold extends ConsumerWidget {
  const RootScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    final l10n = AppLocalizations.of(context)!;
    
    final screens = [
      const HomeScreen(),
      const BandsScreen(),
      const TracksScreen(),
      const SetlistsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            ref.read(selectedTabIndexProvider.notifier).setIndex(index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,  // NEW ARB key
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.navBands,  // NEW ARB key
          ),
          NavigationDestination(
            icon: const Icon(Icons.music_note_outlined),
            selectedIcon: const Icon(Icons.music_note),
            label: l10n.navTracks,  // NEW ARB key
          ),
          NavigationDestination(
            icon: const Icon(Icons.playlist_play_outlined),
            selectedIcon: const Icon(Icons.playlist_play),
            label: l10n.navSetlists,  // NEW ARB key
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.navProfile,  // NEW ARB key
          ),
        ],
      ),
    );
  }
}
```

**ARB entries** (app_en.arb):
```json
{
  "navHome": "Home",
  "navBands": "Bands",
  "navTracks": "Tracks",
  "navSetlists": "Setlists",
  "navProfile": "Profile"
}
```

---

### `lib/widgets/offline_no_cache_view.dart` (component, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Current hardcoded strings** (lines 32, 38):
```dart
Text(
  'No cached data',
  textAlign: TextAlign.center,
  style: Theme.of(context).textTheme.headlineSmall,
),
const SizedBox(height: 8),
Text(
  'Connect to the internet to load this',
  textAlign: TextAlign.center,
  style: Theme.of(context).textTheme.bodyMedium,
),
```

**Import addition needed**:
```dart
import '../generated/app_localizations.dart';
```

**Pattern after Phase 13** (make it a ConsumerWidget):
```dart
class OfflineNoCacheView extends ConsumerWidget {
  const OfflineNoCacheView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.offlineNoCacheTitle,  // NEW ARB key
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.offlineNoCacheDescription,  // NEW ARB key
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

**ARB entries**:
```json
{
  "offlineNoCacheTitle": "No cached data",
  "offlineNoCacheDescription": "Connect to the internet to load this"
}
```

---

### `lib/widgets/offline_banner.dart` (component, request-response)

**Analog:** `lib/features/settings/settings_screen.dart`

**Current hardcoded string** (line 29):
```dart
child: Text(
  'Showing cached data — may be out of date',
  style: TextStyle(color: colorScheme.onErrorContainer),
),
```

**Import addition needed**:
```dart
import '../generated/app_localizations.dart';
```

**Pattern after Phase 13** (already a ConsumerWidget):
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final isOnline = ref.watch(isOnlineProvider);
  if (isOnline) {
    return const SizedBox.shrink();
  }

  final l10n = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;
  return Container(
    color: colorScheme.errorContainer,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Icon(Icons.cloud_off, color: colorScheme.onErrorContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.offlineBannerMessage,  // NEW ARB key
            style: TextStyle(color: colorScheme.onErrorContainer),
          ),
        ),
      ],
    ),
  );
}
```

**ARB entry**:
```json
{
  "offlineBannerMessage": "Showing cached data — may be out of date"
}
```

---

### `lib/features/setlists/setlist_formatting.dart` (utility, transform)

**Analog:** `lib/features/setlists/setlist_formatting.dart` (same file, existing code)

**Current plural helper to REPLACE** (line 5):
```dart
// DELETE THIS:
String pluralizeTracks(int count) => count == 1 ? '1 track' : '$count tracks';
```

**Current max-tracks constant** (to consolidate):
- Currently duplicated in 3 files: `add_setlist_tracks_dialog.dart:53`, `create_setlist_screen.dart:29`, `setlist_detail_screen.dart:38`
- Each has: `static const int _maxSetlistTracks = 100;`

**Pattern after Phase 13**:
```dart
import 'package:cadence/features/tracks/track_formatting.dart';

// Consolidate the duplicated constant here:
const int maxSetlistTracks = 100;

// DELETE: String pluralizeTracks(int count) => ...
// (this will now be handled by AppLocalizations.trackCount(int) in UI)

/// Composes a setlist list row's trailing text, e.g. `'8 tracks, 42:35'`.
/// Reused unmodified by Plan 05's global cross-band Setlists tab.
/// 
/// Note: pluralizeTracks() replaced by AppLocalizations.trackCount()
/// in UI code; this function remains for formatting non-UI data.
String tracksAndDuration(int tracksCount, int durationSeconds) =>
    '${tracksCount == 1 ? 'track' : 'tracks'}, ${durationSeconds.asMinutesSeconds}';

// ... formatEventDate unchanged ...
```

**Key change:**
- Consolidate `maxSetlistTracks` constant from 3 files into 1 central location (here)
- The 3 files (`add_setlist_tracks_dialog.dart`, `create_setlist_screen.dart`, `setlist_detail_screen.dart`) now import it: `import 'setlist_formatting.dart' show maxSetlistTracks;`
- `pluralizeTracks()` deleted; all UI calls replace it with `l10n.trackCount(count)`

---

### `lib/generated/app_localizations.dart` (generated, static)

**Analog:** `lib/generated/app_localizations.dart` (Phase 12 existing, auto-generated)

**This file is AUTO-GENERATED by build_runner** from ARB files. No manual edits.

**After Phase 13 additions, this file will contain:**
- All Phase 12 keys (8 strings)
- All Phase 13 keys (~100+ strings and plural methods)
- Generated methods like: `String memberCount(int count)`, `String trackCount(int count)`, etc.

**Example generated plural method** (auto-generated from ARB):
```dart
String memberCount(int count) {
  return Intl.plural(count,
    one: '$count member',
    other: '$count members',
    locale: localeName,
  );
}
```

**To regenerate after ARB changes:**
```bash
flutter pub run build_runner build
# Or watch mode:
flutter pub run build_runner watch
```

---

### `test/test_strings.dart` (test-utility, request-response)

**NEW FILE in Phase 13** — no prior analog, but follows WidgetTester extension best practices

**Purpose:** Provide type-safe, locale-agnostic access to localized strings in widget tests

**Implementation pattern**:
```dart
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
  ///
  /// Assumes the first [Text] widget in the tree is mounted within the
  /// [MaterialApp]'s widget tree, which gives us access to the [Localizations]
  /// InheritedWidget.
  ///
  /// Throws [StateError] if no Text widget found (edge case: empty screen).
  AppLocalizations get strings {
    final context = element(find.byType(Text).first).context;
    return AppLocalizations.of(context)!;
  }
}
```

**Key behaviors:**
- Reads `AppLocalizations` directly off currently-pumped widget tree
- Single source of truth: the live ARB file, zero drift risk
- Works in any locale (English, Russian, future languages)
- Provides both simple strings and plural methods under one API surface
- Future-proof: if a string's ARB value changes, tests automatically use new value

---

### `test/locale_live_switch_test.dart` (test, request-response)

**Analog:** `test/locale_live_switch_test.dart` (Phase 12 existing)

**Current pattern** (lines 144-151):
```dart
expect(find.text('Settings'), findsOneWidget);
expect(find.text('Language'), findsOneWidget);

await tester.tap(find.text('Русский'));
await tester.pumpAndSettle();

expect(find.text('Настройки'), findsOneWidget);
expect(find.text('Язык'), findsOneWidget);
```

**Phase 13 enhancement** (strengthen with rendered-string assertions on HomeScreen):
```dart
// Add to test/locale_live_switch_test.dart:

// Before locale switch, verify Home tab renders in English
await tester.pumpWidget(buildApp());
await tester.pumpAndSettle();
expect(
  find.text(tester.strings.appBarHomeTitle),  // English version
  findsOneWidget,
);

// Navigate to Settings, switch to Russian
await goToSettings(tester);
await tester.tap(find.text('Русский'));
await tester.pumpAndSettle();

// Pop back to Home tab and verify it re-renders in Russian
Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
await tester.pumpAndSettle();

await tester.tap(
  find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(tester.strings.navHome),  // Uses localized nav label
  ),
);
await tester.pumpAndSettle();

// Verify Home tab now shows Russian text (proves IndexedStack propagates locale)
expect(
  find.text(tester.strings.appBarHomeTitle),  // Russian version
  findsOneWidget,
);
```

---

### `test/features/bands/bands_screen_test.dart` (test, request-response)

**Analog:** `test/features/bands/bands_screen_test.dart` (existing Phase 12+)

**Current hardcoded text assertions** to migrate (representative examples):

```dart
// Lines 102, 105-108 — empty state copy:
// BEFORE:
expect(find.text('No bands yet'), findsOneWidget);
expect(
  find.text('Create a band or ask a bandmate for an invite code to join one.'),
  findsOneWidget,
);

// AFTER:
expect(find.text(tester.strings.bandsEmptyTitle), findsOneWidget);
expect(
  find.text(tester.strings.bandsEmptyDescription),
  findsOneWidget,
);

// Lines 127-132 — error state copy:
// BEFORE:
expect(find.text("Couldn't load bands"), findsOneWidget);
expect(
  find.text('Please check your connection and try again.'),
  findsOneWidget,
);
expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

// AFTER:
expect(find.text(tester.strings.bandsErrorTitle), findsOneWidget);
expect(
  find.text(tester.strings.commonConnectionError),
  findsOneWidget,
);
expect(find.widgetWithText(ElevatedButton, tester.strings.commonRetry), findsOneWidget);

// Lines 467, 498, 524, 549 — member count assertions:
// BEFORE:
expect(find.text('1 member • Owner'), findsOneWidget);
expect(find.text('1 member • Member'), findsOneWidget);
expect(find.text('1 member'), findsOneWidget);
expect(find.text('5 members'), findsOneWidget);

// AFTER:
expect(
  find.text('${tester.strings.bandRoleOwner} • ${tester.strings.memberCount(1)}'),
  findsOneWidget,
);
expect(
  find.text('${tester.strings.bandRoleMember} • ${tester.strings.memberCount(1)}'),
  findsOneWidget,
);
expect(find.text(tester.strings.memberCount(1)), findsOneWidget);
expect(find.text(tester.strings.memberCount(5)), findsOneWidget);
```

**Migration strategy** (per D-07):
- Touched-file only: as each screen is localized in Phase 13, its test file gets updated
- Test data (band names, usernames like `'The Testers'`) stays hardcoded — they are test fixtures, not UI copy
- App-copy assertions (labels, buttons, messages) all migrate to `tester.strings.*`

---

### `test/features/*/.*_test.dart` (all other test files, 28+ files)

**Analog:** `test/features/bands/bands_screen_test.dart` (same pattern)

**Migration pattern** (identical to bands_screen_test.dart above):
1. Import `test/test_strings.dart`
2. Replace all `find.text('hardcoded English text')` calls for app copy with `tester.strings.keyName`
3. Keep test data and fixtures (band names, track titles, usernames) hardcoded
4. Executed per-screen as each screen is localized in Phase 13 execution

---

## Shared Patterns

### Pattern 1: Simple String Extraction in ARB Files

**Source:** `lib/l10n/app_en.arb` and `app_ru.arb` (Phase 12 precedent)

**Apply to:** All simple, non-plural strings (buttons, labels, titles, messages)

**ARB template** (app_en.arb):
```json
{
  "@@locale": "en",
  "keyName": "English text",
  "anotherKey": "Another piece of copy"
}
```

**Russian equivalent** (app_ru.arb):
```json
{
  "@@locale": "ru",
  "keyName": "Русский текст",
  "anotherKey": "Другой текст"
}
```

**Key names must be identical** across both files. Planner will validate during execution.

---

### Pattern 2: ICU Plural Syntax for Russian (New in Phase 13)

**Source:** RESEARCH.md §Code Examples (verified against Unicode CLDR)

**Apply to:** All count-bearing strings (member count, track count, max-track limits)

**ARB template** (app_en.arb):
```json
{
  "memberCount": "{count, plural, =0{No members} =1{1 member} other{{count} members}}",
  "@memberCount": {
    "description": "Pluralized member count for band displays",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

**Russian equivalent** (app_ru.arb) — uses `one`/`few`/`many` forms per Unicode CLDR:
```json
{
  "memberCount": "{count, plural, one{# член} few{# члена} many{# членов} other{# членов}}",
  "@memberCount": {
    "description": "Pluralized member count for band displays",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

**Generated method** (auto-generated in app_localizations.dart):
```dart
String memberCount(int count) {
  return Intl.plural(count,
    one: '$count member',
    other: '$count members',
    locale: localeName,
  );
}
```

**Code usage:**
```dart
Text(l10n.memberCount(5))  // English: "5 members" | Russian: "5 членов"
```

---

### Pattern 3: Accessing AppLocalizations in Dart Code

**Source:** `lib/features/settings/settings_screen.dart` (Phase 12 proven)

**Apply to:** All screens, dialogs, widgets displaying localized strings

**In Widget build() method:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;
  
  return Scaffold(
    appBar: AppBar(
      title: Text(l10n.appBarTitleKey),  // Use l10n.keyName
    ),
    body: Column(
      children: [
        Text(l10n.labelKey),
        ElevatedButton(
          onPressed: () {},
          child: Text(l10n.commonRetry),  // Shared key example
        ),
      ],
    ),
  );
}
```

**Key points:**
- `AppLocalizations.of(context)!` retrieves the locale-specific instance
- `!` is safe: MaterialApp's Localizations InheritedWidget always provides a value
- No explicit locale watching in individual screens
- Works in both ConsumerWidget (Riverpod) and StatelessWidget

---

### Pattern 4: Test-Strings Extension for Widget Tests

**Source:** New in Phase 13, follows WidgetTester extension conventions

**Apply to:** All widget tests verifying UI text (app-copy only, not test data)

**In test file:**
```dart
import 'test/test_strings.dart';  // Import the extension

void main() {
  testWidgets('screen displays localized strings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...],
        child: const CadenceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Use tester.strings instead of hardcoded text
    expect(find.text(tester.strings.commonRetry), findsOneWidget);
    expect(find.text(tester.strings.memberCount(5)), findsOneWidget);
    
    // Test data (fixtures) stay hardcoded:
    expect(find.text('The Testers'), findsOneWidget);  // Band name is test data
  });
}
```

**Works in any locale:**
- When app is English: `tester.strings.commonRetry` → "Retry"
- When app is Russian: `tester.strings.commonRetry` → "Повторить"
- Test automatically passes in both locales

---

### Pattern 5: Shared Key Naming Convention (D-01–D-04)

**Source:** CONTEXT.md D-02 (new convention for Phase 13)

**Apply to:** Deciding whether a string should be shared (commonX) or per-screen

**Decision tree:**
```
Is this string fewer than 4 words?
├─ YES: Check if it appears on 2+ screens (grep codebase)
│  ├─ YES: Use shared key → "commonRetry", "commonCancel", "commonDelete"
│  └─ NO: Use per-screen key → "createBandSubmitButton"
└─ NO: Is it sentence-level copy?
   ├─ YES & appears on 2+ screens: Check if context-agnostic
   │  ├─ YES: Use shared key → "commonConnectionError", "commonRequiresConnection"
   │  └─ NO: Use per-screen key → "bandsEmptyStateDescription", "setlistsEmptyStateDescription"
   └─ NO: Always use per-screen key
```

**Shared key examples** (D-02):
- `commonRetry` — "Retry" button (appears on error states across 6+ screens)
- `commonCancel` — "Cancel" button (dialogs)
- `commonDelete` — "Delete" button (destructive actions)
- `commonConnectionError` — "Please check your connection and try again." (offline/error states)
- `commonRequiresConnection` — "Requires connection" (disabled FAB/button tooltips)

**Per-screen key examples** (D-04):
- `appBarBandsTitle` — "Bands" (only on BandsScreen AppBar)
- `bandsEmptyTitle` — "No bands yet" (only on BandsScreen empty state)
- `setlistsEmptyTitle` — "No setlists yet" (only on SetlistsScreen empty state)
- `loginUsernameLabel` — "Username" (only on LoginScreen)

---

## No Analog Found

Files with no direct precedent (new patterns introduced in Phase 13):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `test/test_strings.dart` | test-utility | request-response | WidgetTester extension is a new pattern for this codebase; while extensions on WidgetTester follow Flutter conventions, this specific "read AppLocalizations off tree" pattern has no prior implementation here. RESEARCH.md provides the design template; planning phase will implement per that design. |

---

## Metadata

**Pattern search scope:**
- `lib/l10n/` — ARB configuration files
- `lib/generated/` — Generated localization code (read-only)
- `lib/features/` — Screen components (auth, bands, home, profile, setlists, songs)
- `lib/navigation/` — Navigation and root-level components
- `lib/widgets/` — Shared UI widgets
- `test/` — Test utilities and widget tests

**Files scanned:** 35+ (all screens, dialogs, shared widgets, test files)

**Analogs found:**
1. ✓ `lib/l10n/app_en.arb` (Phase 12, exact match for config pattern)
2. ✓ `lib/l10n/app_ru.arb` (Phase 12, exact match for config pattern)
3. ✓ `lib/features/settings/settings_screen.dart` (Phase 12, proven AppLocalizations access pattern)
4. ✓ `lib/generated/app_localizations.dart` (Phase 12, generated scaffold, auto-updated by build_runner)

**Shared patterns identified:**
- ARB file structure (flat namespace, scoped prefixes, identical key names across locales)
- AppLocalizations access in screens (`AppLocalizations.of(context)!.keyName`)
- ICU plural syntax in ARB files (Russian 1/few/many forms)
- Generated plural methods in app_localizations.dart
- WidgetTester extension for test-strings utility

**Reversibility notes:**
- D-01 (shared key deduplication) is costly to reverse — requires finding all call sites and re-splitting
- All other changes are localized edits (ARB additions, string replacements, constant consolidation) with no breaking changes

**Key blockers identified:** None. All required infrastructure (ARB pipeline, gen-l10n, Localizations framework, Riverpod providers) was established in Phase 12 and is production-ready.

---

*Phase: 13 - String Extraction & Screen Localization*
*Pattern map created: 2026-08-25*
