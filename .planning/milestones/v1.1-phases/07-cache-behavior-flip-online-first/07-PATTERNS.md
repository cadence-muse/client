# Phase 07: Cache Behavior Flip — Online-First - Pattern Map

**Mapped:** 2026-08-21
**Files analyzed:** 16 new/modified files
**Analogs found:** 16 / 16 (100%)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/providers/bands_provider.dart` | data-provider | CRUD | Self (existing) | exact |
| `lib/providers/tracks_provider.dart` | data-provider | CRUD | `bands_provider.dart` | exact |
| `lib/providers/setlists_provider.dart` | data-provider | CRUD | `bands_provider.dart` | exact |
| `lib/providers/homepage_provider.dart` | data-provider | CRUD | Self (existing) | exact |
| `lib/providers/profile_provider.dart` | data-provider | CRUD | `homepage_provider.dart` | exact |
| `lib/providers/exception.dart` (NEW) | utility | N/A | `lib/api/api_exception.dart` | similar |
| `lib/widgets/offline_banner.dart` | widget | request-response | Self (existing) | exact |
| `lib/features/home/home_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/bands/bands_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/bands/band_detail_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/songs/tracks_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/songs/track_detail_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/songs/track_list_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/setlists/setlists_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/setlists/setlist_detail_screen.dart` | screen | request-response | Self (existing) | exact |
| `lib/features/profile/profile_screen.dart` | screen | request-response | Self (existing) | exact |

---

## Pattern Assignments

### `lib/providers/bands_provider.dart` (data-provider, CRUD)

**Analog:** Self (existing cache-first pattern)

**Current imports pattern** (lines 1-8):
```dart
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_provider.dart';
import '../cache/cache_service.dart';

