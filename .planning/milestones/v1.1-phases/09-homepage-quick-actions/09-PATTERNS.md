# Phase 9: Homepage Quick Actions - Pattern Map

**Mapped:** 2026-08-22
**Files analyzed:** 2 (modify 1, create 1 optional)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/home/home_screen.dart` | screen | request-response | `lib/features/home/home_screen.dart` (current) | perfect |
| `lib/features/home/band_picker_sheet.dart` | component | request-response | `lib/features/bands/bands_screen.dart::_showCreateJoinMenu()` | exact |

**Notes:**
- **home_screen.dart:** Being modified in-place; baseline pattern is the existing file itself, so modifications preserve all established patterns (ConsumerWidget, homepageDataProvider watch, tab-switch invalidation, error handling).
- **band_picker_sheet.dart:** Optional separate file. Planner discretion whether to extract as standalone file (mirrors `join_band_dialog.dart` pattern) or keep picker as `_showBandPickerSheet()` private method within `home_screen.dart` (simpler for Phase 9, mirrors `bands_screen.dart::_showCreateJoinMenu()` approach).

## Pattern Assignments

### `lib/features/home/home_screen.dart` (screen, request-response)

**Primary Analog:** `lib/features/home/home_screen.dart` (existing)
**Secondary Analogs:** `lib/features/bands/bands_screen.dart` (tab structure, modal pattern)

**Imports pattern** (lines 1-8):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/homepage_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../widgets/offline_no_cache_view.dart';
import '../bands/bands_screen.dart';
```

**Key pattern: ConsumerWidget with tab-switch invalidation listener** (lines 10-23):
```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tab re-entry invalidates provider to fetch fresh data
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == 0) ref.invalidate(homepageDataProvider);
    });

    final homeAsync = ref.watch(homepageDataProvider);
```

**Scaffold structure with AppBar + body** (lines 25-58):
```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(homepageDataProvider.notifier).refresh(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: homeAsync.isLoading && homeAsync.hasValue
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
      ),
      body: homeAsync.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(homepageDataProvider),
          );
        },
      ),
    );
```

**Data structure and content building** (lines 61-120):
```dart
  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final username = data['username'] as String;
    final bandsCount = data['bandsCount'] as int;

    // D-03: Replace zero-bands conditional with unified layout
    // Phase 9 restructure: welcome card + quick actions header + button row
    // (both states use same layout, not separate branches)
    
    // Current structure (to be replaced):
    if (bandsCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(...),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome, $username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            // ... rest of content
          ],
        ),
      ),
    );
  }
```

**Error widget pattern** (lines 122-145):
```dart
  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Couldn't load home",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
```

---

### `lib/features/home/band_picker_sheet.dart` (component, request-response)

**Primary Analog:** `lib/features/bands/bands_screen.dart::_showCreateJoinMenu()` (lines 68-96)

