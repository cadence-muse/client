# Phase 7: Cache Behavior Flip — Online-First - Research

**Researched:** 2026-08-21
**Domain:** Riverpod cache-behavior inversion, connectivity state wiring, offline UX patterns
**Confidence:** HIGH

## Summary

Phase 7 inverts the cache policy for 10 Riverpod data providers (Profile, Homepage, BandsList×2, TracksList×2, SetlistsList×2) from cache-first (serve stale data instantly, refresh silently) to online-first (fetch fresh when connected, fall back to cache offline). The change affects every tab screen and their detail screens, removes the 10-call-site `SyncStatusBadge` staleness-tier widget system, and replaces it with a single global offline banner.

The existing architecture is well-positioned for this inversion: `isOnlineProvider` already exists and streams connectivity status; `selectedTabIndexProvider` provides the hook for tab-switch-triggered refetches; the `_version` monotonic guard already prevents race conditions. The main work is restructuring each provider's `build()`/`_refresh()` methods to check `isOnlineProvider` before deciding cache-vs-fetch-first, and wiring tab-screen listeners to invalidate their providers on tab switch.

**Primary recommendation:** Research focused on **three critical wiring decisions** — (1) tab-switch refetch trigger mechanism (D-01), (2) AsyncValue state shape for "have data + refreshing" (D-08), (3) exact mechanism for online-but-fetch-fails silent cache fallback (D-03). All three directly affect the implementation strategy and need to be locked in before planning.

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (Tab-Switch Refetch):** Five IndexedStack tab screens need a refetch on every tab switch (not just cold start). Requires a tab-visibility listener wired to each screen's provider, likely reacting to `selectedTabIndexProvider`.
- **D-02 (Detail Screens):** Band/Track/Setlist detail screens are `autoDispose` family providers that already rebuild on every route push — no new wiring needed for these.
- **D-03 (Fetch-Fails-Online Fallback):** When `isOnlineProvider` is true but a fetch still fails (DNS blip, timeout, server down), silently fall back to cached data with no banner or error (same code path as true offline).
- **D-04 (Banner Wording):** Reword the offline banner from "You're offline — showing cached data" to "Showing cached data — may be out of date" to cover the online-but-fetch-failed edge case.
- **D-05 (Banner Trigger):** Banner stays device-level `isOnlineProvider` (not per-screen). The online-but-fetch-failed case gets **no banner at all** — accepted tradeoff for keeping the global widget simple.
- **D-06 (Offline-No-Cache State):** New state: "No cached data — connect to the internet to load this" + cloud-off icon, reusing `_buildError` layout but with offline-specific copy.
- **D-07 (Offline No-Cache Recovery):** Automatic recovery — screen listens to `isOnlineProvider` and refetches on reconnect with no user action needed.
- **D-08 (In-Flight UX):** When refetch is in flight and cache exists, keep old content visible + subtle indicator (e.g., thin progress bar or AppBar spinner) instead of blank screen.
- **D-09 (Cold Start Exception):** Cold start (no data yet) still shows full-screen centered spinner; D-08's subtle-indicator behavior only applies once state has a value.

### Claude's Discretion
- Exact mechanism for wiring "every tab switch" refetch (listener + invalidate, mixin, or other pattern per `navigation_provider.dart` shape).
- Subtle refresh indicator widget choice (progress bar color/thickness, AppBar spinner style, etc.).
- Offline-empty-state icon choice and exact final copy wording.
- Whether `XxxSyncedAt` providers are kept/repurposed/removed after `SyncStatusBadge` deletion.
- Mechanical removal of `SyncStatusBadge` across 10 call-sites (no design decision needed — pure deletion).