part 'bands_provider.g.dart';
```

**Current cache-first `build()` pattern** (lines 59-70):
```dart
@override
Future<List<Map<String, dynamic>>> build() async {
  final cache = ref.watch(cacheServiceProvider);
  final cached = await cache.readBands();
  if (cached != null) {
    ref.read(bandsListSyncedAtProvider.notifier).set(await cache.readBandsSyncedAt());
    unawaited(_refresh());  // Silent background refresh
    return cached;
  }
  return _fetchAndCache();
}
```

**Pattern to refactor to (online-first logic D-01/D-03)**:
Replace the above `build()` method to:
1. Watch `isOnlineProvider` (from `connectivity_provider.dart`)
2. If online: try to fetch fresh, fall back to cache on failure (D-03)
3. If offline: use cache if available, else throw `OfflineNoCacheException` (D-06)
4. Add tab-switch listener using `ref.listen(selectedTabIndexProvider, ...)` (D-01)

**_fetchAndCache() method pattern** (lines 72-77) — unchanged:
```dart
Future<List<Map<String, dynamic>>> _fetchAndCache() async {
  final bands = await ref.read(publicApiProvider).listBands();
  await ref.read(cacheServiceProvider).writeBands(bands);
  ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
  return bands;
}
```

**_doRefresh() method pattern** (lines 103-116) — preserve `_version` guard, but modify catch logic (D-08/D-09):
```dart
Future<void> _doRefresh() async {
  final capturedVersion = _version;
  try {
    final fresh = await _fetchAndCache();
    if (_version == capturedVersion) {
      state = AsyncData(fresh);
    }
  } catch (e, st) {
    if (state.value == null) {
      state = AsyncError(e, st);  // Only show error on cold start (D-09)
    }
    // Otherwise silently keep the last good data visible (D-08)
  }
}
```

**Key pattern rules:**
- Preserve `_version` monotonic counter (lines 56, 83-87, 104-107) to prevent race conditions on slow fetches
- Preserve `_inFlightRefresh` deduplication (line 49, 97-100) for user-initiated refresh
- Add new imports: `import '../providers/connectivity_provider.dart';` and `import '../providers/navigation_provider.dart';` to access `isOnlineProvider` and `selectedTabIndexProvider`

---

### `lib/providers/tracks_provider.dart` (data-provider, CRUD)

**Analog:** `lib/providers/bands_provider.dart` (same refactor pattern, with `bandId` family parameter)

**Current structure (lines 39-107):**
- `TrackListData` class with family key `String bandId` (line 50)
- Same cache-first pattern as BandsListData (lines 50-61)
- Same `_fetchAndCache()` structure (lines 63-68)
- Same `_refresh()` and `_doRefresh()` with `_version` guard (lines 73-107)
- `_version` field (line 47)
- `removeFromList()` mutation method (lines 114-125)

**Apply the same online-first refactor to `TrackListData.build()`** (lines 50-61):
1. Watch `isOnlineProvider`
2. Online: fetch fresh, fall back to cache on error
3. Offline: use cache or throw `OfflineNoCacheException`
4. Add tab-switch listener for tab index 2 (Tracks tab)

**Also refactor `TrackDetailData`** (lines 151+) — same pattern, family key `(String bandId, String trackId)`

---

### `lib/providers/setlists_provider.dart` (data-provider, CRUD)

**Analog:** `lib/providers/tracks_provider.dart` (identical refactor pattern)

**Current structure:**
- `SetlistListData` class with family key `String bandId` (similar to TrackListData)
- Same cache-first pattern (lines 50-61)
- Same `_fetchAndCache()` structure (lines 63-70)
- Same `_refresh()` and `_doRefresh()` with `_version` guard (lines 75-109)
- `removeFromList()` mutation method (lines 116-129)

**Apply the same online-first refactor to both `SetlistListData` and `SetlistDetailData`**:
1. Watch `isOnlineProvider`
2. Online → fetch fresh, offline fallback
3. Offline → cache or exception
4. Add tab-switch listener for tab index 3 (Setlists tab)

---

### `lib/providers/homepage_provider.dart` (data-provider, CRUD)

**Analog:** Self (existing cache-first pattern, simpler — no `_version` guard)

**Current `build()` pattern** (lines 40-51):
```dart
@override
Future<Map<String, dynamic>> build() async {
  final cache = ref.watch(cacheServiceProvider);
  final cached = await cache.readHomepage();
  if (cached != null) {
    ref.read(homepageSyncedAtProvider.notifier).set(await cache.readHomepageSyncedAt());
    unawaited(_refresh());
    return cached;
  }
  return _fetchAndCache();
}
```

**Pattern to refactor to:**
- Same online-first logic as bands/tracks/setlists
- Note: HomepageData does NOT use `_version` guard (unlike bands/tracks/setlists) — keep this simplification
- Add tab-switch listener for tab index 0 (Home tab)
- Otherwise follows same fetch/cache fallback pattern

**_refresh() method** (lines 65-72) — no `_version` guard:
```dart
Future<void> _refresh() async {
  try {
    final fresh = await _fetchAndCache();
    state = AsyncData(fresh);
  } catch (_) {
    // Keep showing cached data.
  }
}
```

---

### `lib/providers/profile_provider.dart` (data-provider, CRUD)

**Analog:** `lib/providers/homepage_provider.dart` (same simple pattern, no `_version` guard)

**Current `build()` pattern** (lines 40-51):
```dart
@override
Future<Map<String, dynamic>> build() async {
  final cache = ref.watch(cacheServiceProvider);
  final cached = await cache.readProfile();
  if (cached != null) {
    ref.read(profileSyncedAtProvider.notifier).set(await cache.readProfileSyncedAt());
    unawaited(_refresh());
    return cached;
  }
  return _fetchAndCache();
}
```

**Pattern to refactor to:**
- Same online-first logic as homepage
- No `_version` guard (read-mostly, mutations rare)
- Note: D-02 specifies "no new wiring" for detail screens, so ProfileData (which is NOT a detail screen, it's a root tab screen) DOES need tab-switch listener for tab index 4 (Profile tab)
- Otherwise follows same fetch/cache fallback pattern

---

### `lib/providers/exception.dart` (NEW utility, N/A)

**Analog:** `lib/api/api_exception.dart`

**Reference exception pattern** (api_exception.dart shows `ApiException` with `statusCode`, `code`, `message` fields):
```dart
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });
  
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
```

**New exception to create** (lib/providers/exception.dart or inline in provider files):
```dart
class OfflineNoCacheException implements Exception {
  const OfflineNoCacheException();