**Imports pattern:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bands_provider.dart';
import '../tracks/create_track_screen.dart';
import '../setlists/create_setlist_screen.dart';
```

**Bottom-sheet modal pattern** (lines 68-96 from bands_screen.dart):
```dart
void _showCreateJoinMenu(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Create band'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateBandScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Join with code'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              showJoinBandDialog(context, ref);
            },
          ),
        ],
      ),
    ),
  );
}
```

**Key pattern for band picker adaptation:**
```dart
// Phase 9 band-picker pattern (adapted from _showCreateJoinMenu):
void _showBandPickerSheet(
  BuildContext context,
  WidgetRef ref,
  bool shouldCreateTrack, // true for track, false for setlist
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      final bandsAsync = ref.watch(bandsListDataProvider);
      return SafeArea(
        child: bandsAsync.when(
          data: (bands) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final band in bands)
                ListTile(
                  leading: const Icon(Icons.group),
                  title: Text(
                    band['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    final bandId = band['id'] as String;
                    if (shouldCreateTrack) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateTrackScreen(bandId: bandId),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateSetlistScreen(bandId: bandId),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error loading bands'),
          ),
        ),
      );
    },
  );
}
```

**Navigation pattern from picker to create screen:**
- Key: `Navigator.pop()` inside sheet context, then `Navigator.push()` outside
- Data passed: `bandId` extracted from selected band and passed to constructor
- Both CreateTrackScreen and CreateSetlistScreen require `required String bandId` parameter

**Create screen signatures:**
```dart
// From create_track_screen.dart (lines 10-13)
class CreateTrackScreen extends ConsumerStatefulWidget {
  const CreateTrackScreen({super.key, required this.bandId});
  final String bandId;

// From create_setlist_screen.dart (lines 11-14)
class CreateSetlistScreen extends ConsumerStatefulWidget {
  const CreateSetlistScreen({super.key, required this.bandId});
  final String bandId;
```

---

## Shared Patterns

### Tab-Switch Invalidation Pattern
**Source:** `lib/features/home/home_screen.dart` (lines 19-21) and `lib/features/bands/bands_screen.dart` (lines 26-28)
**Apply to:** All tab screens (Home, Bands, Tracks, Setlists, Profile)
**Pattern:**
```dart
ref.listen<int>(selectedTabIndexProvider, (previous, current) {
  if (current == 0) ref.invalidate(homepageDataProvider);  // e.g., Home tab
});
```
**Purpose:** Ensures fresh data when user re-enters a tab (tab kept alive by IndexedStack, doesn't auto-rebuild on re-entry otherwise).

### AsyncValue.when() Pattern for Loading/Error/Data
**Source:** `lib/features/home/home_screen.dart` (lines 45-58)
**Apply to:** All screens with async data providers
**Pattern:**
```dart
body: homeAsync.when(
  data: (data) => _buildContent(context, data),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, stackTrace) {
    if (error is OfflineNoCacheException) {
      return const OfflineNoCacheView();
    }
    return _buildError(context, () => ref.invalidate(homepageDataProvider));
  },
),
```
**Purpose:** Handles three states of async data (loading spinner, error with offline fallback, success). Established pattern across all data-fetching screens.

### Modal Bottom Sheet for Selection
**Source:** `lib/features/bands/bands_screen.dart::_showCreateJoinMenu()` (lines 68-96)
**Apply to:** Band picker in home_screen.dart
**Pattern:**
```dart
showModalBottomSheet<void>(
  context: context,
  builder: (sheetContext) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ListTiles with onTap handlers
      ],
    ),
  ),
);
```
**Purpose:** Shows a modal list for user selection. `SafeArea` ensures content avoids system UI. `Column(mainAxisSize: MainAxisSize.min)` sizes sheet to content, not full-height. Navigation happens outside the sheet after `Navigator.pop()` dismisses it.

### Button Enable/Disable Based on State
**Source:** Established Material Design convention, used implicitly in all existing screens
**Apply to:** Quick-action buttons (Add Song, Add Setlist disabled when bandsCount == 0)
**Pattern:**
```dart
ElevatedButton.icon(
  onPressed: bandsCount > 0
      ? () => _showBandPickerSheet(context, ref, true)
      : null,  // null disables button (Material renders grayed out)
  icon: const Icon(Icons.music_note),
  label: const Text('Add Song'),
)
```
**Purpose:** Disabled visual state communicates precondition; no extra dialog or snackbar needed (per D-09).

### Riverpod ChangeNotifier Pattern
**Source:** `lib/api/auth_session.dart` (pattern used throughout codebase), accessed via `ref.read()`, `ref.watch()`, `ref.listen()`
**Apply to:** All provider reads/watches in new code
**Pattern:**
```dart
// Watch for reactive UI updates
final homeAsync = ref.watch(homepageDataProvider);

// Read for one-time operations
final publicApi = ref.read(publicApiProvider);

// Listen for side effects (like tab-switch)
ref.listen<int>(selectedTabIndexProvider, (previous, current) { ... });

// Invalidate to refresh
ref.invalidate(homepageDataProvider);
```
**Purpose:** Established Riverpod state management pattern across entire codebase.

---

## No Analog Found

**None.** All patterns needed for Phase 9 (screen restructure, modal picker, button row, navigation) have strong analogs in existing codebase:
- Screen structure: existing home_screen.dart
- Modal picker: bands_screen.dart::_showCreateJoinMenu
- Create screens: existing create_band_screen.dart, create_track_screen.dart, create_setlist_screen.dart
- Navigation after picker selection: join_band_dialog.dart demonstrates post-dialog navigation

## Metadata

**Analog search scope:** 
- `lib/features/home/` — home screen files
- `lib/features/bands/` — band management screens (modal patterns)
- `lib/features/tracks/` — track creation screen signature
- `lib/features/setlists/` — setlist creation screen signature
- `lib/providers/` — data provider patterns

**Files scanned:** 6 source files + 2 provider files

**Pattern extraction date:** 2026-08-22

**Key Assumptions:**
- `bandsListDataProvider` returns `List<Map<String, dynamic>>` with 'id' and 'name' fields per band
- `homepageDataProvider` returns `Map<String, dynamic>` with 'username' and 'bandsCount' fields
- CreateTrackScreen and CreateSetlistScreen both require `required String bandId` constructor parameter
- Modal bottom sheet dismiss behavior (tap outside, back button) works per Material spec
- All navigation uses `Navigator.push(MaterialPageRoute(...))` pattern (no named routes, no go_router)
