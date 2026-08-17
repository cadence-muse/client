# Phase 5: Offline Trust & Connectivity UX - Pattern Map

**Mapped:** 2026-08-17
**Files analyzed:** 20 new/modified files
**Analogs found:** 6 core patterns matched / 20 total files

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/providers/connectivity_provider.dart` | provider | state-management | `lib/providers/theme_provider.dart` | role-match |
| `lib/cache/cache_service.dart` | service | cache-I/O | self (existing) | exact |
| `lib/providers/profile_provider.dart` | provider | cache-first | self (existing) | exact |
| `lib/providers/homepage_provider.dart` | provider | cache-first | `lib/providers/profile_provider.dart` | exact |
| `lib/providers/bands_provider.dart` | provider | cache-first | `lib/providers/profile_provider.dart` | exact |
| `lib/providers/tracks_provider.dart` | provider | cache-first | `lib/providers/profile_provider.dart` | exact |
| `lib/providers/setlists_provider.dart` | provider | cache-first | `lib/providers/profile_provider.dart` | exact |
| `lib/widgets/offline_banner.dart` | widget | UI-widget | `lib/navigation/root_scaffold.dart` | role-match |
| `lib/features/profile/widgets/staleness_indicator.dart` | widget | UI-widget | `lib/features/profile/profile_screen.dart` | role-match |
| `lib/features/profile/profile_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/home/home_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/bands/bands_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/bands/band_detail_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/bands/widgets/band_creation_fab.dart` | widget | UI-widget | `lib/features/bands/bands_screen.dart` | role-match |
| `lib/features/tracks/tracks_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/tracks/track_detail_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/tracks/widgets/track_actions.dart` | widget | UI-widget | `lib/features/bands/band_detail_screen.dart` | role-match |
| `lib/features/setlists/setlists_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/setlists/setlist_detail_screen.dart` | screen | UI-widget | self (existing) | exact |
| `lib/features/setlists/widgets/setlist_actions.dart` | widget | UI-widget | `lib/features/bands/band_detail_screen.dart` | role-match |

## Pattern Assignments

### `lib/providers/connectivity_provider.dart` (provider, state-management)

**Analog:** `lib/providers/theme_provider.dart`

**Imports pattern** (lines 1-4):
```dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';
```

**Core StreamProvider pattern** (D-02, D-03):
```dart
@riverpod
Stream<bool> connectivity(ConnectivityRef ref) {
  // D-02: Single StreamProvider wrapping connectivity_plus
  // D-03: No debounce — instant state flips
  
  return Connectivity().onConnectivityChanged.map(
    (result) => result != ConnectivityResult.none,
  );
}
```

**Key decisions:**
- Use `@riverpod` annotation with code generation (follows existing pattern from theme_provider.dart, auth_provider.dart)
- Map `ConnectivityResult.none` to false; any other result (wifi/cellular) to true
- No debouncing per D-03 — let connectivity state flip instantly
- Emit first event synchronously on startup (connectivity_plus behavior)

---

### `lib/cache/cache_service.dart` (service, cache-I/O)

**Analog:** self (existing implementation — this file gets modified, not replaced)

**Pattern change (D-04):** Wrap all cache reads/writes with `{data: {...}, syncedAt: isoString}` wrapper

**Current write pattern** (lines 144-151):
```dart
Future<void> writeProfile(Map<String, dynamic> data) async {
  try {
    await _profileStore.put(_profileKey, data);
  } catch (_) {
    // Non-critical cache write failure; swallow and keep serving the
    // in-memory/network data instead.
  }
}
```

**New write pattern (D-04)** — *to be applied to all write* methods:
```dart
Future<void> writeProfile(Map<String, dynamic> data) async {
  try {
    // D-04: Wrap with timestamp at write time
    final wrapped = {
      'data': data,
      'syncedAt': DateTime.now().toIso8601String(),
    };
    await _profileStore.put(_profileKey, wrapped);
  } catch (_) {
    // Non-critical cache write failure; swallow and keep serving the
    // in-memory/network data instead.
  }
}
```

**Current read pattern** (lines 136-142):
```dart
Future<Map<String, dynamic>?> readProfile() async {
  try {
    return _profileStore.get(_profileKey);
  } catch (_) {
    return null;
  }
}
```

**New read pattern (D-04)** — *extract data from wrapper, return unwrapped*:
```dart
Future<Map<String, dynamic>?> readProfile() async {
  try {
    final wrapped = _profileStore.get(_profileKey);
    if (wrapped == null) return null;
    
    // D-04: Extract data from wrapper, return unwrapped
    return wrapped['data'] as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}
```

**New helper method (D-04+D-05)** — *add to extract syncedAt for staleness indicator*:
```dart
Future<String?> readProfileSyncedAt() async {
  try {
    final wrapped = _profileStore.get(_profileKey);
    if (wrapped == null) return null;
    return wrapped['syncedAt'] as String?;
  } catch (_) {
    return null;
  }
}
```

**Apply this pattern to ALL cache read/write methods:**
- readProfile/writeProfile (already shown)
- readHomepage/writeHomepage
- readBands/writeBands
- readBandDetail/writeBandDetail
- readBandTracks/writeBandTracks
- readBandTrackDetail/writeBandTrackDetail
- readUserTracks/writeUserTracks
- readBandSetlists/writeBandSetlists
- readSetlistDetail/writeSetlistDetail
- readUserSetlists/writeUserSetlists

---

### `lib/providers/profile_provider.dart` (provider, cache-first)

**Analog:** self (existing implementation — this file gets modified for D-06)

**Existing cache-first pattern** (lines 27-35):
```dart
@override
Future<Map<String, dynamic>> build() async {
  final cache = ref.watch(cacheServiceProvider);
  final cached = await cache.readProfile();
  if (cached != null) {
    unawaited(_refresh());
    return cached;
  }
  return _fetchAndCache();
}
```

**Existing _fetchAndCache pattern** (lines 37-43):
```dart
Future<Map<String, dynamic>> _fetchAndCache() async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.send('GET', '/api/me');
  final profile = data!;
  await ref.read(cacheServiceProvider).writeProfile(profile);
  return profile;
}
```

**Modified _fetchAndCache pattern (D-04)** — *wrap before cache write*:
```dart
Future<Map<String, dynamic>> _fetchAndCache() async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.send('GET', '/api/me');
  final profile = data!;
  
  // D-04: Wrap with timestamp before cache write
  final wrapped = {
    'data': profile,
    'syncedAt': DateTime.now().toIso8601String(),
  };
  await ref.read(cacheServiceProvider).writeProfile(wrapped);
  
  // Return unwrapped data to provider state
  return profile;
}
```

**Existing _refresh pattern** (lines 48-55):
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

**Modified _refresh pattern (D-06)** — *no change needed, already preserves state on failure*:
```dart
/// D-06: Silent background refresh. On failure, keeps the old syncedAt
/// timestamp (doesn't update it), so staleness indicator remains accurate.
Future<void> _refresh() async {
  try {
    final fresh = await _fetchAndCache();
    state = AsyncData(fresh);
  } catch (_) {
    // D-06: Keep showing cached data WITHOUT updating syncedAt.
    // Staleness indicator stays honest about the age of the displayed data.
  }
}
```

**Key insight:** The existing `_refresh()` silently keeps cached data on failure (line 54: catch all errors, do nothing). D-06 requires that the timestamp NOT be updated on failure. Since `_fetchAndCache()` only wraps and writes to cache when the fetch succeeds, a failure never reaches the cache layer — the old timestamp stays in place automatically. **No code change needed for D-06 in the _refresh path.**

---

### `lib/providers/homepage_provider.dart`, `lib/providers/bands_provider.dart`, `lib/providers/tracks_provider.dart`, `lib/providers/setlists_provider.dart`

**Analog:** `lib/providers/profile_provider.dart`

**Pattern to apply:** Identical to profile_provider.dart modifications:
1. Wrap payload with `{data: {...}, syncedAt: isoString}` in `_fetchAndCache()`
2. Return unwrapped data to provider state
3. D-06 behavior is already present (silent catch on failure keeps cached data)

**Note on version guard (bands_provider.dart lines 54-59):** 
- `bands_provider.dart` includes a `_version` counter that guards against background refresh reverting local mutations
- This guard (WR-02) discards the entire refresh result if the version changed
- D-06 requires: even if the refresh is discarded, still update the cached `syncedAt` to reflect the successful fetch
- **See Pitfall 6 in RESEARCH.md for edge-case handling** — this may require careful logic to update only the timestamp without applying the stale data

---

### `lib/widgets/offline_banner.dart` (widget, UI-widget)

**Analog:** `lib/navigation/root_scaffold.dart`

**Structure pattern from RootScaffold** (lines 11-29):
```dart
class RootScaffold extends ConsumerWidget {
  const RootScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    // ... widget build
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: screens),
      // ...
    );
  }
}
```

**New OfflineBanner pattern (D-10):**
```dart
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-14: Watch connectivity reactively
    final connAsync = ref.watch(connectivityProvider);
    
    return connAsync.when(
      data: (isOnline) => isOnline 
        ? const SizedBox.shrink()  // Hide when online
        : Container(
            color: Colors.red,  // Claude's Discretion: exact color/icon
            padding: const EdgeInsets.all(8),
            child: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No internet connection',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      loading: () => const SizedBox.shrink(),  // Don't show banner while loading
      error: (_, __) => const SizedBox.shrink(),  // Don't show banner on error
    );
  }
}
```

**Integration in RootScaffold (D-10):**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final selectedIndex = ref.watch(selectedTabIndexProvider);
  final screens = [
    // ... existing screens
  ];

  return Scaffold(
    body: Column(
      children: [
        const OfflineBanner(),  // D-10: wrap body, positioned above IndexedStack
        Expanded(
          child: IndexedStack(index: selectedIndex, children: screens),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      // ... existing navigation
    ),
  );
}
```