  @override
  String toString() => 'OfflineNoCacheException: No cached data available offline';
}
```

**Decision:** Inline the exception in each provider file (e.g., at the top of `bands_provider.dart`, `tracks_provider.dart`, etc.) or create a shared `lib/providers/exceptions.dart` file. Recommend inline for now to avoid new import dependencies across providers.

---

### `lib/widgets/offline_banner.dart` (widget, request-response)

**Analog:** Self (existing widget)

**Current implementation** (lines 9-37):
```dart
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (isOnline) {
      return const SizedBox.shrink();
    }

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
              "You're offline — showing cached data",  // OLD
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Pattern to refactor to (D-04):**
Change the banner text from `"You're offline — showing cached data"` to:
```dart
"Showing cached data — may be out of date"
```

This reworded message covers the case where online-but-fetch-failed also serves cached data silently (D-03).

**No structural changes required** — D-05 confirms the banner stays device-level `isOnlineProvider`, not per-screen or aggregate logic.

---

### `lib/features/home/home_screen.dart` (screen, request-response)

**Analog:** Self (existing screen)

**Current pattern** (lines 12-39):
```dart
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homepageDataProvider);
    final syncedAt = ref.watch(homepageSyncedAtProvider);  // TO REMOVE

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: homeAsync.when(
        data: (data) => Column(
          children: [
            SyncStatusBadge(syncedAt: syncedAt),  // TO REMOVE
            Expanded(child: _buildContent(context, data)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _buildError(context, () => ref.invalidate(homepageDataProvider)),
      ),
    );
  }
  // ... rest
}
```

**Refactor pattern:**
1. Remove the line `final syncedAt = ref.watch(homepageSyncedAtProvider);`
2. Remove the `SyncStatusBadge` widget from the Column
3. Add tab-switch listener: `ref.listen(selectedTabIndexProvider, (prev, current) { if (current == 0) ref.invalidate(homepageDataProvider); });`
4. Add subtle refresh indicator to AppBar (D-08): conditionally show `LinearProgressIndicator` when `homeAsync.isLoading && homeAsync.hasValue`
5. Update error handling to check for `OfflineNoCacheException` (D-06) and show offline-specific layout instead of generic retry button

**New AppBar pattern with refresh indicator** (D-08):
```dart
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
```

**New error handling pattern** (D-06):
```dart
error: (error, st) {
  if (error is OfflineNoCacheException) {
    return _buildOfflineError(context);  // D-06: special offline-no-cache state
  }
  return _buildError(context, () => ref.invalidate(homepageDataProvider));
},
```

**New offline-error widget** (D-06):
```dart
Widget _buildOfflineError(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'No cached data',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Connect to the internet to load this',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
```

---

### `lib/features/bands/bands_screen.dart` (screen, request-response)

**Analog:** `lib/features/home/home_screen.dart` (same refactor pattern)

**Current pattern** (lines 15-44):
```dart
class BandsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandsAsync = ref.watch(bandsListDataProvider);
    final syncedAt = ref.watch(bandsListSyncedAtProvider);  // TO REMOVE
    final isOnline = ref.watch(isOnlineProvider);
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bands')),
      body: bandsAsync.when(
        data: (bands) => Column(
          children: [
            SyncStatusBadge(syncedAt: syncedAt),  // TO REMOVE
            Expanded(child: _buildContent(context, bands, profileAsync)),
          ],
        ),
        // ...
      ),
    );
  }
}
```

**Refactor pattern (same as HomeScreen):**
1. Remove `syncedAt` watch
2. Remove `SyncStatusBadge` widget
3. Add tab-switch listener for tab index 1
4. Add AppBar progress indicator (D-08)
5. Update error handling for `OfflineNoCacheException` (D-06)
6. Reuse `_buildOfflineError()` helper from home_screen or extract to shared widget

---

### `lib/features/bands/band_detail_screen.dart` (screen, request-response)

**Analog:** Self (existing detail screen, different pattern than tab screens)

