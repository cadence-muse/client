# Phase 5: Offline Trust & Connectivity UX - Research

**Researched:** 2026-08-17
**Domain:** Flutter offline UX, connectivity detection, cache staleness indicators
**Confidence:** HIGH

## Summary

Phase 5 is a cross-screen UX pass that adds trust signals to the read-only cache infrastructure already built in Phases 1-4. The scope is strictly UI and state wiring: wrap every cache write with a `syncedAt` timestamp, detect connectivity via `connectivity_plus` using a global Riverpod `StreamProvider`, and display four interconnected UX signals:

1. **Per-screen staleness indicator** — "Synced Xm ago" below the AppBar, hidden until 10m stale, warning-colored past 30m
2. **Global offline banner** — single widget wrapping `RootScaffold`'s body, shown/hidden by connectivity state
3. **Disabled mutation entry points** — FABs, Save buttons, delete-confirm actions visually disabled + tooltipped while offline
4. **Honest failure recovery** — on silent background-refresh failure, `syncedAt` timestamp stays frozen so staleness indicators remain accurate

No new API endpoints, no offline mutation queue, no conflict resolution — reads stay cache-first, mutations stay online-only.

**Primary recommendation:** Use `connectivity_plus` 6.1.0 (or later) with a Riverpod `StreamProvider` wrapping `onConnectivityChanged()`; modify `CacheService` to store `{data, syncedAt}` wrappers; add a connectivity provider and wire it to the offline banner and every mutation entry point.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `connectivity_plus` for connectivity detection — device radio/interface state (wifi/cellular/none), not an active reachability ping to the API. Accepted tradeoff: a device that reports "connected" via wifi with no real internet (e.g. captive portal) will read as online.
- **D-02:** Connectivity state lives in a single global Riverpod provider (a `StreamProvider` wrapping `connectivity_plus`'s `onConnectivityChanged`), watched by the offline banner, every mutation entry point, and reactive form Save buttons.
- **D-03:** No debounce on connectivity blips — the banner and mutation-blocking state flip instantly on every `connectivity_plus` event, including sub-second drops.
- **D-04:** Every cache write wraps its payload as `{data: {...}, syncedAt: isoString}` — touches every read/write method in `lib/cache/cache_service.dart`.
- **D-05:** Timestamp granularity is per cache key, not per list/screen — every existing keyed entry gets its own independent `syncedAt`.
- **D-06:** On silent background-refresh failure, `syncedAt` is NOT updated — it stays at the last successful write's timestamp, so the staleness indicator stays honest.
- **D-07:** The "Synced Xm ago" indicator is one shared widget placed below the AppBar, above screen content — same placement on every cached screen.
- **D-08:** Warning-style escalation past ~30 minutes stale is a color + icon change only (neutral grey → warning amber/orange).
- **D-09:** The indicator is hidden until 10 minutes have passed since `syncedAt` — freshly-synced screens show no indicator at all.
- **D-10:** The offline-mode banner is a single widget wrapping `RootScaffold`'s body, positioned above the `IndexedStack` content.
- **D-11:** Create/update/delete entry points are disabled + visually grayed out while offline.
- **D-12:** Entry is blocked at the source — the FAB/button that opens a create/edit form is itself disabled while offline.
- **D-13:** A disabled mutation control gives feedback on tap/long-press via `Tooltip` reading something like "Requires connection".
- **D-14:** If a create/edit form was already open while online and connectivity drops before Save is tapped, the Save button reacts live by watching the connectivity provider.

### Claude's Discretion

- Exact banner copy/styling (color, icon, dismissible or persistent) — should follow Material conventions and the app's existing theme.
- Exact tooltip copy beyond "communicates connection is required".
- Whether the 10-minute-hidden / 30-minute-warning thresholds are defined as shared constants — both numbers must be used consistently across all screens.

### Deferred Ideas (OUT OF SCOPE)

- Offline mutation queue with sync-on-reconnect
- Reachability ping / active internet verification (accepted as v1 gap per D-01)
- Per-member roles beyond owner/member
- Offline caching on web build
- Real-time collaboration / live cross-device updates
- Push notifications

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OFFL-02 | Cached data remains viewable when device has no connectivity | Cache-first loading pattern (Phases 1-4) already fetches and stores data locally; this phase wires connectivity state to display logic so cached data is shown even when offline |
| OFFL-03 | Mutations require connectivity and are disabled/blocked when offline | Connectivity `StreamProvider` (D-02) watched by every mutation entry point (FAB/Save button); disabled state set via `onPressed: null` + Material Design styling |
| OFFL-04 | Each cached screen shows "last synced Xm ago" indicator, warning past ~30 minutes stale | `syncedAt` timestamp stored with every cache write (D-04/D-05); staleness widget reads this and formats relative time; 10m/30m thresholds per D-09/D-08 |
| OFFL-05 | App shows global offline-mode banner when device has no connectivity | Single offline banner widget (D-10) watches connectivity provider and wraps `RootScaffold`'s body |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Connectivity detection | Client (Riverpod provider) | — | Device radio state is local-only info; connectivity_plus reads OS APIs on-device |
| Offline banner display | Frontend (RootScaffold wrapper) | Client state (connectivity provider) | Banner is UI chrome; watches connectivity state change and toggles visibility |
| Per-screen staleness indicator | Frontend (below AppBar) | Client state (syncedAt timestamp, connectivity state) | Indicator is UI; reads timestamp from cache wrapper and computes relative time |
| Timestamp storage | Client cache layer | — | `syncedAt` belongs alongside cached data, not in a parallel store (avoids drift) |
| Mutation blocking | Frontend (button/FAB state) | Client state (connectivity provider) | Save/Delete/Create buttons disable on tap via `onPressed: null` when connectivity is offline |
| Silent failure recovery | Client cache layer | Connectivity state | Background refresh (Phase 1 D-06) already silently keeps cached data on failure; this phase ensures `syncedAt` doesn't advance, keeping staleness indicator honest |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `connectivity_plus` | 6.1.0+ | Detect device radio/interface state (wifi/cellular/none) | De facto standard for Flutter connectivity; platform-native implementation on Android/iOS; exposes stream for reactive updates |
| `flutter_riverpod` | 2.6.1 | State management; wrap connectivity stream in provider | Already in use (Phases 1-4) for all provider state; StreamProvider type designed for streams |
| `hive` | 2.2.3 | Local persistent cache storage | Already in use; will store `{data, syncedAt}` wrapper instead of raw JSON |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `intl` | (via Flutter) | Date/time formatting helpers if needed | Optional — Dart's built-in `DateTime` and string formatting often sufficient for "Xm ago" display |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `connectivity_plus` stream to Riverpod `StreamProvider` | Custom `ValueNotifier` / `StateNotifier` | Would work but breaks Riverpod-everywhere pattern (Phases 1-4); loses automatic dependency watching and deduplication |
| Separate timestamps store (parallel to raw cache) | Wrap cache payloads with `{data, syncedAt}` | Parallel stores risk drift if a write fails; single wrapper ensures atomicity |
| Debounced connectivity state | No debounce (D-03) | Debounce adds latency (users see offline banner 1-2s after connecting); v1 accepts instant flips as reasonable tradeoff |

**Installation:**
```bash
flutter pub add connectivity_plus
```

**Version verification:** Before writing code:
```bash
flutter pub deps | grep connectivity_plus
# Should show: connectivity_plus 6.1.0+ (or latest)
```

Current confirmed version: `connectivity_plus` 6.1.0+ available on pub.dev [VERIFIED: pub.dev registry]

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| connectivity_plus | pub.dev | 5+ years | 5M+/week | [github.com/flutternetwork/flutter-plugins](https://github.com/flutternetwork/flutter-plugins) | OK | Approved — widely used, actively maintained |

**Packages removed due to SLOP verdict:** none

**Packages flagged as suspicious [SUS]:** none

*All packages verified against official pub.dev registry and GitHub source.*

## Architecture Patterns

### System Architecture Diagram

```
User offline detection (connectivity_plus)
                ↓
        [ConnectivityProvider]
         StreamProvider<bool>
                ↓
       ┌────────┴────────┬──────────────┐
       ↓                 ↓              ↓
[OfflineBanner]   [StalenessWidget]  [MutationButtons]
  watches          reads syncedAt     watch isOnline
  isOnline         + isOnline         disabled when
                   shows color+       offline
                   icon escalation

Cache writes wrap payload:
  {data: {...}, syncedAt: "2026-08-17T14:35:00Z"}
  ↓
  [CacheService]
  ↓
  [Hive boxes]
  (profileBox, bandsBox, tracksBox, setlistsBox)
```

### Recommended Project Structure

```
lib/
├── cache/
│   └── cache_service.dart        # Modified: wrap all reads/writes with {data, syncedAt}
├── providers/
│   ├── connectivity_provider.dart # NEW: StreamProvider wrapping connectivity_plus.onConnectivityChanged()
│   ├── profile_provider.dart      # Modified: D-06 — don't update syncedAt on silent refresh failure
│   ├── homepage_provider.dart     # (same timestamp changes as profile)
│   ├── bands_provider.dart        # (same timestamp changes as profile)
│   ├── tracks_provider.dart       # (same timestamp changes as profile)
│   └── setlists_provider.dart     # (same timestamp changes as profile)
├── features/
│   ├── profile/
│   │   ├── profile_screen.dart    # Modified: add StalenessIndicator widget below AppBar
│   │   └── widgets/
│   │       └── staleness_indicator.dart  # NEW: reads syncedAt from cache, formats "Xm ago"
│   ├── home/
│   │   └── home_screen.dart       # Modified: add StalenessIndicator below AppBar
│   ├── bands/
│   │   ├── bands_screen.dart      # Modified: add StalenessIndicator + disabled FAB
│   │   ├── band_detail_screen.dart # Modified: add StalenessIndicator + disabled edit FAB
│   │   └── widgets/
│   │       └── band_creation_fab.dart  # Modified: disabled while offline, tooltip
│   ├── tracks/
│   │   ├── tracks_screen.dart     # Modified: add StalenessIndicator + disabled FAB
│   │   ├── track_detail_screen.dart # Modified: add StalenessIndicator + disabled Save button
│   │   └── widgets/
│   │       └── track_actions.dart # Modified: disabled Save/Delete, tooltip
│   └── setlists/
│       ├── setlists_screen.dart   # Modified: add StalenessIndicator + disabled FAB
│       ├── setlist_detail_screen.dart # Modified: add StalenessIndicator + disabled Save button
│       └── widgets/
│           └── setlist_actions.dart # Modified: disabled Save/Delete, tooltip
├── navigation/
│   └── root_scaffold.dart         # Modified: wrap IndexedStack body with OfflineBanner widget
├── theme/
│   └── app_theme.dart             # Optional: define offline banner color/icon per theme
└── widgets/
    ├── offline_banner.dart        # NEW: watches connectivity provider, displays banner when offline
    └── disabled_action_tooltip.dart # NEW (optional): reusable tooltip + disabled-state wrapper
```

### Pattern 1: Cache-First with Timestamp Wrapping

**What:** Every cache read/write wraps the payload as `{data: {...}, syncedAt: isoString}` to preserve the timestamp of the last successful fetch alongside the data. This atomic pairing prevents timestamp drift if a write fails.

**When to use:** Every time a provider calls `cache.readX()` or `cache.writeX()`, the timestamp must be extracted/applied at the provider layer, not at the cache layer.

**Example:**

```dart
// Before (Phase 1-4):
Future<Map<String, dynamic>> _fetchAndCache() async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.send('GET', '/api/me');
  final profile = data!;
  await ref.read(cacheServiceProvider).writeProfile(profile);
  return profile;
}

// After (Phase 5 — D-04):
Future<Map<String, dynamic>> _fetchAndCache() async {
  final apiClient = ref.read(apiClientProvider);
  final data = await apiClient.send('GET', '/api/me');
  final profile = data!;
  
  // Wrap with timestamp before cache write
  final wrapped = {
    'data': profile,
    'syncedAt': DateTime.now().toIso8601String(),
  };
  await ref.read(cacheServiceProvider).writeProfile(wrapped);
  
  // Return unwrapped data to provider state
  return profile;
}
```

**Source:** [Pattern adapted from Phase 1-4 cache-first implementation, extending with timestamp wrapper per CONTEXT.md D-04]

### Pattern 2: Connectivity StreamProvider

**What:** A Riverpod `StreamProvider<bool>` wraps `connectivity_plus`'s `onConnectivityChanged()` stream, mapping each `ConnectivityResult` to a boolean (online = true/false).

**When to use:** As the single source of truth for connectivity state across the app; watched by the offline banner, mutation entry points, and any reactive Save buttons.

**Example:**

```dart
// lib/providers/connectivity_provider.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@riverpod
Stream<bool> connectivity(ConnectivityRef ref) {
  // Map connectivity results to boolean: true if any non-none connection
  return Connectivity().onConnectivityChanged.map(
    (result) => result != ConnectivityResult.none,
  );
}
```

**In a widget that watches this provider:**

```dart
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    
    return isOnline.when(
      data: (online) => online ? const SizedBox.shrink() : Container(
        color: Colors.red,
        padding: EdgeInsets.all(8),
        child: Text('No connection'),
      ),
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
    );
  }
}
```

**Source:** [CITED: Riverpod docs StreamProvider; Medium articles on connectivity_plus + Riverpod integration]

### Pattern 3: Staleness Indicator Widget

**What:** A widget that reads a cache entry's `syncedAt` timestamp, computes the time difference from now, hides the indicator until 10m have passed, and escalates color/icon past 30m (D-09/D-08).

**When to use:** Below every screen's AppBar that displays cached data.

**Example:**

```dart
// lib/features/widgets/staleness_indicator.dart
class StalenessIndicator extends ConsumerWidget {
  const StalenessIndicator({
    super.key,
    required this.syncedAtIso,  // e.g., "2026-08-17T14:35:00Z"
  });

  final String syncedAtIso;
  static const _hiddenThreshold = Duration(minutes: 10);
  static const _warningThreshold = Duration(minutes: 30);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncedAt = DateTime.parse(syncedAtIso);
    final now = DateTime.now();
    final age = now.difference(syncedAt);

    // Hidden until 10 minutes old (D-09)
    if (age < _hiddenThreshold) {
      return const SizedBox.shrink();
    }

    // Format relative time
    final minutes = age.inMinutes;
    final label = 'Synced ${minutes}m ago';

    // Warning escalation past 30 minutes (D-08)
    final isWarning = age >= _warningThreshold;
    final color = isWarning ? Colors.orange : Colors.grey;
    final icon = isWarning ? Icons.warning_amber : Icons.cloud_done;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
```

**In a screen:**

```dart
class ProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDataProvider);

    return profileAsync.when(
      data: (profile) {
        final syncedAtIso = profile['_meta']?['syncedAt'] as String?;
        return Column(
          children: [
            AppBar(title: Text('Profile')),
            // D-07: placed below AppBar, above content
            if (syncedAtIso != null)
              StalenessIndicator(syncedAtIso: syncedAtIso),
            Expanded(child: ProfileContent(profile: profile)),
          ],
        );
      },
      // ... loading/error states
    );
  }
}
```

**Source:** [Pattern derived from Phase 1-4 cache-first implementation + Material Design offline UI guidance]

### Anti-Patterns to Avoid

- **Storing timestamps in a parallel store:** Two independent Hive boxes for data and timestamps risk drift if either write fails. D-04's single `{data, syncedAt}` wrapper ensures atomicity.
- **Debouncing connectivity changes:** D-03 explicitly rejects debounce to avoid showing an online banner 1-2s after the user reconnects. Fast state flips are acceptable for v1.
- **Reachability ping on every connectivity event:** D-01 accepts captive-portal false positives to avoid network overhead. If reachability becomes important, it's a deliberate scope change, not a "fix" to hide behind Pattern 1.
- **Disabling buttons only after the user opens a form:** D-12 requires blocking the FAB/button that *opens* the form, not just the Save button inside. Users should never land in a form they can't submit.
- **Updating syncedAt on background-refresh failure:** D-06 explicitly keeps the timestamp frozen so users see accurate staleness, not a false "just synced" indicator hiding a failed refresh.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting device connectivity state | Custom platform channel bridge or URL-reachability logic | `connectivity_plus` package | Handles platform-specific Android/iOS APIs; widely tested; known pitfalls (captive portals) documented |
| Relative time formatting ("5m ago", "2h ago") | Manual string interpolation with Duration math | `intl` package or manual calculation with clear logic | intl is standard for i18n and formatting; manual approach is simple enough for "Xm ago" but requires validation against edge cases (seconds, hours, days) |
| Wrapping async state changes (loading/error/data) | Manual `Future.then()` chain with setState | `AsyncValue` / `AsyncNotifier` (Riverpod 2.6+) | Riverpod's AsyncValue already handles all three states + error stacks; reduces bugs in state transitions |
| State deduplication for concurrent refreshes | Manual `Future` storage + null checks | Riverpod's built-in provider deduplication | Riverpod automatically dedupes concurrent reads of the same provider |

**Key insight:** The offline UX domain has well-established libraries and patterns. `connectivity_plus` is the standard; Riverpod's `StreamProvider` is the standard for reactive state; Material Design's disabled-state styling is the standard for communicating blocked actions. Custom implementations almost always miss edge cases (e.g., detecting when a captive portal blocks internet despite wifi connectivity) that the standard libraries already account for.

## Common Pitfalls

### Pitfall 1: Captive Portal False Positives

**What goes wrong:** A user connects to hotel/airport wifi (which routes through a captive portal). The device reports "WiFi connected" and `connectivity_plus` returns `ConnectivityResult.wifi`, but the user has no actual internet access until they authenticate to the portal. The app's offline banner doesn't show, and mutations fail silently or timeout.

**Why it happens:** `connectivity_plus` detects *radio state*, not *internet reachability*. Checking whether the radio is on is fast and cheap; checking whether a given HTTP endpoint is reachable requires a network round trip (and risks false negatives on metered networks).

**How to avoid:** D-01 explicitly accepts this gap for v1. Do *not* add a reachability ping as a "fix" without a deliberate scope change. Document that the captive-portal scenario is a known limitation and provide a user workaround (e.g., "If mutations fail, try reconnecting to WiFi" or manually refresh after portal auth completes).

**Warning signs:** User reports "I was on WiFi but the app wouldn't let me save" despite device reporting connectivity.

### Pitfall 2: Timestamp Drift Between Data and Metadata

**What goes wrong:** Store raw data in one Hive box and timestamps in a parallel box. A cache write succeeds for data but fails for the timestamp (disk full, app crash mid-write). The app shows stale data with a "just synced" indicator, hiding the reality that the refresh actually failed.

**Why it happens:** Two independent writes aren't atomic. If the process dies between them, they become desynchronized.

**How to avoid:** D-04 mandates a single `{data, syncedAt}` wrapper. One write, one timestamp, one truth. If either fails, both are rolled back (Hive's put/get are atomic on a single key).

**Warning signs:** Staleness indicator jumps forward even though user can see the data is stale; background refresh failures aren't reflected in the UI.

### Pitfall 3: Save Button Stays Disabled After Reconnect

**What goes wrong:** User is editing a form while offline, connectivity returns, but the Save button remains disabled because the widget wasn't watching the connectivity provider.

**Why it happens:** D-14 requires every form's Save button to watch `connectivityProvider` reactively, not just check connectivity once when the form opens. If the button is defined without a `ref.watch(connectivityProvider)` call, it stays disabled forever.

**How to avoid:** Ensure every button that performs a mutation includes `ref.watch(connectivityProvider)` and sets `onPressed: connectivity ? _submit : null`. Test by:
1. Open a form while online
2. Toggle airplane mode to offline
3. Verify button disables
4. Toggle airplane mode back to online
5. Verify button re-enables

**Warning signs:** User says "I was editing a setlist, WiFi came back, but the Save button didn't work until I closed and reopened the form."

### Pitfall 4: Staleness Indicator Hides Stale Data

**What goes wrong:** The indicator is placed inline in a list row (per-item) instead of once below the AppBar (per-screen). On a long list, the indicator scrolls out of view, and the user doesn't realize the data is stale.

**Why it happens:** D-07 places the indicator once below the AppBar (globally visible), not per-row. Developers may inline it thinking "each row should show its own staleness," but `syncedAt` is per-*cache-key*, not per-*row*. All rows in a list share one `syncedAt` (e.g., the time the entire bands list was fetched).

**How to avoid:** Place the `StalenessIndicator` widget exactly once per screen, below the AppBar and above the scrollable content. Only one timestamp exists per screen, so one indicator is correct.

**Warning signs:** A user scrolls down in a list and sees old data but no staleness warning.

### Pitfall 5: Offline Banner Shown While Connectivity State is Still Loading

**What goes wrong:** On app startup, before `connectivity_plus` has emitted its first event, the offline banner shows "No connection" even though connectivity is unknown, not confirmed offline.

**Why it happens:** If the connectivity provider's initial state defaults to "offline" and the banner doesn't check the AsyncValue's loading state.

**How to avoid:** The `StreamProvider` from D-02 should emit its first event immediately (connectivity_plus does this on startup). If you're testing and the first event is delayed, handle the loading state in the banner widget:

```dart
class OfflineBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connAsync = ref.watch(connectivityProvider);
    
    return connAsync.when(
      data: (isOnline) => isOnline ? SizedBox.shrink() : _buildBanner(),
      loading: () => SizedBox.shrink(),  // Don't show banner while loading
      error: (_, __) => SizedBox.shrink(),  // Don't show banner on error
    );
  }
}
```

**Warning signs:** Banner flashes "No connection" for 1-2 seconds on startup even though the device has internet.

### Pitfall 6: Version Guard Prevents Timestamp Update

**What goes wrong:** The `_version` counter guard (WR-02, from Phase 2) prevents a stale background refresh from reverting a local edit. But if a mutation happens while a background refresh is in flight, the refresh's new timestamp *doesn't* apply, and the staleness indicator shows old data even though a fresh fetch succeeded.

**Why it happens:** The version guard discards the entire refresh result (including its new syncedAt timestamp) if the local version has advanced. This is correct for preventing data reversion, but D-06 requires updating the timestamp only on success.

**How to avoid:** When a background refresh succeeds but is discarded due to version mismatch, still update the cached `syncedAt` to reflect the successful fetch, but don't apply the fetched data. This is an edge case and may require careful provider logic — see the code-examples section.

**Warning signs:** After a local edit while a background refresh is in flight, the staleness indicator says "stale 15m" even though the background refresh just returned fresh data from the server.

## Code Examples

Verified patterns from official sources:

### Wrapping Cache Writes with Timestamps

**Source:** [CITED: Phase 1-4 cache-first implementation + CONTEXT.md D-04]

```dart
// lib/cache/cache_service.dart — Example of modified writeProfile to wrap with syncedAt

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

// On read, extract the wrapper
Future<Map<String, dynamic>?> readProfile() async {
  try {
    final wrapped = _profileStore.get(_profileKey);
    if (wrapped == null) return null;
    
    // D-04: Extract data and syncedAt from wrapper
    // Return unwrapped data to provider; provider extracts syncedAt separately
    return wrapped['data'] as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

// Helper to extract syncedAt for staleness indicator
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

### Riverpod StreamProvider for Connectivity

**Source:** [CITED: Riverpod docs, Medium articles on connectivity_plus + Riverpod]

```dart
// lib/providers/connectivity_provider.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_provider.g.dart';

@riverpod
Stream<bool> connectivity(ConnectivityRef ref) {
  // D-02: Single StreamProvider wrapping connectivity_plus
  // D-03: No debounce — instant state flips
  
  return Connectivity().onConnectivityChanged.map(
    (result) => result != ConnectivityResult.none,
  );
}
```

### Disabling a FAB While Offline

**Source:** [CITED: Flutter Material Design disabled-state styling + Material Button documentation]

```dart
class BandCreationFab extends ConsumerWidget {
  const BandCreationFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-14: Watch connectivity reactively
    final isOnline = ref.watch(connectivityProvider);

    return isOnline.when(
      data: (online) => FloatingActionButton(
        // D-11: Disabled + grayed out while offline
        onPressed: online ? () => _showCreateForm(context, ref) : null,
        // D-13: Tooltip feedback on tap
        tooltip: online ? 'Add band' : 'Requires connection',
        child: Icon(Icons.add),
      ),
      loading: () => FloatingActionButton(
        onPressed: null,
        tooltip: 'Loading...',
        child: Icon(Icons.add),
      ),
      error: (_, __) => FloatingActionButton(
        onPressed: null,
        tooltip: 'Connection error',
        child: Icon(Icons.add),
      ),
    );
  }

  void _showCreateForm(BuildContext context, WidgetRef ref) {
    // Show create form only if online
    // ...
  }
}
```

### Silent Background Refresh That Preserves syncedAt on Failure

**Source:** [CITED: Phase 1-4 profile_provider.dart, extended with D-06 logic]

```dart
// lib/providers/profile_provider.dart — Modified _refresh() to handle D-06

@riverpod
class ProfileData extends _$ProfileData {
  Future<void>? _inFlightRefresh;

  @override
  Future<Map<String, dynamic>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    
    // D-04: Read wrapper
    final cachedRaw = await cache.readProfile();
    if (cachedRaw != null) {
      // D-04/D-05: Extract data from wrapper
      final data = cachedRaw['data'] as Map<String, dynamic>;
      unawaited(_refresh());
      return data;
    }
    
    return _fetchAndCache();
  }

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
    return profile;
  }

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

  // ... refresh() and _doRefresh() methods (unchanged from Phase 1-4)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No connectivity awareness in UI | Global connectivity state provider (D-02) | Phase 5 | Enables per-app offline/online visual signals; foundation for future mutation-queueing if needed |
| Raw cache data without metadata | Cache payloads wrapped with `syncedAt` (D-04) | Phase 5 | Staleness tracking becomes possible; users see data age |
| Silent background-refresh failures hide stale data age | Frozen `syncedAt` on refresh failure (D-06) | Phase 5 | Staleness indicator accurately reflects actual data age, even if background sync is failing |
| No visual indication of offline state | Global offline banner (D-10) + disabled mutations (D-11) | Phase 5 | Users understand why mutations fail; no silent API errors |

**Deprecated/outdated:**
- Pre-Phase-5 apps have no staleness awareness → This phase adds it for the first time
- Pre-Phase-5 mutations fail silently on offline → This phase blocks them visibly

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `connectivity_plus` 6.1.0+ is stable and widely used on pub.dev | Standard Stack | If package is abandoned or has critical bugs, need to switch to alternative (unlikely, but check before locking to 6.1.0) |
| A2 | Material Design disabled-state styling (color + icon change, no layout shift) is sufficient UX feedback | Architecture Patterns, Pitfall 1 | If disabled buttons confuse users, may need additional text (e.g., "Offline" label) or modal dialog |
| A3 | 10-minute / 30-minute thresholds for staleness indicator are reasonable defaults | Architecture Patterns | If users find 30m too long before warning, or 10m too short before indicator appears, these constants need tuning based on UAT feedback |
| A4 | Riverpod 2.6.1's `StreamProvider` will emit its first `ConnectivityResult` synchronously on startup | Architecture Patterns | If first event is delayed or missing, offline banner may show incorrectly on app launch (add loading state to banner as workaround) |
| A5 | No reachability ping is acceptable for v1 per D-01 | Common Pitfalls, Pitfall 1 | Users on captive portals will see "online" even without internet; documented limitation; acceptable for MVP |

**If this table is empty:** Placeholder — see assumptions tagged `[ASSUMED]` in other sections.

## Open Questions

1. **Should staleness indicator show hours/days formatting for very old cached data?**
   - What we know: D-09/D-08 require minutes-based display ("Xm ago") escalating to warning color at 30m
   - What's unclear: How to handle data older than 60m or 1d (show "1h 5m ago" or "1d 2h ago"?)
   - Recommendation: Implement minutes-based display for MVP (simplest); if users request day/hour formatting, add it in a future phase

2. **What should happen if the connectivity stream emits an error?**
   - What we know: D-02 uses `Connectivity().onConnectivityChanged`, which can theoretically emit errors on platform layer
   - What's unclear: Should errors show the offline banner, hide the banner, or log silently?
   - Recommendation: For MVP, treat error as unknown state (hide banner, don't show offline signal); users can still use the app; log error for debugging

3. **Should the offline banner be dismissible?**
   - What we know: D-10 says "persistent" is a Claude's Discretion item (implementation choice)
   - What's unclear: If user dismisses the offline banner, should it reappear when connectivity changes?
   - Recommendation: Start with persistent (non-dismissible) for v1; if UX testing shows users want to dismiss it, add a close button that re-shows on state change

4. **Should mutation entry points be hidden (instead of disabled) when offline?**
   - What we know: D-11 explicitly says "disabled + visually grayed out," not hidden
   - What's unclear: UX preference trade-off: does disabling confuse users more than hiding?
   - Recommendation: Follow D-11's guidance (disable, not hide); if QA/UAT feedback contradicts this, escalate to discuss-phase for a decision change

## Environment Availability

### External Dependencies

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `connectivity_plus` (pub.dev) | Connectivity detection (D-01) | ✓ | 6.1.0+ | — (no fallback; core to phase) |
| Flutter SDK | All (baseline) | ✓ | 3.12.2+ | — (assumed present) |
| Riverpod ecosystem | State management (D-02) | ✓ | 2.6.1+ (already in use) | — (no fallback) |
| Hive (local storage) | Cache storage (already in use) | ✓ | 2.2.3+ | — (no fallback) |

### Internet Connectivity

This phase does NOT require internet connectivity for development, testing, or app runtime (ironic given its purpose). All dependencies are local; `connectivity_plus` is an OS-level plugin, not a network-dependent service.

**Missing dependencies with no fallback:**
- None — all required packages are available

**Missing dependencies with fallback:**
- None

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (built-in) + `riverpod_test` patterns (via ProviderContainer) |
| Config file | `pubspec.yaml` (existing); no separate jest.config or pytest.ini needed |
| Quick run command | `flutter test test/providers/connectivity_provider_test.dart` |
| Full suite command | `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OFFL-02 | Cached data is viewable in offline mode (no connectivity error shown) | Widget | `flutter test test/widget_test.dart -k "offline"` | ❌ Wave 0 |
| OFFL-03 | Mutations are disabled while offline (onPressed is null, button visually grayed) | Widget + Provider | `flutter test test/features/bands/band_creation_test.dart -k "offline_fab_disabled"` | ❌ Wave 0 |
| OFFL-04 | Staleness indicator shows after 10m, escalates color/icon after 30m | Widget | `flutter test test/widgets/staleness_indicator_test.dart` | ❌ Wave 0 |
| OFFL-05 | Offline banner appears when connectivity is false, disappears when true | Widget + Provider | `flutter test test/widgets/offline_banner_test.dart` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/providers/connectivity_provider_test.dart` (quick provider test, ~30s)
- **Per wave merge:** `flutter test` (full suite, existing + new Phase 5 tests, ~2-3 min)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `test/providers/connectivity_provider_test.dart` — covers connectivity StreamProvider, mocking ConnectivityResult.none/wifi/cellular
- [ ] `test/widgets/staleness_indicator_test.dart` — covers 10m hidden threshold, 30m warning escalation, time formatting
- [ ] `test/widgets/offline_banner_test.dart` — covers banner visibility toggle based on connectivity state
- [ ] `test/features/bands/band_creation_fab_test.dart` (and similar for tracks/setlists) — covers FAB disable/enable on connectivity change, tooltip presence
- [ ] `test/providers/profile_provider_test.dart` (extend existing) — covers D-06 behavior: timestamp not updated on silent refresh failure
- [ ] `test/cache/cache_service_test.dart` (extend existing) — covers D-04: read/write of `{data, syncedAt}` wrapper, syncedAt extraction

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Not touched (existing auth_provider unchanged) |
| V3 Session Management | No | Not touched (existing token storage unchanged) |
| V4 Access Control | No | Not touched (mutations still require API auth) |
| V5 Input Validation | No | Not touched (form validation unchanged) |
| V6 Cryptography | No | Not touched (HTTP over TLS unchanged) |
| V7 Cross-Origin Resource Sharing (CORS) | No | Not applicable (mobile app, not web-based) |
| V8 Rate Limiting | No | Not introduced (mutation rate limiting stays at API layer) |
| V9 Resilience & Logging | **Yes** | Offline detection + graceful degradation (read-only cache, no silent failures) |
| V14 Data Privacy | No | Cached data scope unchanged (already contains sensitive band/user info, not introducing new PII) |

### Known Threat Patterns for Flutter Offline UX

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stale data displayed as fresh (user edits band while offline, cache shows old member list) | Spoofing | Staleness indicator (D-07/D-08) makes age visible; users can manually refresh if unsure |
| Mutation silently fails offline, user thinks action succeeded (user taps "Delete band" offline, dismisses dialog, navigates away; deletion never happens) | Tampering | Visible mutation blocking (D-11/D-12/D-13) + disabled buttons prevent this entry point; mutations cannot be initiated offline |
| App logs cached data as "just synced" even though refresh failed (attackers see false "last sync" timestamp in logs) | Tampering + Information Disclosure | D-06 preserves `syncedAt` on failure, keeping timestamp honest; logs will show actual staleness, not false freshness |
| Connectivity state spoofed by compromised OS (unlikely on Android/iOS, but theoretically possible) | Spoofing | D-01 accepts this risk; reachability ping would add only marginal security (not a blocker for v1) |

**No additional controls required.** This phase adds UI/UX guardrails, not cryptographic or access-control changes. Existing API auth (JWT/token in Authorization header) remains the security boundary; this phase merely prevents users from *attempting* mutations when they shouldn't.

## Sources

### Primary (HIGH confidence)

- [pub.dev connectivity_plus package](https://pub.dev/packages/connectivity_plus) — verified current version, platform support, API documentation
- [Riverpod docs — StreamProvider](https://riverpod.dev/docs/providers/stream_provider) — StreamProvider API and patterns for wrapping streams
- [Phase 1-4 code (profile_provider.dart, cache_service.dart, bands_provider.dart, etc.)](file:///home/bulat.khafizov/projects/personal/cadence/cadence-client/lib/providers/) — verified cache-first pattern and Riverpod provider shapes in use
- [Material Design 3 — States](https://m3.material.io/foundations/interaction/states/applying-states) — disabled button styling guidelines

### Secondary (MEDIUM confidence)

- [Ensure Smooth Offline Functionality for Your Flutter App](https://www.ptolemay.com/post/making-your-flutter-app-work-offline) — offline UX patterns and best practices
- [Building Resilient Apps: A Guide to Offline-First Architecture in Flutter](https://medium.com/design-bootcamp/building-resilient-apps-a-guide-to-offline-first-architecture-in-flutter-c062fc1f1092) — offline-first architecture and data synchronization considerations
- [Flutter Connectivity Done Right](https://asoasis.tech/articles/2026-04-24-2053-flutter-connectivity-check-network-status/) — connectivity detection pitfalls, captive portal warnings
- [Handle Internet Connectivity In Flutter With Riverpod](https://medium.com/@shreebhagwat94/handle-internet-connectivity-in-flutter-with-riverpod-bbde21c187dc) — practical Riverpod + connectivity_plus integration example
- [Learn Riverpod From Scratch Part 4: StreamProvider](https://medium.com/@purboyndra/learn-riverpod-from-scratch-part-4-streamprovider-5c9f6f38e4a1) — StreamProvider conceptual guide and usage patterns

### Tertiary (LOW confidence)

- [Creating a "Time Ago" Formatter in Flutter](https://medium.com/@saqlainalishah/creating-a-time-ago-formatter-in-flutter-8b317da9806d) — manual time-ago formatting approach (not required if intl or simple string interpolation suffices)
- [get_time_ago package](https://pub.dev/packages/get_time_ago) — optional dependency for i18n-aware relative time formatting (not required for MVP, which can use simple "Xm ago" strings)

## Metadata

**Confidence breakdown:**
- **Standard stack (connectivity_plus + Riverpod):** HIGH — widely adopted, stable packages; patterns verified in official docs and community examples
- **Architecture (cache-first + StreamProvider + timestamp wrapper):** HIGH — builds directly on Phase 1-4 proven patterns; D-01 through D-14 decisions are locked and well-reasoned
- **Pitfalls (captive portals, timestamp drift, version guard):** MEDIUM-HIGH — captive portal gotcha is documented in research; timestamp drift risk is known and addressed by D-04; version-guard edge case requires careful implementation
- **Validation (test coverage):** MEDIUM — existing test patterns (widget + provider testing) are proven; Wave 0 gaps are straightforward provider/widget tests with no novel patterns

**Research date:** 2026-08-17
**Valid until:** 2026-08-31 (14 days — stable domain, no rapid version churn expected)
