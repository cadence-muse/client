# Phase 16: Track Terminology Rename - Pattern Map

**Mapped:** 2026-08-27
**Files analyzed:** 12 modified + 1 directory move
**Analogs found:** 12 / 12 (100% coverage)

## File Classification

| File | Role | Data Flow | Closest Analog | Match Quality |
|------|------|-----------|----------------|---------------|
| `lib/features/songs/tracks_screen.dart` (moved) | screen | request-response | `lib/features/home/home_screen.dart` | exact |
| `lib/navigation/root_scaffold.dart` | navigation | request-response | `lib/navigation/root_scaffold.dart` (self) | self |
| `lib/features/home/home_screen.dart` | screen | request-response | `lib/features/home/home_screen.dart` (self) | self |
| `lib/features/home/band_picker_sheet.dart` | component | request-response | `lib/features/home/band_picker_sheet.dart` (self) | self |
| `lib/l10n/app_en.arb` | config-localization | static | `lib/l10n/app_en.arb` (self) | self |
| `lib/l10n/app_ru.arb` | config-localization | static | `lib/l10n/app_ru.arb` (self) | self |
| `lib/generated/app_localizations.dart` | generated | static | `lib/generated/app_localizations.dart` (self, regenerated) | self |
| `test/features/tracks/tracks_screen_test.dart` | test | N/A | `test/features/home/home_screen_test.dart` | role-match |
| `test/features/home/home_screen_test.dart` | test | N/A | `test/features/home/home_screen_test.dart` (self) | self |
| `test/regression/offline_trust_regression_test.dart` | test | N/A | `test/regression/offline_trust_regression_test.dart` (self) | self |
| Test fixture data files | test | N/A | `test/features/tracks/track_list_screen_test.dart` | role-match |

## Pattern Assignments

### `lib/features/songs/tracks_screen.dart` → `lib/features/tracks/tracks_screen.dart` (Directory Move)

**Analog:** `lib/features/home/home_screen.dart`

**Pattern:** Flutter ConsumerWidget screen component

**Imports pattern** (lines 1-11):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/bands_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/tracks_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import '../tracks/track_detail_screen.dart';
import '../tracks/track_formatting.dart';
```

**Core screen pattern** (lines 17-59):
```dart
class TracksScreen extends ConsumerWidget {
  const TracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    // Listener for tab re-selection to invalidate provider
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == 2) ref.invalidate(userTracksListDataProvider);
    });

    // Main build with Scaffold and async data handling
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navTracks),
      ),
      body: _buildBody(), // Delegated to private method
    );
  }
  
  // Private helper methods for building UI sections
  Widget _buildFilterDropdown(...) { ... }
  Widget _buildTracksBody(...) { ... }
  Widget _buildContent(...) { ... }
  Widget _buildEmptyState(...) { ... }
  Widget _buildError(...) { ... }
}
```

**Error handling pattern** (lines 106-118):
```dart
Widget _buildTracksBody(...) {
  return tracksAsync.when(
    data: (tracks) => _buildContent(context, ref, tracks),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, stackTrace) {
      if (error is OfflineNoCacheException) {
        return const OfflineNoCacheView();
      }
      return _buildError(
        context,
        () => ref.invalidate(userTracksListDataProvider),
      );
    },
  );
}
```

**File-to-copy note:** 
- The file content itself is already correctly named (`TracksScreen` class at line 17)
- Only the parent directory changes: `lib/features/songs/` → `lib/features/tracks/`
- Class name, imports within the file, and all logic remain unchanged
- Use `git mv lib/features/songs/tracks_screen.dart lib/features/tracks/tracks_screen.dart` to preserve history, or delete + recreate if git mv is unavailable

---

### `lib/navigation/root_scaffold.dart` (Import Update)

**Analog:** `lib/navigation/root_scaffold.dart` (self)

**Current import** (line 8):
```dart
import '../features/songs/tracks_screen.dart';
```

**Updated import:**
```dart
import '../features/tracks/tracks_screen.dart';
```

**Context:** The import is used at line 26 in the `screens` list:
```dart
final screens = [
  const HomeScreen(),
  const BandsScreen(),
  const TracksScreen(),  // Referenced after import
  const SetlistsScreen(),
  const ProfileScreen(),
];
```

---

### `lib/features/home/home_screen.dart` (Comment and ARB Key Update)

**Analog:** `lib/features/home/home_screen.dart` (self)

**Comment updates:**

Location: Line 66 (within `_buildContent` method's doc comment)
```dart
// Phase 9 (D-01/D-02/D-03/D-09/D-10): one unified layout for both the
// zero-bands and populated states — a welcome card, a "Quick Actions"
// header, and a 3-button row where "Add Song"/"Add Setlist" are disabled
// until bandsCount > 0. Replaces the old bandsCount==0-only empty-state
// block and the old populated-state band-count display text entirely.
```

Change to:
```dart
// Phase 9 (D-01/D-02/D-03/D-09/D-10): one unified layout for both the
// zero-bands and populated states — a welcome card, a "Quick Actions"
// header, and a 3-button row where "Add Track"/"Add Setlist" are disabled
// until bandsCount > 0. Replaces the old bandsCount==0-only empty-state
// block and the old populated-state band-count display text entirely.
```

Location: Line 128 (within the "Quick Actions" section comment)
```dart
// D-10: all 3 buttons always render; only enabled/disabled
// state of Add Song/Add Setlist changes with bandsCount.
```

Change to:
```dart
// D-10: all 3 buttons always render; only enabled/disabled
// state of Add Track/Add Setlist changes with bandsCount.
```

**ARB call update:**

Location: Line 145 (within `ElevatedButton.icon` for the track button)
```dart
label: Text(l10n.homeAddSongButton),
```

Change to:
```dart
label: Text(l10n.homeAddTrackButton),
```

---

### `lib/features/home/band_picker_sheet.dart` (Comment Update)

**Analog:** `lib/features/home/band_picker_sheet.dart` (self)

**Comment update:**

Location: Line 9 (in the doc comment)
```dart
/// Shows the shared band-picker bottom sheet for the "Add Song" and
/// "Add Setlist" Homepage quick actions (HOME-02, D-05/D-06/D-07/D-08).
```

Change to:
```dart
/// Shows the shared band-picker bottom sheet for the "Add Track" and
/// "Add Setlist" Homepage quick actions (HOME-02, D-05/D-06/D-07/D-08).
```

---

### `lib/l10n/app_en.arb` (ARB Key Rename)

**Analog:** `lib/l10n/app_en.arb` (self)

**Current entry** (line 194):
```json
  "homeAddSongButton": "Add Song",