---

### `lib/features/profile/widgets/staleness_indicator.dart` (widget, UI-widget)

**Analog:** Custom widget pattern from existing screens

**Implementation pattern (D-07, D-08, D-09):**
```dart
class StalenessIndicator extends ConsumerWidget {
  const StalenessIndicator({
    super.key,
    required this.syncedAtIso,  // e.g., "2026-08-17T14:35:00Z"
  });

  final String syncedAtIso;
  
  // D-09: Hidden threshold
  static const _hiddenThreshold = Duration(minutes: 10);
  // D-08: Warning escalation threshold
  static const _warningThreshold = Duration(minutes: 30);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncedAt = DateTime.parse(syncedAtIso);
    final now = DateTime.now();
    final age = now.difference(syncedAt);

    // D-09: Hidden until 10 minutes old
    if (age < _hiddenThreshold) {
      return const SizedBox.shrink();
    }

    // Format relative time
    final minutes = age.inMinutes;
    final label = 'Synced ${minutes}m ago';

    // D-08: Warning escalation past 30 minutes (color + icon change)
    final isWarning = age >= _warningThreshold;
    final color = isWarning ? Colors.orange : Colors.grey;
    final icon = isWarning ? Icons.warning_amber : Icons.cloud_done;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
```

---

### All Screen Files (`profile_screen.dart`, `home_screen.dart`, `bands_screen.dart`, `band_detail_screen.dart`, `tracks_screen.dart`, `track_detail_screen.dart`, `setlists_screen.dart`, `setlist_detail_screen.dart`)