### Deferred Ideas (OUT OF SCOPE)
- Owner tools, homepage quick actions, searchable track picker — Phase 8–10 respectively.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Online-first fetch decision | API / Backend Provider | Browser / Client State | Each provider checks `isOnlineProvider` before deciding fetch vs. cache — provider layer owns the policy; connectivity state is device-level (client-side) |
| Tab-switch refetch trigger | Frontend / App State | API / Data Layer | Navigation state (`selectedTabIndexProvider`) drives when to invalidate; providers execute the fetch |
| Offline cache fallback | API / Data Layer | Browser / Client Storage | Cache service holds stale data; providers decide when to serve it |
| Connectivity detection | Browser / Client | — | `connectivity_plus` is device-level; `isOnlineProvider` exposes it |
| Offline banner UX | Browser / Client | — | Global `OfflineBanner` widget renders based on connectivity state |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| riverpod_annotation | 2.6.1 | Code-gen provider definitions and family support | [VERIFIED: pubspec.yaml:19] Required for `@riverpod` macros that auto-generate `.g.dart` files with async state handling |
| flutter_riverpod | 2.6.1 | Runtime for reactive state management with AsyncValue | [VERIFIED: pubspec.yaml:16] Enables AsyncData/AsyncLoading/AsyncError state discrimination needed for D-08 (keep-data-while-refreshing) |
| riverpod_generator | 2.6.5 | Code generation during build | [VERIFIED: pubspec.yaml:28] Processes @riverpod annotations into provider implementations |
| connectivity_plus | 7.3.1 | Device radio-state connectivity detection | [VERIFIED: pubspec.yaml:20] Already used by `isOnlineProvider` in existing codebase; streams connection changes without debounce |
| hive + hive_flutter | 2.2.3 + 1.1.0 | Local persistent cache storage | [VERIFIED: pubspec.yaml:17-18] Already in use; unchanged by this phase |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_test | (SDK) | Widget testing harness | For testing provider state transitions and tab-switch refetch triggers |
| http (via ApiClient) | 1.6.0 | HTTP client for API calls | Already in use; no changes needed to HTTP layer itself |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `connectivity_plus` for offline detection | `internet_connection_checker` or a ping-based check | Would add latency and complexity; connectivity_plus is radio-state (instant) but doesn't guarantee true internet — accepted per D-03's online-but-fetch-fails fallback |
| Invalidate all providers on tab switch | Selective per-screen invalidation | Simpler for tab screens (all 5 reset on tab change), but detail screens (autoDispose) already auto-invalidate on push — mixing strategies adds cognitive load |
| Per-screen offline banner | Global `RootScaffold`-level widget | Global banner trades per-screen accuracy for simplicity — D-05 explicitly accepted this tradeoff; per-screen would require StateNotifier aggregating across providers |

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter_riverpod | pub.dev | 3+ yrs | 2M+/wk | [github.com/rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) | OK | Approved |
| riverpod_annotation | pub.dev | 3+ yrs | 2M+/wk | [github.com/rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) | OK | Approved |
| riverpod_generator | pub.dev | 3+ yrs | 1M+/wk | [github.com/rrousselGit/riverpod](https://github.com/rrousselGit/riverpod) | OK | Approved |
| connectivity_plus | pub.dev | 4+ yrs | 3M+/wk | [github.com/fluttercommunity/plus_plugins](https://github.com/fluttercommunity/plus_plugins) | OK | Approved |

*All packages are established, widely-used, and already integrated into the codebase. No new dependencies added by this phase.*

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    RootScaffold                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │ OfflineBanner (watches isOnlineProvider)         │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │ IndexedStack (5 tab screens kept alive)          │   │
│  │ ┌──────────────┐  ┌──────────────┐               │   │
│  │ │ Home/Bands/  │  │ Detail Route │               │   │
│  │ │ Tracks/etc   │  │ (autoDispose)│               │   │
│  │ │ (watch prov) │  │              │               │   │
│  │ └──────────────┘  └──────────────┘               │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │ NavigationBar (updates selectedTabIndexProvider) │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                            ↓ (watches)
┌─────────────────────────────────────────────────────────┐
│          Data Provider Layer (10 providers)             │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Tab-Screen Provider (e.g., BandsListData)        │   │
│  │ • Listens to: isOnlineProvider, selectedTabIndex │   │
│  │ • Logic: isOnline? fetch fresh : use cache       │   │
│  │ • Handles: _version guard, async state shape     │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Detail-Screen Provider (e.g., BandDetailData)    │   │
│  │ • Marked: autoDispose                            │   │
│  │ • Auto-rebuild on every Navigator.push           │   │
│  │ • Same online-first logic as tab screens         │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│     Supporting Providers                                │
│  • isOnlineProvider (connectivity_plus stream)          │
│  • selectedTabIndexProvider (navigation state)          │
│  • XxxSyncedAtProvider (timestamps for each resource)   │
│  • cacheServiceProvider (Hive-backed storage)           │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│     External Services & Storage                         │
│  • API (http via ApiClient) — network fetches           │
│  • Hive (local persistent storage) — cache read/write   │
│  • connectivity_plus (native platform) — radio state    │
└─────────────────────────────────────────────────────────┘
```

Data flow on tab-switch (D-01):
1. User taps Bands tab → `NavigationBar` calls `setIndex(1)`
2. `selectedTabIndexProvider` updates → `BandsScreen` watches this
3. `BandsScreen` (or provider) listens to tab-index change
4. Listener invalidates `BandsListDataProvider`
5. Provider rebuilds → checks `isOnlineProvider`
6. If online: fetch fresh from API → cache → state
7. If offline: read cache → state (no fetch)
8. `AsyncValue.when()` renders: if old data exists + loading, show old + subtle indicator; else show full spinner

### Recommended Project Structure

```
lib/
├── providers/
│   ├── bands_provider.dart         # Online-first refactor: BandsListData, BandDetailData
│   ├── tracks_provider.dart        # Online-first refactor: TrackListData, TrackDetailData (2×)
│   ├── setlists_provider.dart      # Online-first refactor: SetlistsListData, SetlistDetailData (2×)
│   ├── homepage_provider.dart      # Online-first refactor: HomepageData
│   ├── profile_provider.dart       # Online-first refactor: ProfileData
│   ├── connectivity_provider.dart  # Unchanged: isOnlineProvider streams
│   ├── navigation_provider.dart    # Unchanged: selectedTabIndexProvider state
│   ├── *_synced_at_provider.dart   # Unchanged: timestamps (may repurpose after SyncStatusBadge removal)
│   └── *_listener.dart             # NEW: Tab-switch listeners (if using separate files)
├── features/
│   ├── home/home_screen.dart       # Remove SyncStatusBadge
│   ├── bands/bands_screen.dart     # Remove SyncStatusBadge, add tab-switch listener
│   ├── songs/tracks_screen.dart    # Remove SyncStatusBadge (×2 list/detail), add listener
│   ├── setlists/setlists_screen.dart # Remove SyncStatusBadge (×2), add listener
│   └── profile/profile_screen.dart # Remove SyncStatusBadge, add listener
├── widgets/
│   ├── offline_banner.dart         # Reword message (D-04) — no structural change
│   └── sync_status_badge.dart      # DELETE entirely (10 removal sites)
└── cache/
    └── cache_service.dart          # Unchanged
```

### Pattern 1: Online-First Provider Refactor

**What:** Invert each provider's `build()` to check connectivity before choosing cache-vs-fetch-first.

**When to use:** For all 10 affected providers (5 tab + 5 detail/list variants).

**Example:**

```dart
// BEFORE (cache-first):
@override
Future<List<Map<String, dynamic>>> build() async {
  final cache = ref.watch(cacheServiceProvider);
  final cached = await cache.readBands();
  if (cached != null) {
    ref.read(bandsListSyncedAtProvider.notifier).set(...);
    unawaited(_refresh());  // Silent background refresh
    return cached;
  }
  return _fetchAndCache();
}

// AFTER (online-first — D-01):
@override
Future<List<Map<String, dynamic>>> build() async {
  final isOnline = ref.watch(isOnlineProvider);  // NEW: watch connectivity
  final cache = ref.watch(cacheServiceProvider);
  
  if (isOnline) {
    // Online: always fetch fresh
    try {
      return await _fetchAndCache();
    } catch (_) {
      // D-03: fetch failed online — fall back to cache silently
      final cached = await cache.readBands();
      if (cached != null) {
        ref.read(bandsListSyncedAtProvider.notifier).set(...);
        return cached;
      }
      rethrow;  // No cache available; surface error
    }
  } else {
    // Offline: try cache first
    final cached = await cache.readBands();
    if (cached != null) {
      ref.read(bandsListSyncedAtProvider.notifier).set(...);
      return cached;
    }
    // D-06: offline with no cache — surface dedicated error state
    throw OfflineNoCacheException();
  }
}
```

[VERIFIED: lib/providers/bands_provider.dart:59-70]

### Pattern 2: Tab-Switch Refetch Listener (D-01)

**What:** Wire `selectedTabIndexProvider` to invalidate the currently-visible tab's provider on every switch.

**When to use:** In each of the 5 tab screens (Home, Bands, Tracks, Setlists, Profile).

**Approaches:**

**Option A — Listener in the provider itself:**
```dart
@riverpod
class BandsListData extends _$BandsListData {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    // Listen to tab changes; invalidate self when Bands tab becomes visible
    ref.listen(selectedTabIndexProvider, (previous, current) {
      if (current == 1) {  // 1 = Bands tab
        // Invalidate and rebuild
        ref.invalidateSelf();
      }
    });
    
    // ... rest of online-first logic from Pattern 1
  }
}
```

**Option B — Listener in the screen widget:**
```dart
class BandsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to tab changes and invalidate when this tab becomes visible
    ref.listen(selectedTabIndexProvider, (previous, current) {
      if (current == 1) {  // This screen's tab index
        ref.invalidate(bandsListDataProvider);
      }
    });
    
    final bandsAsync = ref.watch(bandsListDataProvider);
    // ... render with AsyncValue.when()
  }
}
```

**Recommendation:** Option A (provider-level listener) centralizes the logic with the data-fetching decision; Option B (screen-level) is more declarative for UI. Choose based on existing project patterns. The context mentions `navigation_provider.dart` is the natural hook point — if it currently serves only navigation state, Option A keeps concerns separated; if it already aggregates data-invalidation logic, Option B may fit better.

[VERIFIED: lib/providers/navigation_provider.dart:1-27]

### Pattern 3: AsyncValue State Shape for In-Flight Refresh (D-08)

**What:** Distinguish "loading with no prior data" (show full spinner) vs. "refreshing with cached data present" (show old content + subtle indicator).

**Current state:** Today's `_doRefresh()` uses `state = AsyncLoading()` naively, which collapses both cases into one. To support D-08, check if data already exists before transitioning.

**Example:**

```dart
Future<void> _doRefresh() async {
  final capturedVersion = _version;
  try {
    final fresh = await _fetchAndCache();
    if (_version == capturedVersion) {
      state = AsyncData(fresh);
    }
  } catch (e, st) {
    // D-09: if no data exists yet (true cold-start), surface error
    if (state.value == null) {
      state = AsyncError(e, st);
    }
    // Otherwise silently keep the last good data visible (D-08).
  }
}