```

**Updated entry:**
```json
  "homeAddTrackButton": "Add Track",
```

**Context:** This key is part of the "Quick Actions" section alongside sibling keys:
```json
  "homeQuickActionsHeader": "Quick Actions",
  "homeAddBandButton": "Add Band",
  "homeAddTrackButton": "Add Track",  // Changed from homeAddSongButton
  "homeAddSetlistButton": "Add Setlist",
```

**Pattern note:** ARB key naming follows the sibling pattern: `homeAdd{Entity}Button` where entity is `Band`, `Track`, or `Setlist`. The key `homeAddSongButton` broke this pattern; the rename aligns it with the established convention.

---

### `lib/l10n/app_ru.arb` (ARB Key Rename with Translation)

**Analog:** `lib/l10n/app_ru.arb` (self)

**Current entry** (line 194):
```json
  "homeAddSongButton": "Добавить песню",
```

**Updated entry:**
```json
  "homeAddTrackButton": "Добавить трек",
```

**Context:** Russian localization follows the same sibling pattern as English:
```json
  "homeQuickActionsHeader": "Быстрые действия",
  "homeAddBandButton": "Добавить группу",
  "homeAddTrackButton": "Добавить трек",  // Changed from homeAddSongButton: "Добавить песню"
  "homeAddSetlistButton": "Добавить сетлист",