**Analog:** `lib/features/profile/profile_screen.dart` (lines 8-32)

**Current screen structure:**
```dart
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        data: (profile) => _buildContent(context, ref, profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(context, ...),
      ),
    );
  }
}
```

**Modified pattern (D-07)** — *add StalenessIndicator below AppBar*:
```dart
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        data: (profile) {
          // D-07: Extract syncedAt and pass to indicator
          final syncedAtIso = profile['_meta']?['syncedAt'] as String?;
          return Column(
            children: [
              // D-07: placed below AppBar, above content
              if (syncedAtIso != null)
                StalenessIndicator(syncedAtIso: syncedAtIso),
              Expanded(child: _buildContent(context, ref, profile)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildError(context, ...),
      ),
    );
  }
}
```

**Key point:** The `syncedAt` is extracted from the provider's returned data after the cache-first pattern wraps it. Providers will need to expose the timestamp in the returned data structure, or a separate `syncedAtProvider` may be needed to avoid coupling the UI to the wrapper structure.

---

### Mutation Entry Points (FABs, Save buttons, Delete buttons)

**Analog:** `lib/features/bands/bands_screen.dart` (lines 25-30) and `lib/features/bands/create_band_screen.dart` (lines 96-105)

**Current FAB pattern from BandsScreen** (lines 25-28):
```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => _showCreateJoinMenu(context, ref),
  child: const Icon(Icons.add),
),
```