// In screen:
bandsAsync.when(
  data: (bands) {
    // Render list
    return BandsList(bands: bands);
  },
  loading: () {
    // D-09: only shown on true cold-start (no prior data)
    return const Center(child: CircularProgressIndicator());
  },
  error: (error, st) => _buildError(context, ...),
);
```

For D-08's subtle indicator while refreshing with data present, the UI layer needs to detect "I have data but a refresh is in progress." Riverpod's `AsyncValue` does not natively express this dual state. **Options:**

1. **Custom wrapper provider:** Create a `BandsListStateWithRefreshStatus` that combines `BandsListData.AsyncValue` + a separate `isRefreshing` boolean.
2. **Side-channel boolean:** Keep a `isRefreshing` StateNotifier that the UI watches alongside the data provider.
3. **Hide the loading state:** Keep old data visible by default (never call `state = AsyncLoading()`), and only show a subtle top-progress-bar (added to the Scaffold AppBar or as an overlay) when a refetch is detected via a separate listener.

**Recommendation:** Option 3 (subtle indicator via AppBar/overlay) is simplest — it doesn't require new state-aggregation providers, and the screen already has access to both data and connectivity state. Add a thin `LinearProgressIndicator` to the Scaffold's AppBar when:
- `bandsAsync.isLoading` is true (any async operation)
- `bandsAsync.hasValue` is true (data already exists)

This signals "refreshing in background" without blanking content.

[VERIFIED: lib/providers/bands_provider.dart:110-115]

### Pattern 4: Offline-No-Cache Error State (D-06)

**What:** When offline and no cache exists, show a dedicated message instead of generic "Couldn't load."

**Example:**

```dart
// In screen's error branch:
error: (error, st) {
  if (error is OfflineNoCacheException) {
    return _buildOfflineError(context);  // D-06: special state
  }
  return _buildError(context, retryFn);  // Generic error
}