**Important note (D-02):** Band/Track/Setlist detail screens use `autoDispose` family providers that already rebuild on every `Navigator.push`, so they need NO new tab-switch wiring. They only need:
1. Remove `SyncStatusBadge` widget (mechanical removal)
2. Remove `syncedAt` watch
3. Update error handling to check for `OfflineNoCacheException`
4. Add `_buildOfflineError()` method

**No tab-switch listener needed** — the detail screen's provider auto-rebuilds on route push.

---

### `lib/features/songs/tracks_screen.dart` (screen, request-response)

**Analog:** `lib/features/bands/bands_screen.dart` (tab screen with refactor)

**Pattern:** Same as BandsScreen — tab-screen pattern, tab index 2

**Remove:** `SyncStatusBadge` and `syncedAt` watches
**Add:** Tab-switch listener (index 2), AppBar progress indicator, offline-error handling

---

### `lib/features/songs/track_detail_screen.dart` (screen, request-response)

**Analog:** `lib/features/bands/band_detail_screen.dart` (detail screen pattern, NO tab-switch wiring)

**Pattern:** Same as band_detail_screen — detail pattern, auto-rebuild on push

**Remove:** `SyncStatusBadge` and `syncedAt` watches
**Add:** Offline-error handling (NO tab-switch listener)

---

### `lib/features/songs/track_list_screen.dart` (screen, request-response)

**Alias:** This may be `tracks_screen.dart` or a separate list view — check codebase for exact file name.

**Pattern:** Same as Tracks tab screen — tab-switch listener for tab index 2

---

### `lib/features/setlists/setlists_screen.dart` (screen, request-response)

**Analog:** `lib/features/bands/bands_screen.dart` (tab screen with refactor)

**Pattern:** Same as BandsScreen — tab-screen pattern, tab index 3

**Remove:** `SyncStatusBadge` and `syncedAt` watches
**Add:** Tab-switch listener (index 3), AppBar progress indicator, offline-error handling

---

### `lib/features/setlists/setlist_detail_screen.dart` (screen, request-response)

**Analog:** `lib/features/bands/band_detail_screen.dart` (detail screen pattern, NO tab-switch wiring)

**Pattern:** Same as band_detail_screen — detail pattern, auto-rebuild on push

**Remove:** `SyncStatusBadge` and `syncedAt` watches
**Add:** Offline-error handling (NO tab-switch listener)

---

### `lib/features/profile/profile_screen.dart` (screen, request-response)

**Analog:** `lib/features/home/home_screen.dart` (tab screen with refactor)

**Pattern:** Same as HomeScreen — tab-screen pattern, tab index 4

**Remove:** `SyncStatusBadge` and `syncedAt` watches
**Add:** Tab-switch listener (index 4), AppBar progress indicator, offline-error handling

---

## Shared Patterns

### Tab-Switch Listener Pattern (D-01)

**Apply to all 5 tab screens:** Home (index 0), Bands (index 1), Tracks (index 2), Setlists (index 3), Profile (index 4)

**Option A — Provider-level listener (centralizes invalidation logic):**
```dart
@override
Future<List<Map<String, dynamic>>> build() async {
  ref.listen(selectedTabIndexProvider, (previous, current) {
    if (current == 1) {  // This provider's tab index
      ref.invalidateSelf();
    }
  });
  
  final isOnline = ref.watch(isOnlineProvider);
  // ... rest of online-first logic
}
```

**Option B — Screen-level listener (more declarative for UI lifecycle):**
```dart
class BandsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(selectedTabIndexProvider, (previous, current) {
      if (current == 1) {
        ref.invalidate(bandsListDataProvider);
      }
    });
    
    final bandsAsync = ref.watch(bandsListDataProvider);
    // ... rest
  }
}
```

**Recommendation:** Use Option B (screen-level) for clarity — each screen owns its tab-index logic, avoiding provider-to-screen coupling.

### Online-First Logic Pattern (D-01/D-03/D-06)

**Applies to all 10 data providers:**