```

**Translation note:** "трек" (track) is the established Russian terminology throughout the app (used in `trackCount`, `navTracks`, `commonAddTracks`, `commonEnterTrackTitle` in existing ARB). The old "песню" (song) breaks this consistency; "трек" aligns with the app's Russian terminology convention.

---

### `lib/generated/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_ru.dart` (Generated - Auto-Updated)

**Analog:** `lib/generated/app_localizations*.dart` (self, auto-generated)

**Pattern:** These files are generated by `flutter gen-l10n` from ARB source files

**Regeneration trigger:** After ARB files are edited:
```bash
flutter gen-l10n
```

**What changes:**
- Old getter removed: `String get homeAddSongButton => ...;`
- New getter added: `String get homeAddTrackButton => ...;`
- Translation tables in `app_localizations_en.dart` and `app_localizations_ru.dart` updated to include the new key

**Files affected:**
- `lib/generated/app_localizations.dart` — Main class with abstract getter declarations
- `lib/generated/app_localizations_en.dart` — English translations
- `lib/generated/app_localizations_ru.dart` — Russian translations
- `lib/generated/app_localizations_en_US.dart` — (if locales use variants; check what exists)

**No manual edits required** — regenerate only after ARB updates.

---

## Test Pattern Updates

### `test/features/tracks/tracks_screen_test.dart` (Import Path Update)

**Analog:** `test/features/home/home_screen_test.dart`

**Current import** (line 6):
```dart
import 'package:cadence/features/songs/tracks_screen.dart';
```

**Updated import:**
```dart
import 'package:cadence/features/tracks/tracks_screen.dart';
```

**Pattern note:** Test imports mirror the package structure; directory reorganization requires corresponding import updates in test files.

---

### `test/features/home/home_screen_test.dart` (ARB Key Updates in Test Code)

**Analog:** `test/features/home/home_screen_test.dart` (self)

**Pattern:** Test code uses `tester.strings.<keyName>` to access live ARB-backed strings via the `StringsExtension` in `test/test_strings.dart` (lines 1-27).

**Updates required:**

Locations with `homeAddSongButton` references:
- Line 79: Test description (for readability, not functional)
- Lines 108-110: Widget lookup in assertion (functional)
- Lines 147-149: Widget lookup in loop (functional)

**Line 79 (test description):**
```dart
'bandsCount 0 renders Quick Actions with Add Song/Add Setlist disabled '
```

Change to:
```dart
'bandsCount 0 renders Quick Actions with Add Track/Add Setlist disabled '
```

**Lines 108-110:**
```dart
final addSong = tester.widget<ElevatedButton>(
  find.widgetWithText(ElevatedButton, tester.strings.homeAddSongButton),
);
```

Change to:
```dart
final addTrack = tester.widget<ElevatedButton>(
  find.widgetWithText(ElevatedButton, tester.strings.homeAddTrackButton),
);
```

(Also update local variable name from `addSong` to `addTrack` if used in subsequent assertions; confirm in full file context.)

**Lines 147-150 (in loop):**
```dart
for (final label in [
  tester.strings.homeAddBandButton,
  tester.strings.homeAddSongButton,
  tester.strings.homeAddSetlistButton,
]) {
```

Change to:
```dart
for (final label in [
  tester.strings.homeAddBandButton,
  tester.strings.homeAddTrackButton,
  tester.strings.homeAddSetlistButton,
]) {
```

---

### `test/regression/offline_trust_regression_test.dart` (Path Literal Update)

**Analog:** `test/regression/offline_trust_regression_test.dart` (self)

**Current path literal** (line 34):
```dart
const cachedScreens = [
  'lib/features/profile/profile_screen.dart',
  'lib/features/home/home_screen.dart',
  'lib/features/bands/bands_screen.dart',
  'lib/features/bands/band_detail_screen.dart',
  'lib/features/songs/tracks_screen.dart',  // <-- OLD PATH
  'lib/features/tracks/track_list_screen.dart',
  ...
];
```

**Updated path literal:**
```dart
const cachedScreens = [
  'lib/features/profile/profile_screen.dart',
  'lib/features/home/home_screen.dart',
  'lib/features/bands/bands_screen.dart',
  'lib/features/bands/band_detail_screen.dart',
  'lib/features/tracks/tracks_screen.dart',  // <-- NEW PATH
  'lib/features/tracks/track_list_screen.dart',
  ...
];
```

**Pattern note:** This regression test uses file-content scanning with file paths as strings. Directory reorganization requires updating the path list to match the new structure.

---

### Test Fixture Data Replacements (Multiple Test Files)

**Analog:** `test/features/tracks/create_track_screen_test.dart` and similar

**Pattern:** Test data uses arbitrary sample track titles as fixture values; "Song One", "My Song", "Cached Song" are not meaningful assertions but rather placeholder names for test data.

**Replacements:** Rename all occurrences of test fixture title strings:
- "Song One" → "Track One"
- "Song Two" → "Track Two"
- "Song Three" → "Track Three"
- "My Song" → "My Track"
- "Cached Song" → "Cached Track"
- Any other "Song {X}" pattern → "Track {X}"

**Files affected:**
- `test/providers/setlists_provider_test.dart` — Setlist fixture data
- `test/features/setlists/setlist_detail_screen_test.dart` — Setlist detail fixtures
- `test/features/tracks/track_list_screen_test.dart` — Track list fixtures
- `test/features/tracks/confirm_delete_track_dialog_test.dart` — Confirm dialog fixtures
- `test/features/tracks/create_track_screen_test.dart` — Create screen fixtures
- `test/features/tracks/track_detail_screen_test.dart` — Track detail fixtures
- `test/cache/cache_service_test.dart` — Cache service fixtures

**Example pattern** (from `track_list_screen_test.dart`):
```dart
// BEFORE:
'title': 'Cached Song',

// AFTER:
'title': 'Cached Track',
```

**Pattern note:** These are find/replace operations on string literals; no logic changes. Replacements ensure that grep/search for "song" (case-insensitive) returns zero hits in test files, confirming the terminology rename is complete.

---

## Shared Patterns

### ARB Localization Key Naming Convention

**Source:** `lib/l10n/app_en.arb` and `lib/l10n/app_ru.arb`

**Pattern:** All localization keys follow a hierarchical naming scheme:
- Screen/feature prefix: `home`, `band`, `track`, `setlist`, `profile`, `common`
- Action/type: `AppBarTitle`, `Button`, `Label`, `Message`, `Header`, `Error`, etc.
- Composite example: `homeAddTrackButton` = home screen + add action + track entity + button widget

**Apply to:** All new ARB keys must follow this convention. Renaming `homeAddSongButton` → `homeAddTrackButton` aligns with the sibling keys `homeAddBandButton` and `homeAddSetlistButton`.

---

### Flutter Screen Component Pattern (ConsumerWidget)

**Source:** `lib/features/home/home_screen.dart`, `lib/features/songs/tracks_screen.dart`

**Pattern:**
```dart
class ScreenNameScreen extends ConsumerWidget {
  const ScreenNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    // Listener for tab re-selection (if applicable)
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == tabIndex) ref.invalidate(relevantProvider);
    });

    // Data fetching
    final dataAsync = ref.watch(someDataProvider);

    // Rendering with Scaffold
    return Scaffold(
      appBar: AppBar(...),
      body: dataAsync.when(
        data: (data) => _buildContent(context, ref, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) { ... },
      ),
    );
  }

  // Private helper methods
  Widget _buildContent(...) { ... }
  Widget _buildEmptyState(...) { ... }
  Widget _buildError(...) { ... }
}
```

**Apply to:** All screen files in `lib/features/*/`. File being moved (`tracks_screen.dart`) already follows this pattern; no changes needed to the class itself.

---

### Test File Structure with Mock ApiClient and String Localization

**Source:** `test/features/home/home_screen_test.dart`, `test/features/tracks/create_track_screen_test.dart`

**Pattern:**
```dart
import 'package:cadence/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test_strings.dart';  // StringsExtension for tester.strings

void main() {
  // Mock ApiClient builder
  ApiClient buildApiClient(...) { ... }

  // Widget wrapper with ProviderScope
  Widget wrap(ApiClient apiClient, ...) {
    return ProviderScope(
      overrides: [...],
      child: MaterialApp(
        localizationsDelegates: [...],
        supportedLocales: [...],
        home: ScreenUnderTest(),
      ),
    );
  }

  testWidgets('description', (tester) async {
    await tester.pumpWidget(wrap(...));
    await tester.pumpAndSettle();
    
    // Assert using tester.strings.keyName for live ARB-backed strings
    expect(
      find.text(tester.strings.homeAddTrackButton),
      findsOneWidget,
    );
  });
}
```

**Apply to:** All test files. When ARB keys change, test code using `tester.strings.<keyName>` must be updated to match.

---

## No Analog Found

All files in this phase have direct analogs in the existing codebase. No new file types or patterns are being introduced; this is a pure rename/cleanup phase.

---

## Metadata

**Analog search scope:** `lib/features/`, `lib/navigation/`, `lib/l10n/`, `lib/generated/`, `test/features/`, `test/regression/`, `test/cache/`, `test/providers/`

**Files scanned:** 60+

**Pattern extraction date:** 2026-08-27

**Key findings:**
- All screen files follow a consistent ConsumerWidget + async data pattern
- ARB files use a hierarchical key-naming convention (prefix + action + entity + type)
- Test files consistently use `tester.strings` extension for localization assertions
- Directory restructuring requires corresponding import updates in all dependent files
- Fixture data in tests can be bulk-renamed without behavioral changes