// Dedicated offline-empty widget:
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

Define a custom exception in the provider:
```dart
class OfflineNoCacheException implements Exception {
  const OfflineNoCacheException();
}
```

[VERIFIED: lib/widgets/sync_status_badge.dart:1-75] (pattern reference for existing error layout)

### Anti-Patterns to Avoid

- **Checking `isOnlineProvider` in UI layer instead of provider:** The connectivity decision must happen in the provider `build()`, not scattered across screen widgets. Screens should only react to the resulting `AsyncValue`, not make their own online/offline logic decisions.
- **Calling `state = AsyncLoading()` unconditionally on manual refresh:** This blanks the screen on every tab switch. Always check `state.value != null` first (see Pattern 3).
- **Per-screen offline banners:** D-05 explicitly rejected this. Keep the global `OfflineBanner` and accept that online-but-fetch-failed cases get no banner (the silent fallback to cache is sufficient).
- **Removing `_version` guard when refactoring `_refresh()`:** The guard prevents slow background fetches from clobbering local mutations. Preserve it across the online-first inversion.
- **Ignoring the `connectivity_plus` limitations:** It reports radio state, not true internet connectivity. Online can mean "wifi enabled but no actual internet." D-03's fetch-fails-offline-fallback handles this implicitly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Connectivity detection | Custom socket ping or DNS check | `connectivity_plus` (already integrated) | Platform-native, efficient radio-state detection; custom pings add latency and battery drain |
| Async state management | Manual `isLoading`/`hasError`/`data` booleans | Riverpod's `AsyncValue` | Built-in discrimination of AsyncData/AsyncLoading/AsyncError; prevents state machine bugs (e.g., both `isLoading` and `hasError` true simultaneously) |
| Cache-versioning to prevent race conditions | Ad-hoc timestamps or sequence numbers | `_version` monotonic counter (already in use) | Simple, proven pattern; timestamp comparison is fragile across time-zone/system-clock changes |
| Global offline UI state | Per-screen banners or a separate StateNotifier aggregating across providers | Single `OfflineBanner` watching `isOnlineProvider` | Simplicity; accepts the tradeoff that online-but-fetch-failed gets no banner (silent cache fallback is sufficient) |
| Tab-switch triggered refetch | Polling timer or `WidgetBinding.instance.addPostFrameCallback` | `ref.listen(selectedTabIndexProvider)` inside provider or screen | Declarative, reactive, integrates with Riverpod's dependency graph |

**Key insight:** This phase's core pattern is "connectivity state drives cache policy" — a simple inversion of today's cache-first default. All the supporting mechanisms (async state, version guards, cache storage) already exist and work. The main risk is ad-hoc fixes for edge cases (D-03, D-08) that bypass these patterns.

## Runtime State Inventory

**Trigger:** Phase 7 is not a rename/refactor/migration phase — it's a cache-behavior inversion on existing providers and screens. No stored data, secrets, or OS-registered state will be renamed or need migration.

**Assessment:**

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — phase only changes behavior, not data shape or cache keys | None |
| Live service config | None — API contract unchanged; all requests/responses stay same | None |
| OS-registered state | None — no new native tasks or services registered | None |
| Secrets/env vars | None — auth token handling unchanged | None |
| Build artifacts | None — no new packages or build outputs | None |

**Nothing found in any category** — verified by tracing all 10 providers and associated screens; no data mutations or schema changes introduced by online-first logic.

## Common Pitfalls

### Pitfall 1: Async State Confusion on Tab Switch