```dart
@override
Future<List<Map<String, dynamic>>> build() async {
  final isOnline = ref.watch(isOnlineProvider);  // NEW: watch connectivity
  final cache = ref.watch(cacheServiceProvider);
  
  if (isOnline) {
    // Online: fetch fresh, fall back to cache on error
    try {
      return await _fetchAndCache();
    } catch (_) {
      // D-03: online but fetch failed — fall back to cache
      final cached = await cache.readBands();
      if (cached != null) {
        ref.read(bandsListSyncedAtProvider.notifier).set(await cache.readBandsSyncedAt());
        return cached;
      }
      rethrow;  // No cache; surface error
    }
  } else {
    // Offline: use cache if available
    final cached = await cache.readBands();
    if (cached != null) {
      ref.read(bandsListSyncedAtProvider.notifier).set(await cache.readBandsSyncedAt());
      return cached;
    }
    // D-06: offline with no cache
    throw OfflineNoCacheException();
  }
}
```

### Refresh Indicator UX Pattern (D-08/D-09)

**Apply to all tab screens (5 screens):**

**AppBar with conditional progress indicator:**
```dart
appBar: AppBar(
  title: const Text('Bands'),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(2),
    child: bandsAsync.isLoading && bandsAsync.hasValue
        ? const LinearProgressIndicator()
        : const SizedBox.shrink(),
  ),
),
```

**Cold-start spinner still shown (D-09):**
```dart
bandsAsync.when(
  data: (bands) => /* ... */,
  loading: () => const Center(child: CircularProgressIndicator()),  // D-09: still shown on cold start
  error: (error, st) => /* ... */,
)
```

### Offline-No-Cache Error State Pattern (D-06)

**Apply to all screens with error handling:**

```dart
error: (error, st) {
  if (error is OfflineNoCacheException) {
    return _buildOfflineError(context);
  }
  return _buildError(context, retryFn);
}

Widget _buildOfflineError(BuildContext context) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'No cached data',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Connect to the internet to load this',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
```

### Banner Reword Pattern (D-04)

**Single change in `lib/widgets/offline_banner.dart` (line 29):**

**Before:**
```dart
"You're offline — showing cached data"
```

**After:**
```dart
"Showing cached data — may be out of date"
```

### SyncStatusBadge Removal Pattern

**Mechanical removal from 10 files:**

1. Delete the import: `import '../../widgets/sync_status_badge.dart';`
2. Delete the watch: `final syncedAt = ref.watch(bandsListSyncedAtProvider);`
3. Delete the widget from the Column: `SyncStatusBadge(syncedAt: syncedAt),`
4. Run `flutter analyze` to catch unused imports

**Files to clean:**
- `lib/features/home/home_screen.dart`
- `lib/features/bands/bands_screen.dart`
- `lib/features/bands/band_detail_screen.dart`
- `lib/features/songs/tracks_screen.dart` (×2 occurrences if both list and detail screens use it)
- `lib/features/songs/track_detail_screen.dart`
- `lib/features/songs/track_list_screen.dart` (if separate from tracks_screen)
- `lib/features/setlists/setlists_screen.dart`
- `lib/features/setlists/setlist_detail_screen.dart`
- `lib/features/profile/profile_screen.dart`

---

## No Analog Found

All files have existing analogs in the codebase. No new patterns need to be invented from scratch.

---

## Key Import Additions Required

All modified providers will need new imports to access connectivity and navigation state:

**Add to all 5 data providers:**
```dart
import '../providers/connectivity_provider.dart';
import '../providers/navigation_provider.dart';
```

**Already present in screen files:**
```dart
import '../../providers/connectivity_provider.dart';  // isOnlineProvider
```

---

## Metadata

**Analog search scope:** `/lib/providers/`, `/lib/features/`, `/lib/widgets/`, `/lib/api/`
**Files scanned:** 25+ Dart files (providers, screens, widgets, exceptions)
**Pattern extraction date:** 2026-08-21
**Confidence:** HIGH — all patterns drawn from existing, working code (Phase 6 baseline)

---

*Phase 07: Cache Behavior Flip — Online-First*
*Pattern mapping completed: 2026-08-21*