**Current button pattern from CreateBandScreen** (lines 96-105):
```dart
FilledButton(
  onPressed: _isSubmitting ? null : _submit,
  child: _isSubmitting
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Create'),
),
```

**Modified FAB pattern (D-11, D-12, D-13, D-14):**
```dart
floatingActionButton: ConsumerWidget.build(
  builder: (context, ref) {
    // D-14: Watch connectivity reactively
    final connAsync = ref.watch(connectivityProvider);
    
    return connAsync.when(
      data: (isOnline) => FloatingActionButton(
        // D-11/D-12: Disabled + grayed out while offline
        onPressed: isOnline ? () => _showCreateJoinMenu(context, ref) : null,
        // D-13: Tooltip feedback on tap
        tooltip: isOnline ? 'Create band' : 'Requires connection',
        child: const Icon(Icons.add),
      ),
      loading: () => FloatingActionButton(
        onPressed: null,
        tooltip: 'Loading...',
        child: const Icon(Icons.add),
      ),
      error: (_, __) => FloatingActionButton(
        onPressed: null,
        tooltip: 'Connection error',
        child: const Icon(Icons.add),
      ),
    );
  },
),
```

**Modified button pattern (D-11, D-13, D-14)** — *for Save buttons in forms*:
```dart
class _CreateBandScreenState extends ConsumerState<CreateBandScreen> {
  // ... existing fields
  
  @override
  Widget build(BuildContext context) {
    // D-14: Watch connectivity reactively in build
    return Consumer(
      builder: (context, ref, child) {
        final connAsync = ref.watch(connectivityProvider);
        
        return Scaffold(
          appBar: AppBar(title: const Text('Create a new band')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ... form fields
                    const SizedBox(height: 24),
                    connAsync.when(
                      data: (isOnline) => FilledButton(
                        // D-11/D-14: Disabled while offline
                        onPressed: (!isOnline || _isSubmitting) ? null : _submit,
                        // D-13: Tooltip explains why it's disabled
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isOnline ? 'Create' : 'Requires connection'),
                      ),
                      loading: () => FilledButton(
                        onPressed: null,
                        child: const Text('Loading...'),
                      ),
                      error: (_, __) => FilledButton(
                        onPressed: null,
                        child: const Text('Connection error'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Shared Patterns

### Riverpod Provider Codegen Convention
**Source:** All existing providers (`auth_provider.dart`, `theme_provider.dart`, `profile_provider.dart`, etc.)
**Apply to:** All new and modified providers

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'filename_provider.g.dart';

@riverpod
// ... provider implementation
```