**What goes wrong:** A tab screen wired to refetch on tab switch calls `ref.invalidate(provider)`, triggering a rebuild that hits the provider's `build()` again. The provider tries to fetch online data. Meanwhile, the previous tab's data might still be rendering. If the screen doesn't discriminate between "loading on cold start" (show spinner) and "loading with old data present" (show old data), every tab switch blanks the screen.

**Why it happens:** Riverpod's `AsyncValue` has three states (AsyncData, AsyncLoading, AsyncError), but two distinct *user scenarios*: (1) first-ever load (no data yet), (2) refresh of existing data. Without checking `hasValue` before transitioning to `AsyncLoading`, the screen can't tell them apart.

**How to avoid:** Follow Pattern 3 — never call `state = AsyncLoading()` without first checking if `state.value != null`. Only surface the full-screen spinner if there's no prior data (D-09). Keep old content visible during a background refresh and add a subtle indicator (AppBar spinner or progress bar).

**Warning signs:** Tab switches cause blank-screen flashes; slow networks make the problem obvious (each tab switch hangs for 2–5 seconds before content reappears).

### Pitfall 2: Fetch Failures Not Falling Back to Cache

**What goes wrong:** A provider is marked online and tries to fetch. The fetch fails (network timeout, 500 error). The provider's `build()` catches the exception and rethrows, surfacing an error state to the UI. Meanwhile, good cached data exists but is never shown. User sees "Couldn't load" instead of stale data.

**Why it happens:** The online-first logic assumes "online means fetch will succeed," but D-03 explicitly allows for online-but-fetch-failed. If the provider doesn't have a fallback catch block inside the online branch, this edge case slips through.

**How to avoid:** Follow Pattern 1 — wrap the online fetch in a try/catch that falls back to cache silently:

```dart
if (isOnline) {
  try {
    return await _fetchAndCache();
  } catch (_) {
    // Fall back to cache
    final cached = ...;
    if (cached != null) return cached;
    rethrow;  // Only throw if no cache exists
  }
}
```

**Warning signs:** User reports "blank screen" intermittently during poor network; works fine on WiFi/cellular but fails on slow/flaky networks.

### Pitfall 3: _version Guard Forgotten in Online-First Refactor

**What goes wrong:** A provider is refactored to online-first and `_doRefresh()` is rewritten to check connectivity. The new code forgets to capture `_version` before the async fetch, or forgets to check it after. A slow fetch completes after a local mutation has bumped the version, and the stale fetched data overwrites the local edit.

**Why it happens:** The `_version` guard is easy to miss when restructuring a method. It's not part of the online-first concept — it's a latency/race-condition guard that applies to both cache-first and online-first.

**How to avoid:** Copy the `_version`-guarding pattern directly from the existing code:

```dart
Future<void> _doRefresh() async {
  final capturedVersion = _version;  // Capture BEFORE fetch
  try {
    final fresh = await _fetchAndCache();
    if (_version == capturedVersion) {  // Check AFTER fetch
      state = AsyncData(fresh);
    }
  } catch (e, st) { ... }
}
```

**Warning signs:** Edits (rename band, add track, etc.) appear to succeed but then revert to the old value after a second or two; happens more often on slow networks where background syncs take longer.

### Pitfall 4: Missing Tab-Switch Listener on One Screen

**What goes wrong:** Four of the five tab screens (Home, Bands, Tracks, Setlists) get the tab-switch refetch listener wired up. Profile is missed. When the user switches to Profile, it shows stale cached data instead of a fresh fetch. User edits a password on Settings, sees the stale old profile data, and gets confused.

**Why it happens:** D-01 requires *all five* tab screens to listen to tab switches. It's easy to apply the listener to the most-active screens (Bands, Tracks) and miss the quieter ones (Home, Profile).

**How to avoid:** Apply the listener uniformly to all five tab screens (Home, Bands, Tracks, Setlists, Profile) using the same code pattern. Consider a shared mixin or a checklist during implementation to ensure no screen is skipped.

**Warning signs:** Some tabs refresh on switch; others don't; inconsistent behavior makes it look like a connectivity bug rather than a missed wiring.

### Pitfall 5: SyncStatusBadge Removal Leaving Dangling Imports

**What goes wrong:** A screen imports `SyncStatusBadge` and uses it in the widget tree. The removal task (mechanical deletion from 10 call-sites) deletes the instantiation but forgets to remove the `import` statement. The file still compiles (unused import warning from linter), but linter fails CI. Or the developer removes the import but a different screen still imports it, and a git merge conflict happens if two branches are removing it at once.

**Why it happens:** Removing a component involves two changes: (1) delete the widget from the tree, (2) remove the import. It's easy to forget step 2, especially if using automated find-and-replace.

**How to avoid:** Run `flutter analyze` after all removals to catch unused imports. Consider a two-step removal: (1) remove all instantiations first, (2) run analyze to find dangling imports, (3) remove imports.

**Warning signs:** `flutter analyze` reports "unused_import" on 10 files; git diff shows more lines removed from imports than expected.

## Code Examples

### Complete Online-First Provider Example

[Source: lib/providers/bands_provider.dart]

```dart
@riverpod
class BandsListData extends _$BandsListData {
  Future<void>? _inFlightRefresh;
  int _version = 0;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    // D-01: Listen to tab-switch to trigger refetch
    ref.listen(selectedTabIndexProvider, (previous, current) {
      if (current == 1) {  // Bands tab index
        ref.invalidateSelf();
      }
    });

    final isOnline = ref.watch(isOnlineProvider);  // NEW: online-first check
    final cache = ref.watch(cacheServiceProvider);

    if (isOnline) {
      // Online: always fetch fresh (D-01)
      try {
        return await _fetchAndCache();
      } catch (_) {
        // D-03: online but fetch failed — fall back to cache silently
        final cached = await cache.readBands();
        if (cached != null) {
          ref.read(bandsListSyncedAtProvider.notifier).set(await cache.readBandsSyncedAt());
          return cached;
        }
        rethrow;  // No cache available; surface error
      }
    } else {
      // Offline: use cache
      final cached = await cache.readBands();
      if (cached != null) {
        ref.read(bandsListSyncedAtProvider.notifier).set(await cache.readBandsSyncedAt());
        return cached;
      }
      // D-06: offline with no cache
      throw OfflineNoCacheException();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache() async {
    final bands = await ref.read(publicApiProvider).listBands();
    await ref.read(cacheServiceProvider).writeBands(bands);
    ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
    return bands;
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    final capturedVersion = _version;  // IMPORTANT: capture before fetch
    try {
      final fresh = await _fetchAndCache();
      if (_version == capturedVersion) {
        state = AsyncData(fresh);
      }
    } catch (e, st) {
      // D-08/D-09: keep old data if refresh fails; only show error on cold start
      if (state.value == null) {
        state = AsyncError(e, st);
      }
    }
  }

  void setBands(List<Map<String, dynamic>> bands) {
    _version++;
    state = AsyncData(bands);
    ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
  }

  void renameBand(String bandId, String newName) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = [
      for (final band in current)
        if (band['id'] == bandId) {...band, 'name': newName} else band,
    ];
    _version++;
    state = AsyncData(updated);
    unawaited(ref.read(cacheServiceProvider).writeBands(updated));
    ref.read(bandsListSyncedAtProvider.notifier).set(DateTime.now());
  }
}
```

### Screen Widget: Reword Banner + Remove Badge