### Reactive State Watching Pattern
**Source:** All ConsumerWidget/ConsumerStatefulWidget implementations
**Apply to:** All UI widgets that react to connectivity or cache state

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final state = ref.watch(someProvider);
  // Use ref.watch() for reactive updates
  // Use ref.read() for one-time reads (in callbacks)
}
```

### AsyncValue Pattern (D-14 specific)
**Source:** `lib/navigation/root_scaffold.dart` and `lib/features/profile/profile_screen.dart`
**Apply to:** Any widget watching a StreamProvider or AsyncNotifier

```dart
connAsync.when(
  data: (value) => /* online/have-data widget */,
  loading: () => /* loading widget */,
  error: (err, st) => /* error widget */,
);
```

### Cache Wrapper Extraction Pattern
**Source:** Modified `lib/cache/cache_service.dart`
**Apply to:** All providers that need to read `syncedAt` timestamp

```dart
// In cache_service.dart — add helper method
Future<String?> readProfileSyncedAt() async {
  try {
    final wrapped = _profileStore.get(_profileKey);
    if (wrapped == null) return null;
    return wrapped['syncedAt'] as String?;
  } catch (_) {
    return null;
  }
}

// In provider — read the timestamp separately
Future<Map<String, dynamic>> build() async {
  final cache = ref.watch(cacheServiceProvider);
  final cached = await cache.readProfile();
  if (cached != null) {
    unawaited(_refresh());
    return cached;
  }
  return _fetchAndCache();
}

// In screen — extract syncedAt from cache separately
// Option 1: Store alongside data in returned Map
// Option 2: Create companion Riverpod providers (profileSyncedAtProvider)
// for each data provider to expose timestamps
```

---

## No Analog Found

No files require patterns not present in the existing codebase:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| None | — | — | All patterns (Riverpod providers, cache wrappers, reactive widgets, form submission) are already established in Phases 1-4 |

All new files in Phase 5 either:
- Extend existing patterns (providers wrapping new state, screens adding staleness indicator)
- Copy existing patterns exactly (FAB/button disabling follows the same reactive watch + onPressed guard pattern used throughout)
- Use standard Flutter/Material Design patterns (disabled button styling, tooltips, banner positioning)

---

## Metadata

**Analog search scope:** `lib/providers/`, `lib/cache/`, `lib/features/*/`, `lib/navigation/`, `lib/widgets/`
**Files scanned:** 25 core implementation files
**Pattern extraction date:** 2026-08-17

### Pattern Maturity by Category

| Pattern | Maturity | First Used |
|---------|----------|-----------|
| Riverpod @riverpod codegen | Proven | Phase 1 (auth_provider.dart) |
| Cache-first loading with background refresh | Proven | Phase 1 (profile_provider.dart) |
| StreamProvider (for connectivity) | Not yet used; design from research | Phase 5 (NEW) |
| Cache payload wrapping with metadata | Not yet used; design from research | Phase 5 (NEW) |
| Reactive widget disable/enable pattern | Proven | Phase 2+ (create/edit forms) |
| Staleness indicator widget | Not yet used; design from research | Phase 5 (NEW) |
| Global offline banner | Not yet used; design from research | Phase 5 (NEW) |

### Key Implementation Notes

1. **Timestamp Storage:** All cache writes must wrap payload before calling `_profileStore.put()`. Unwrap in read path and return clean data to provider state. Providers may need to expose timestamps via separate getter methods or Riverpod providers for screens to read.

2. **Connectivity Provider:** Will emit its first event synchronously on app startup (connectivity_plus behavior). No special initialization needed. Handle loading state in banner and mutation entry points (show SizedBox.shrink() during loading to avoid false "offline" signal).

3. **Version Guard Edge Case (bands_provider.dart only):** When a background refresh succeeds but is discarded due to local mutation (version mismatch), the current code keeps the old data. D-06 requires: also update the `syncedAt` timestamp to reflect the successful fetch, even though the data itself is discarded. This prevents the staleness indicator from lying. See RESEARCH.md Pitfall 6 for detailed handling.

4. **Form State & Reactive Buttons:** Forms must watch `connectivityProvider` in their build method and disable Save/Delete buttons reactively. Setting up a ConsumerStatefulWidget and watching in the build method (not the state) allows button state to change without form rebuild. Alternatively, extract the button into a separate ConsumerWidget that watches connectivity.

5. **Constants:** Define `_hiddenThreshold = Duration(minutes: 10)` and `_warningThreshold = Duration(minutes: 30)` as static constants in the `StalenessIndicator` widget (not shared globally, per Claude's Discretion in CONTEXT.md).