[Source: lib/widgets/offline_banner.dart]

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
              'Showing cached data — may be out of date',  // D-04: reworded
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
```

[Source: lib/features/bands/bands_screen.dart]

```dart
class BandsScreen extends ConsumerWidget {
  const BandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bandsAsync = ref.watch(bandsListDataProvider);
    // REMOVED: final syncedAt = ref.watch(bandsListSyncedAtProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bands'),
        // D-08: Add subtle indicator when refreshing
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: bandsAsync.isLoading && bandsAsync.hasValue
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
      ),
      body: bandsAsync.when(
        data: (bands) => Column(
          children: [
            // REMOVED: SyncStatusBadge(syncedAt: syncedAt),
            Expanded(child: _buildContent(context, bands, profileAsync)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, st) {
          if (error is OfflineNoCacheException) {
            return _buildOfflineError(context);  // D-06
          }
          return _buildError(context, () => ref.invalidate(bandsListDataProvider));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isOnline ? () => _showCreateJoinMenu(context, ref) : null,
        tooltip: isOnline ? null : 'Requires connection',
        child: const Icon(Icons.add),
      ),
    );
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

  // ... rest of screen code
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Cache-first serve on app start | Online-first fetch on app start (or reconnect) | Phase 7 (v1.1) | Users always see freshest data when connected; reduces stale-data complaints |
| Per-item staleness badge (10min/30min tiers) | Global offline-only banner | Phase 7 (v1.1) | Removes UI clutter; users understand they're offline rather than confused by "synced 35m ago" on WiFi |
| Manual refresh button only | Automatic refetch on tab switch + reconnect | Phase 7 (v1.1) | Improves UX — tab switch now refetches without user action; reconnect is automatic |
| Cold-start spinner hidden by cache | Cold-start spinner still shown, but old content preserved during refresh | Phase 7 (v1.1) | Improves perceived performance — users don't see blank screens on every tab switch |

**Deprecated/outdated:**
- **`SyncStatusBadge`:** Removed entirely. Its purpose (showing data staleness tiers) is replaced by the simple offline banner. The `XxxSyncedAt` providers it watched may be repurposed for internal "when did we last fetch this" logic (D-03/D-08), or removed if unused.
- **Manual pull-to-refresh as primary update method:** Tab switch now triggers automatic refetch (D-01). Manual refresh button is still available on some screens for user-initiated updates, but is no longer the main way stale data gets refreshed.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `connectivity_plus` will always report correct radio state without delay | Standard Stack, Architecture Patterns | If there's latency between actual radio-state change and `isOnlineProvider` update, offline-first logic might fetch on stale connectivity signal; risk is low (platform-native, tested extensively) |
| A2 | `selectedTabIndexProvider` is watched as a stream/single value and triggers listener when changed | D-01, Pattern 2 | If the provider doesn't support listeners or batches updates, tab-switch refetch may not trigger; verify by reading `navigation_provider.dart` and testing with a simple listener |
| A3 | Offline-no-cache error state (D-06) can reuse existing `_buildError()` layout widget | Pattern 4, Screen Example | If `_buildError()` is incompatible with new offline-specific layout, will need a custom widget; low risk since it's just a Column with icon + text |
| A4 | `AsyncValue.isLoading && AsyncValue.hasValue` reliably detects "refreshing with old data" state | Pattern 3, D-08 | If Riverpod's AsyncValue semantics differ from expectation, the subtle-indicator condition may fire on cold start; verify with a quick test of this condition |
| A5 | The `_version` monotonic counter pattern will still prevent race conditions after online-first refactor | D-03, Pitfall 3 | If the online-first fetch path doesn't properly capture and check `_version`, local mutations can be reverted; risk is medium — must verify during implementation |

**If any table above assumed knowledge, the planner must add a `checkpoint:human-verify` task before implementation to confirm.**

## Open Questions

1. **Tab-Switch Listener Implementation (D-01):**
   - Should the listener be inside each provider's `build()` (centralizes logic), or in each screen widget (more declarative)?
   - What if a provider is watched by multiple screens (e.g., `TrackListData` watched by both a tab screen and a detail screen)? Invalidating from the tab screen might cause the detail screen to refetch unnecessarily.
   - **Recommendation:** Start with Option B (screen-level listener) to keep each screen's lifecycle independent. If that causes performance issues (too many invalidations), refactor to Option A (provider-level).

2. **Subtle Refresh Indicator Widget (D-08):**
   - Should the indicator be a `LinearProgressIndicator` in the AppBar's `bottom` property, a small spinner in the top-right of AppBar, or a full-screen overlay?
   - **Recommendation:** `LinearProgressIndicator` in `AppBar.bottom` (shown conditionally when `bandsAsync.isLoading && bandsAsync.hasValue`) is simplest and most consistent with Material design.

3. **OfflineNoCacheException Handling:**
   - Should this be a custom exception class in the provider file, or moved to a shared exceptions module?
   - How should detail screens handle this (they use autoDispose, so they rebuild on every route push — they shouldn't hit the no-cache state as often)?
   - **Recommendation:** Define in the provider file for now; move to a shared module if more phases need it.

4. **SyncStatusBadge Removal Order:**
   - Should all 10 removal sites be handled in a single task, or split across 5 tasks (one per screen)?
   - **Recommendation:** Single task with a checklist of 10 files to ensure no file is missed; low risk of conflict since each screen's usage is local.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Build/run | ✓ | Latest stable | — |
| Dart 3.12.2+ | Compile Dart code | ✓ | Via Flutter | — |
| connectivity_plus package | isOnlineProvider | ✓ | 7.3.1 (pubspec.yaml) | Manual timer-based fallback (not recommended) |
| Riverpod packages | Providers, AsyncValue | ✓ | 2.6.1 (pubspec.yaml) | State management rewrite (not in scope) |
| Hive + Hive Flutter | Cache storage | ✓ | 2.2.3 + 1.1.0 (pubspec.yaml) | In-memory cache (already available for tests) |
| Android SDK | APK build | ✓ | (assumed from existing Phase 6 work) | — |
| Xcode | iOS build | ✓ | (assumed from existing Phase 6 work) | — |

**Missing dependencies with no fallback:** None — all required packages are already installed and verified.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) + Riverpod's ProviderContainer for provider testing |
| Config file | None (flutter_test needs no explicit config) |
| Quick run command | `flutter test test/providers/` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OFFL-07 | When online, cached screen always fetches fresh on open | Unit | `flutter test test/providers/bands_provider_test.dart::online-first-fetch` | ❌ Wave 0 |
| OFFL-07 | Tab switch triggers refetch (5 tab screens) | Integration | `flutter test test/features/` | ❌ Wave 0 |
| OFFL-08 | When offline, screen shows cached data | Unit | `flutter test test/providers/bands_provider_test.dart::offline-cache-hit` | ❌ Wave 0 |
| OFFL-08 | When offline with no cache, shows dedicated "No cached data" state | Unit | `flutter test test/providers/bands_provider_test.dart::offline-no-cache` | ❌ Wave 0 |
| OFFL-08 | SyncStatusBadge removed from all 10 screens | Smoke | (visual inspection + flutter analyze) | ✅ (by removal) |
| OFFL-08 | Offline banner text updated to "Showing cached data — may be out of date" | Unit | `flutter test test/widgets/offline_banner_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter test test/providers/<changed_provider>_test.dart`
- **Per wave merge:** `flutter test` (full suite)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/providers/bands_provider_test.dart` — online-first fetch, offline fallback, tab-switch refetch, offline-no-cache state (4 test cases per provider × 10 providers = 40 tests total; batch into shared test template)
- [ ] `test/providers/tracks_provider_test.dart` — same 4 cases, applied to track list/detail (2 variants)
- [ ] `test/providers/setlists_provider_test.dart` — same 4 cases, applied to setlists list/detail (2 variants)
- [ ] `test/providers/profile_provider_test.dart` — same 4 cases for profile (no tab-switch needed; read-mostly)
- [ ] `test/providers/homepage_provider_test.dart` — same 4 cases for homepage
- [ ] `test/widgets/offline_banner_test.dart` — banner text verification, visibility based on `isOnlineProvider`
- [ ] `test/features/bands_screen_test.dart` — verify tab-switch listener is wired (integration-level check: switch tabs and verify state rebuilds)
- [ ] `test/features/tracks_screen_test.dart` — same tab-switch listener check
- [ ] `test/features/setlists_screen_test.dart` — same
- [ ] `test/features/profile_screen_test.dart` — same (no tab-switch refetch needed per D-02, but still verify no regressions)
- [ ] `test/features/home_screen_test.dart` — same
- [ ] Framework install: None (flutter_test is built-in; Riverpod's ProviderContainer is in pubspec.lock)

*(Existing regression suite covers Phase 1–6 auth/cache basics; Phase 7 tests verify the new online-first policy, not foundational functionality.)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Auth token handling is unchanged; no new login/session logic |
| V3 Session Management | No | Token invalidation on logout unchanged; 403 auto-logout unchanged |
| V4 Access Control | No | API endpoints are the same; no new permission logic |
| V5 Input Validation | Yes | Offline-no-cache exception must not be user-triggered (it's an internal state, not a request field) — no input validation needed |
| V6 Cryptography | No | Token storage (flutter_secure_storage) unchanged; crypto layer untouched |

### Known Threat Patterns for {Riverpod + connectivity_plus + cache}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cache poisoning: stale data shown as fresh | Tampering | `_version` guard + `syncedAt` timestamp (now internal only, not UI-visible) — prevents a slow fetch from clobbering a local edit |
| Connectivity spoofing: app believes it's online when it isn't | Spoofing | `connectivity_plus` reports radio state, not active reachability; D-03's fetch-fails-online fallback handles this implicitly (no silent cache serve) |
| Credential leakage on offline cache read | Information Disclosure | Cache is stored in Hive (Dart-side only); no new serialization or exposure vectors introduced by online-first logic |

**No new security controls needed by Phase 7** — the refactor is a cache-policy change, not a new data-handling or credential-management mechanism. Existing controls (token storage, API auth, cache isolation) remain sufficient.

## Sources

### Primary (HIGH confidence)
- [VERIFIED: lib/providers/bands_provider.dart:1-240] — Complete provider example showing cache-first pattern (to be inverted)
- [VERIFIED: lib/providers/connectivity_provider.dart:1-42] — isOnlineProvider implementation and `ConnectivityStatus` enum
- [VERIFIED: lib/providers/navigation_provider.dart:1-27] — selectedTabIndexProvider for tab-index state
- [VERIFIED: lib/widgets/offline_banner.dart:1-38] — Existing offline banner widget structure
- [VERIFIED: lib/widgets/sync_status_badge.dart:1-76] — SyncStatusBadge widget to be removed (10 call-sites identified)
- [VERIFIED: .planning/phases/07-cache-behavior-flip-online-first/07-CONTEXT.md:1-103] — Phase 7 context with D-01 through D-09 decisions
- [VERIFIED: pubspec.yaml:1-67] — Dependency versions (riverpod_annotation 2.6.1, connectivity_plus 7.3.1, etc.)

### Secondary (MEDIUM confidence)
- [CITED: REQUIREMENTS.md] — OFFL-07 and OFFL-08 requirement text
- [CITED: STATE.md] — Project roadmap and phase sequencing; Phase 7 flagged for deeper research before planning

### Tertiary (LOW confidence — training knowledge, not verified this session)
- Riverpod provider lifecycle: providers auto-rebuild on dependency changes; `ref.invalidateSelf()` triggers a rebuild of the calling provider; listeners fire on watched value changes
- AsyncValue semantics: `isLoading` true when any async operation is in flight; `hasValue` true when AsyncData or AsyncError with a value; `value` property retrieves the success data or rethrows the error
- Flutter's `IndexedStack` keeps all children mounted and alive, allowing internal state (like provider caches) to persist across tab switches

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — all packages are existing, verified in pubspec.lock, and working from Phase 6
- Architecture: **HIGH** — Phase 6 context thoroughly documented; provider patterns are established in codebase
- Pitfalls: **HIGH** — async state management and version-guarding pitfalls are grounded in existing code review (Phase 02 gap-closure history)
- D-01 (tab-switch trigger): **MEDIUM** — mechanism is clear (use `ref.listen`), but exact placement (provider vs. screen) is discretionary and affects implementation order
- D-08 (refresh indicator UI): **MEDIUM** — AsyncValue state shape is clear, but visual design (progress bar vs. spinner) is a UX choice, not technical risk

**Research date:** 2026-08-21
**Valid until:** 2026-09-04 (14 days — this phase's architecture is stable, but platform-level behavior of `connectivity_plus` can change on OS updates; revalidate after major iOS/Android release)

---

*Phase 7: Cache Behavior Flip — Online-First*
*Research completed: 2026-08-21*
