# Phase 2: Bands - Research

**Researched:** 2026-08-15
**Domain:** Band management with Riverpod + Hive cache-store pattern extension
**Confidence:** HIGH (decisions locked in CONTEXT.md; Phase 1 pattern verified; API contract reviewed)

## Summary

Phase 2 extends the Riverpod + Hive cache-first pattern from Phase 1 to full band management: listing bands, creating new bands, viewing band detail with members and invite code, updating band names, joining via invite code, leaving bands, and owner-only delete/member-remove operations.

The phase is tightly scoped around the decisions in CONTEXT.md (D-01 through D-15): owner-gating is direct (comparing `Band.ownerId` to `UserProfile.id`), cache storage mirrors Phase 1's per-endpoint-box pattern, and all destructive actions follow prescribed confirmation flows (type-to-confirm for delete, standard dialog for leave/remove).

**Primary recommendation:** Extend Phase 1's AsyncNotifier + Hive pattern directly to band endpoints. No new state-management approach or caching strategy; only apply existing patterns to new domain (bands list + per-band detail). Implement band-list and band-detail cache providers following `ProfileData` and `HomepageData` as templates. Build new `BandsApi` methods in `public_api.dart` wrapping `ApiClient.send()`. Implement screens as ConsumerWidgets watching band providers, with mutation actions caught at UI layer for error display.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**API gap & owner-gating (D-01 through D-04):**
- Assume `Band.ownerId` and `UserProfile.id` exist and are correct (backend is ready).
- No username-match fallback, no defensive missing-field handling.
- Owner-only actions (Delete band, Remove member) are hidden entirely for non-owners — not shown-disabled.
- Current user id comes from existing `profileProvider` (`GET /api/me`, cache-first), no new network call.

**Band list & detail caching (D-05 through D-08):**
- Bands list row shows name + first-letter avatar circle (no member count/genre as placeholders).
- Avatar is dedicated reusable widget (`BandAvatar`, e.g. `lib/features/bands/band_avatar.dart`) for future image swap-in.
- Both band list (`bandsBox`) and per-band detail (members, inviteCode, ownerId) are cached following Phase 1's one-box-per-endpoint pattern.
- Band detail screen uses cache-first pattern: show cached detail immediately if present, then refresh silently; first-ever view shows loading.

**Create & join band flow (D-09 through D-12):**
- Single FAB on Bands list opens action menu/bottom sheet with "Create band" and "Join with code".
- "Create band" opens full screen (not dialog), consistent with detail/edit screens.
- "Join band" (invite code entry) opens dialog — matches single-field `JoinBandRequestBody`.
- After create/join succeeds, navigate to that band's detail screen (not back to list).

**Destructive actions (D-13 through D-15):**
- "Delete band" uses type-to-confirm: user must type the band's name to enable the Delete button.
- "Leave band" and "Remove member" use standard Cancel/Confirm dialog with interpolated copy.
- After delete or leave from detail screen, return to Bands list (which reflects the removal).

### Claude's Discretion

- Exact bottom-sheet/menu styling for FAB's Create/Join action menu (D-09).
- `BandAvatar` widget's initial-letter rendering (color, sizing) — follow existing theme.
- Empty-state copy/layout for "no bands yet" — follow Phase 1 pattern for empty/error states.

### Deferred Ideas (OUT OF SCOPE)

- Real image avatars for bands — planned for later milestone; D-06's reusable widget structure enables painless swap-in.
- Per-member roles beyond owner/member — no role field exists in API; not supported.
- Offline mutation queue (create/join/leave/delete offline, sync on reconnect) — Phase 5 owns offline mutations; Phase 2 is read-only cache + online mutations.
- Offline mutations disabled when offline — Phase 5 owns mutation blocking; Phase 2 mutations require connectivity.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BAND-01 | User can view list of bands they belong to | Bands list provider with cache-first load; `BandsListData` AsyncNotifier mirrors `HomepageData` pattern |
| BAND-02 | User can create a new band | `CreateBandScreen` with form; `PublicApi.createBand()` method; post-create navigation to new band's detail |
| BAND-03 | User can view band detail (name, members, invite code) | `BandDetailScreen` + `BandDetailData` provider; per-band cached detail following D-07/D-08 |
| BAND-04 | User can update a band's name | `UpdateBandScreen` form; `PublicApi.updateBand()` method; cache invalidation on success |
| BAND-05 | Band owner can delete a band | Owner-gated UI (hide Delete button for non-owners via D-02); type-to-confirm dialog (D-13); post-delete return to list (D-15) |
| BAND-06 | User can join a band via invite code | `JoinBandDialog` with single text field; `PublicApi.joinBand()` method; cache invalidation on success |
| BAND-07 | User can view and copy the band's invite code to share | Displayed on `BandDetailScreen`; copy-to-clipboard action via `Clipboard.setData()` |
| BAND-08 | User can leave a band (remove self from member list) | Owner-gating: hide "Leave" for band owner (D-03); use `PublicApi.removeMember(bandId, userId)` with current user's id; standard Cancel/Confirm dialog (D-14) |
| BAND-09 | Band owner can remove another member from the band | Owner-gating via D-02; standard Cancel/Confirm dialog interpolating username (D-14); `PublicApi.removeMember(bandId, userId)` with target member's id |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Band list fetch | API / Backend | Database / Storage | `GET /api/band/list` → Riverpod `BandsListData` AsyncNotifier → Hive `bandsBox` cache-first load |
| Band detail fetch | API / Backend | Database / Storage | `GET /api/band/{bandId}` → Riverpod `BandDetailData` AsyncNotifier per band → Hive `bandsBox` (or per-band box per D-07) cache-first |
| Band creation | API / Backend | — | `POST /api/band` → `PublicApi.createBand()` → error caught at UI layer; on success, navigate to detail screen |
| Band update (name) | API / Backend | — | `PUT /api/band/{bandId}` → `PublicApi.updateBand()` → on success, update detail provider state + cache |
| Band deletion | API / Backend | — | `DELETE /api/band/{bandId}` → owner-only via D-02/D-13 type-to-confirm → cache invalidation + list refresh |
| Join band via invite | API / Backend | — | `POST /api/band/join` → `PublicApi.joinBand()` → on success, refresh list provider + navigate to detail |
| Leave band (self-remove) | API / Backend | — | `DELETE /api/band/{bandId}/remove-member/{userId}` with current user's id → owner-gating D-03 (hide for owner) → cache invalidation + return to list |
| Remove member (owner action) | API / Backend | — | `DELETE /api/band/{bandId}/remove-member/{userId}` with target member id → owner-only via D-02 → cache invalidation |
| Owner permission check | Browser / Client | — | Compare `Band.ownerId` (from detail cache) to `UserProfile.id` (from profile provider) per D-01/D-02 |
| Band avatar (initials) | Browser / Client | — | Dedicated `BandAvatar` reusable widget rendering first letter in theme-matching color circle |
| Invite code display & copy | Browser / Client | — | Display on detail screen; copy-to-clipboard via `Clipboard.setData()` from Flutter's material services |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `flutter_riverpod` | ^2.6.1 | State management for band data providers | [VERIFIED: pubspec.yaml] Established in Phase 1; same line used for all async data |
| `riverpod_annotation` | ^2.6.1 | @riverpod decorator for codegen | [VERIFIED: pubspec.yaml] Required for AsyncNotifier pattern in Phase 1; extend to bands |
| `riverpod_generator` | ^2.6.5 (dev) | Codegen band providers | [VERIFIED: pubspec.yaml] Phase 1 decision D-10; locked approach |
| `build_runner` | ^2.5.4 (dev) | Runs Dart codegen | [VERIFIED: pubspec.yaml] Phase 1 dev dependency; already in place |
| `hive` | ^2.2.3 | Hive box storage (existing) | [VERIFIED: pubspec.yaml] Phase 1 decision D-01; extend with `bandsBox` |
| `hive_flutter` | ^1.1.0 | Hive platform integration | [VERIFIED: pubspec.yaml] Phase 1 dependency; already initialized |
| `http` | ^1.6.0 | HTTP client wrapper | [VERIFIED: pubspec.yaml] Existing, wrapped by `ApiClient` |
| `flutter_secure_storage` | ^11.0.0 | Token persistence | [VERIFIED: pubspec.yaml] Existing; unchanged |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_test` | SDK | Widget testing framework | Testing band providers and screens |
| `flutter_lints` | ^6.0.0 | Dart analysis rules | Already applied; no new dependencies |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One `bandsBox` for list + detail | Separate `bandDetailBox` per band | Single box simpler (one cache key per endpoint); separate boxes allow per-band versioning; D-07 uses per-endpoint pattern so single box is correct |
| AsyncNotifier for band list/detail | FutureProvider + manual state | AsyncNotifier provides refresh() method + silent background updates (D-06); FutureProvider is read-only; would need additional StateNotifier for mutations |
| Type-to-confirm for delete | Simple "are you sure?" dialog | Type-to-confirm is irreversible/destructive friction per D-13 rationale; lighter dialog for leave/remove (D-14) is appropriate |

**Installation:**
```bash
# No new packages needed; extend existing Phase 1 stack with band providers + BandsApi methods
flutter pub run build_runner watch --delete-conflicting-outputs  # Already running from Phase 1
```

## Package Legitimacy Audit

> All packages in Phase 2's standard stack are already locked in pubspec.yaml from Phase 1. No new packages introduced.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flutter_riverpod | pub.dev | 5+ years | 15M+/week | github.com/rrousselGit/riverpod | OK | Already approved in Phase 1 |
| riverpod_annotation | pub.dev | 5+ years | 15M+/week | github.com/rrousselGit/riverpod | OK | Already approved in Phase 1 |
| riverpod_generator | pub.dev | 5+ years | 15M+/week | github.com/rrousselGit/riverpod | OK | Already approved in Phase 1 |
| build_runner | pub.dev | 7+ years | 60M+/week | github.com/dart-lang/build | OK | Already approved in Phase 1 |
| hive | pub.dev | 5+ years | 5M+/week | github.com/isar/hive | OK | Already approved in Phase 1 |
| hive_flutter | pub.dev | 5+ years | 5M+/week | github.com/isar/hive | OK | Already approved in Phase 1 |

**Packages removed due to [SLOP] verdict:** None.
**Packages flagged as suspicious [SUS]:** None.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                   Riverpod ProviderScope (extended Phase 1)          │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              Band Data Layer (new AsyncNotifiers)            │   │
│  │                                                              │   │
│  │  BandsListData Provider:                                    │   │
│  │    GET /api/band/list → cached in Hive bandsBox →           │   │
│  │    List[{id, name}] (BandListItem)                          │   │
│  │                                                              │   │
│  │  BandDetailData Provider (per-band):                        │   │
│  │    GET /api/band/{bandId} → cached in Hive bandsBox →       │   │
│  │    {id, name, ownerId, members, inviteCode}                 │   │
│  │                                                              │   │
│  │  Both follow Phase 1's cache-first pattern:                 │   │
│  │    1. Check cache first (silent return if hit)              │   │
│  │    2. Fire background refresh silently                      │   │
│  │    3. On cache miss, fetch inline (show loading)            │   │
│  │                                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │          Bands API Layer (extends PublicApi)                │   │
│  │                                                              │   │
│  │  PublicApi.listBands() → GET /api/band/list                │   │
│  │  PublicApi.createBand(name) → POST /api/band                │   │
│  │  PublicApi.getBand(bandId) → GET /api/band/{bandId}        │   │
│  │  PublicApi.updateBand(bandId, name) → PUT /api/band/...    │   │
│  │  PublicApi.deleteBand(bandId) → DELETE /api/band/...       │   │
│  │  PublicApi.joinBand(inviteCode) → POST /api/band/join      │   │
│  │  PublicApi.removeMember(bandId, userId) →                  │   │
│  │    DELETE /api/band/{bandId}/remove-member/{userId}         │   │
│  │                                                              │   │
│  │  All wrap ApiClient.send() + error handling                 │   │
│  │                                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │              UI Layer (ConsumerWidgets)                      │   │
│  │                                                              │   │
│  │  BandsScreen (list) → ref.watch(bandsListProvider)          │   │
│  │    FAB → [Create / Join] action menu (D-09)                 │   │
│  │                                                              │   │
│  │  CreateBandScreen → form → PublicApi.createBand()           │   │
│  │    → on success: navigate to BandDetailScreen               │   │
│  │                                                              │   │
│  │  JoinBandDialog → inviteCode field → PublicApi.joinBand()   │   │
│  │    → on success: navigate to newly-joined band detail       │   │
│  │                                                              │   │
│  │  BandDetailScreen → ref.watch(bandDetailProvider)           │   │
│  │    → displays name, members, invite code                    │   │
│  │    → owner-gated actions (delete, remove member)            │   │
│  │    → self-remove action (hidden for owner)                  │   │
│  │                                                              │   │
│  │  Error states:                                              │   │
│  │    ApiException caught at screen level → show snackbar      │   │
│  │    403 permission_denied → auto-logout via ApiClient        │   │
│  │                                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │            Auth & Profile Layer (Phase 1, reused)            │   │
│  │                                                              │   │
│  │  ProfileData → UserProfile.id (for owner checks via D-04)   │   │
│  │  AuthSession → token for all band API calls                 │   │
│  │                                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

```
lib/features/bands/
├── bands_screen.dart          # List screen with FAB → Create/Join menu
├── band_detail_screen.dart    # Detail: name, members, invite code, actions
├── create_band_screen.dart    # Full-screen form for band creation
├── join_band_dialog.dart      # Dialog for invite-code entry
├── band_avatar.dart           # Reusable widget: first-letter circle avatar
├── band_detail_edit_screen.dart # (Phase 4+) Update band name; skipped Phase 2
├── band_member_tile.dart      # (optional) Refactor member list into widget

lib/providers/
├── bands_provider.dart        # New: @riverpod BandsListData + BandDetailData
├── (other existing providers)

lib/api/
├── public_api.dart            # Extend with new band methods
```

### Pattern 1: Cache-First Band List Load (mirrors Phase 1)

**What:** `BandsListData` AsyncNotifier watches cache + fires silent background refresh.

**When to use:** Whenever displaying the user's band list; on app resume, swipe-to-refresh, or explicit refresh button.

**Example:**
```dart
// lib/providers/bands_provider.dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/public_api.dart';
import '../cache/cache_service.dart';
import 'auth_provider.dart';

part 'bands_provider.g.dart';

/// Cache-first `GET /api/band/list` data.
/// 
/// On [build], cached data (if present) is returned immediately with a
/// background refresh kicked off silently (D-04/D-06 in 02-CONTEXT.md).
/// With no cache, the network fetch happens inline and any [ApiException]
/// becomes an [AsyncError].
@riverpod
class BandsListData extends _$BandsListData {
  Future<void>? _inFlightRefresh;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBands();
    if (cached != null) {
      unawaited(_refresh());
      return cached;
    }
    return _fetchAndCache();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache() async {
    final api = ref.read(publicApiProvider);
    final data = await api.listBands();
    await ref.read(cacheServiceProvider).writeBands(data);
    return data;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
    } catch (_) {
      // Keep showing cached data.
    }
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
    }
  }
}
```

### Pattern 2: Owner-Gating UI (D-01/D-02)

**What:** Compare `Band.ownerId` to current user's id; hide non-owner actions entirely.

**When to use:** Delete button, Remove member action; owner-gating must be consistent across all screens.

**Example:**
```dart
// In BandDetailScreen
Future<void> _showDeleteConfirmation() async {
  final profile = await ref.read(profileDataProvider.future);
  final currentUserId = profile?['id'] as String?;
  final bandDetail = await ref.read(bandDetailProvider(bandId).future);
  final ownerId = bandDetail?['ownerId'] as String?;

  if (currentUserId == null || ownerId == null || currentUserId != ownerId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Only the band owner can delete the band.')),
    );
    return;
  }

  // Proceed with type-to-confirm (D-13)
  _showTypeToConfirmDialog(bandDetail?['name'] ?? 'Unknown Band');
}
```

### Pattern 3: Type-to-Confirm for Destructive Delete (D-13)

**What:** User must type the band name exactly to enable the Delete button.

**When to use:** Only for irreversible actions affecting all band members (band deletion).

**Example:**
```dart
// Dialog with text input matching band name
void _showTypeToConfirmDialog(String bandName) {
  final controller = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Band'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Type "$bandName" to confirm deletion:'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter band name'),
            onChanged: (_) => setState(() {}), // Trigger rebuild for button state
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: controller.text == bandName ? _deleteBand : null,
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
```

### Pattern 4: Standard Confirmation Dialog for Leave/Remove Member (D-14)

**What:** Simple Cancel/Confirm dialog with interpolated copy, no typing required.

**When to use:** Leave band (self-remove), remove another member (owner action).

**Example:**
```dart
// Leave band dialog
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Leave Band'),
    content: Text('Leave "${bandDetail['name']}"?\nYou can rejoin later with an invite code.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          _leaveBand();
        },
        child: const Text('Leave'),
      ),
    ],
  ),
);

// Remove member dialog (owner only)
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Remove Member'),
    content: Text('Remove ${memberUsername} from "${bandDetail['name']}"?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          _removeMember(memberId);
        },
        child: const Text('Remove'),
      ),
    ],
  ),
);
```

### Pattern 5: Post-Success Navigation (D-12/D-15)

**What:** After create/join, navigate to detail screen; after delete/leave, return to list.

**When to use:** All mutation actions (create, join, update, delete, leave, remove member).

**Example:**
```dart
// After successful createBand
Future<void> _submitCreateBand(String name) async {
  try {
    final api = ref.read(publicApiProvider);
    final response = await api.createBand(name: name);
    final newBandId = response['id'] as String;
    
    // Invalidate bands list to trigger refresh
    ref.invalidate(bandsListDataProvider);
    
    // Navigate to new band's detail screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BandDetailScreen(bandId: newBandId),
        ),
      );
    }
  } on ApiException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.message}')),
    );
  }
}
```

### Anti-Patterns to Avoid

- **Checking ownership by username:** Backend provides `ownerId` (D-01); never rely on username matching for permission gating — usernames are not guaranteed unique and create security gaps.
- **Showing disabled-but-visible owner-only buttons:** Per D-02, hide the button entirely; no grayed-out non-functional button. This prevents confusion and accidental taps.
- **Calling the API twice on permission-denied:** If 403 is returned (owner mismatch), ApiClient auto-logs out (existing pattern). Don't retry or show "permission denied" message expecting a second attempt.
- **Mutating cache in the UI layer:** Cache writes happen in `_fetchAndCache()` inside the provider, not in screen event handlers. Screens only read providers and call API methods; cache invalidation via `ref.invalidate()` after successful mutation.
- **Forgetting to invalidate list after mutation:** Creating/joining a band must invalidate `bandsListDataProvider` so the list refreshes; deleting/leaving must do the same. Forgetting invalidation leaves the list stale.
- **Trying to join while offline:** Phase 2 mutations require connectivity (Phase 5 owns offline mutation queue). No offline queueing; just show "requires connectivity" error if the network call fails.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local cache storage | Custom JSON serialization or SQLite | Hive (D-01 from Phase 1) | Hive handles Map<String, dynamic> natively; no schema migration headaches; already initialized |
| Provider state management | Reducer pattern or GetIt service locator | Riverpod AsyncNotifier (D-10) | AsyncNotifier gives cache-first + refresh() + error handling; codegen eliminates boilerplate; locked approach |
| HTTP layer | Direct http.Client calls in UI | ApiClient wrapper (D-09) | Single place for auth headers, token injection, 403 auto-logout; consistent error handling |
| API method signatures | Hardcoding request/response parsing in screens | BandsApi class (new) wrapping ApiClient | Encapsulates endpoint contracts; reusable across screens; single source of truth for request/response shapes per `publicapi.yml` |
| Invite code copy | Manual Clipboard handling | `Clipboard.setData()` from services/material | Flutter standard; one-liner; shows copy feedback via snackbar |
| Permission checks | Figuring out ownership after the fact | Direct `ownerId` comparison on load (D-01/D-02) | Backend provides `ownerId` upfront; no guessing or username matching; proactive hiding avoids confusing UX |

**Key insight:** All of these are deceptively complex if hand-rolled (serialization edge cases, provider lifecycle bugs, auth header injection in 10 places, clipboard permissions). Using existing/established patterns avoids weeks of debugging.

## Common Pitfalls

### Pitfall 1: Cache Invalidation Timing

**What goes wrong:** After creating a band, the list screen is pushed aside, then when the user goes back to the list, they see the old data. The new band doesn't appear until they pull-to-refresh.

**Why it happens:** `ref.invalidate(bandsListDataProvider)` was called after create succeeds, but before the navigation happened — by the time the user returns to the list screen, the stale cache is re-read.

**How to avoid:** Call `ref.invalidate()` before returning to the list or before the provider is next read. If navigating away, invalidate immediately after the API call succeeds, not inside the navigation callback. Test by creating a band, navigating to detail (to confirm success), then popping back — the list should have the new band visible.

**Warning signs:** New bands/joined bands don't show in the list until manual refresh; joined band doesn't appear after "Join" succeeds; updated band name doesn't reflect on detail screen until reload.

### Pitfall 2: Owner-Gating Race Condition

**What goes wrong:** The owner-only "Delete" button is visible for a moment, then disappears after the profile loads. Or, the button is hidden even though the current user is the owner.

**Why it happens:** `BandDetailData` and `ProfileData` load asynchronously; ownership check in `build()` reads an older snapshot of `profileDataProvider` before it has the profile data, or reads an empty profile if the request is still in flight.

**How to avoid:** Use a combined provider that waits for both band detail and profile data, then compares in a single place. Or, gate the button display on `profileDataProvider.when()` so it only renders once the profile is loaded.

```dart
// ✓ Correct: wait for profile before checking ownership
bool _isOwner(AsyncValue<Map<String, dynamic>> profile, Map<String, dynamic> band) {
  return profile.maybeWhen(
    data: (p) {
      final userId = p['id'] as String?;
      final ownerId = band['ownerId'] as String?;
      return userId == ownerId;
    },
    orElse: () => false,
  );
}
```

**Warning signs:** Buttons flicker on/off as data loads; owner sees "You can't delete" error despite being the owner; non-owner can see a delete button.

### Pitfall 3: Invite Code Handling

**What goes wrong:** User copies the invite code but it includes trailing whitespace. They paste it into another device's join dialog, and the API rejects it as invalid.

**Why it happens:** `inviteCode` is copied directly from the API response without `.trim()`, or pasted from clipboard without trimming before sending to `joinBand()`.

**How to avoid:** Trim the code before display and before sending: `inviteCode.trim()` on both read and write. Display it in a monospace font to make whitespace visible if present.

**Warning signs:** Users report "invite code doesn't work" even though they copied it correctly; join dialog repeatedly rejects valid codes.

### Pitfall 4: Silent Background Refresh Failure

**What goes wrong:** Band detail screen shows stale data. User can see it's not the latest (they changed the name in another session), but there's no indication that a refresh is even happening.

**Why it happens:** Cache-first pattern (D-06) fires a silent background refresh that fails (network down, 500 error). The catch block swallows the error and leaves the cached data visible with no error indicator.

**How to avoid:** This is intentional per D-06 (Phase 5 owns staleness indicators). Phase 2 does NOT show a "this is cached" or "failed to refresh" indicator. Instead, if users expect to see fresh data, they should pull-to-refresh manually (which surfaces errors). Accept that silent background refresh failures are silent; Phase 5 will add visible staleness UI.

**Warning signs:** Data looks stale but no error is shown; user doesn't realize they're looking at cached data.

### Pitfall 5: Member List Ordering

**What goes wrong:** The members list in band detail is in a different order each time, confusing users. Or, after removing a member, the list doesn't update until the user navigates away and back.

**Why it happens:** `members` array from the API doesn't specify order; client re-fetches but doesn't invalidate the cache, so stale member list stays visible.

**How to avoid:** Accept whatever order the API returns (it should be stable, e.g., join-order). After a successful remove-member action, invalidate `bandDetailProvider(bandId)` to force a fresh fetch of the detail, which will reflect the member removal.

**Warning signs:** Members list reorders randomly; removed member still shows in the list after "Remove" succeeds; member appears twice.

## Code Examples

Verified patterns from existing Phase 1 code:

### Example 1: Extend CacheService for Bands

```dart
// lib/cache/cache_service.dart — add to existing class

static const _bandsKey = 'bands';

Future<List<Map<String, dynamic>>?> readBands() async {
  try {
    final raw = _bandsStore.get(_bandsKey);
    if (raw == null) return null;
    final items = raw['items'] as List?;
    if (items == null) return null;
    return items.cast<Map<String, dynamic>>();
  } catch (_) {
    return null;
  }
}

Future<void> writeBands(List<Map<String, dynamic>> data) async {
  try {
    await _bandsStore.put(_bandsKey, {'items': data});
  } catch (_) {
    // Non-critical cache write failure; swallow
  }
}

// For per-band detail caching (alternative: separate box)
Future<Map<String, dynamic>?> readBandDetail(String bandId) async {
  try {
    return _bandsStore.get('band_$bandId');
  } catch (_) {
    return null;
  }
}

Future<void> writeBandDetail(String bandId, Map<String, dynamic> data) async {
  try {
    await _bandsStore.put('band_$bandId', data);
  } catch (_) {
    // Non-critical cache write failure; swallow
  }
}
```

### Example 2: Add Band Methods to PublicApi

```dart
// lib/api/public_api.dart — add to existing class

Future<List<Map<String, dynamic>>> listBands() async {
  final response = await _client.send('GET', '/api/band/list');
  final items = response!['items'] as List;
  return items.cast<Map<String, dynamic>>();
}

Future<Map<String, dynamic>> createBand({required String name}) async {
  final response = await _client.send(
    'POST',
    '/api/band',
    body: {'name': name},
  );
  return response!;
}

Future<Map<String, dynamic>> getBand(String bandId) async {
  final response = await _client.send('GET', '/api/band/$bandId');
  return response!;
}

Future<void> updateBand({required String bandId, required String name}) async {
  await _client.send(
    'PUT',
    '/api/band/$bandId',
    body: {'name': name},
  );
}

Future<void> deleteBand(String bandId) async {
  await _client.send('DELETE', '/api/band/$bandId');
}

Future<void> joinBand({required String inviteCode}) async {
  await _client.send(
    'POST',
    '/api/band/join',
    body: {'inviteCode': inviteCode.trim()},
  );
}

Future<void> removeMember({required String bandId, required String userId}) async {
  await _client.send(
    'DELETE',
    '/api/band/$bandId/remove-member/$userId',
  );
}
```

### Example 3: BandsListData Provider (mirrors HomepageData pattern)

```dart
// lib/providers/bands_provider.dart

@riverpod
class BandsListData extends _$BandsListData {
  Future<void>? _inFlightRefresh;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    final cache = ref.watch(cacheServiceProvider);
    final cached = await cache.readBands();
    if (cached != null) {
      unawaited(_refresh());
      return cached;
    }
    return _fetchAndCache();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCache() async {
    final api = ref.read(publicApiProvider);
    final data = await api.listBands();
    await ref.read(cacheServiceProvider).writeBands(data);
    return data;
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
    } catch (_) {
      // Keep showing cached data.
    }
  }

  Future<void> refresh() {
    return _inFlightRefresh ??= _doRefresh().whenComplete(
      () => _inFlightRefresh = null,
    );
  }

  Future<void> _doRefresh() async {
    try {
      final fresh = await _fetchAndCache();
      state = AsyncData(fresh);
    } catch (e, st) {
      if (state.value == null) {
        state = AsyncError(e, st);
      }
    }
  }
}
```

### Example 4: Testing Band Provider (mirrors Phase 1 pattern)

```dart
// test/providers/bands_provider_test.dart

import 'dart:convert';
import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'cache-hit returns cached bands list with silent background refresh',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': '1', 'name': 'Band 1'},
        {'id': '2', 'name': 'Band 2'},
      ]);

      final apiClient = ApiClient(
        baseUrl: 'http://localhost',
        getToken: () => 'test-token',
        onUnauthorized: () async {},
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': '1', 'name': 'Band 1'},
                {'id': '2', 'name': 'Band 2'},
              ],
            }),
            200,
          );
        }),
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          cacheServiceProvider.overrideWithValue(cacheService),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(bandsListDataProvider.future);

      expect(data, isA<List>());
      expect(data.length, 2);
      expect(data[0]['name'], 'Band 1');
    },
  );
}
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (bundled with Flutter SDK) + riverpod testing utilities |
| Config file | analysis_options.yaml (already configured from Phase 1) |
| Quick run command | `flutter test test/providers/bands_provider_test.dart -k "cache-hit"` |
| Full suite command | `flutter test test/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BAND-01 | List bands from cache-first provider | unit | `flutter test test/providers/bands_provider_test.dart -k "cache-hit"` | ✅ (template provided) |
| BAND-02 | POST /api/band succeeds → navigate to detail | unit + integration | `flutter test test/providers/bands_provider_test.dart -k "create"` | ❌ Wave 0 |
| BAND-03 | GET /api/band/{bandId} cache-first load | unit | `flutter test test/providers/band_detail_provider_test.dart -k "cache-hit"` | ❌ Wave 0 |
| BAND-04 | PUT /api/band/{bandId} updates detail + invalidates cache | unit | `flutter test test/providers/band_detail_provider_test.dart -k "update"` | ❌ Wave 0 |
| BAND-05 | DELETE /api/band/{bandId} owner-only + list refresh | unit + widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "delete"` | ❌ Wave 0 |
| BAND-06 | POST /api/band/join succeeds → navigate to detail | unit | `flutter test test/providers/bands_provider_test.dart -k "join"` | ❌ Wave 0 |
| BAND-07 | inviteCode visible + Clipboard.setData works | widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "copy-invite"` | ❌ Wave 0 |
| BAND-08 | DELETE /api/band/{bandId}/remove-member/{userId} (self) + owner-gated | unit + widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "leave"` | ❌ Wave 0 |
| BAND-09 | DELETE /api/band/{bandId}/remove-member/{userId} (other) owner-only | unit + widget | `flutter test test/features/bands/band_detail_screen_test.dart -k "remove-member"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run provider-level tests (`flutter test test/providers/`) for quick feedback on data loading.
- **Per wave merge:** Full suite (`flutter test test/`) to catch screen integration issues.
- **Phase gate:** Full suite green + manual verification of owner-gating UI before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/providers/bands_provider_test.dart` — covers BAND-01 (list cache-first), BAND-02 (create), BAND-06 (join)
- [ ] `test/providers/band_detail_provider_test.dart` — covers BAND-03 (detail cache-first), BAND-04 (update)
- [ ] `test/features/bands/band_detail_screen_test.dart` — covers BAND-05/BAND-08/BAND-09 (ownership gating, delete/leave/remove dialogs)
- [ ] `test/features/bands/bands_screen_test.dart` — covers BAND-01 (list display), FAB interaction, navigation
- [ ] `test/features/bands/create_band_screen_test.dart` — covers BAND-02 (form validation, submission)
- [ ] `test/features/bands/join_band_dialog_test.dart` — covers BAND-06 (invite code input, validation)
- [ ] `lib/api/public_api.dart` — BandsApi methods (testable with MockClient pattern)

*(Existing test infrastructure from Phase 1 covers ProviderContainer setup, CacheService test double, MockClient patterns. New tests follow the same patterns.)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | AuthSession + token via `apiClientProvider` (Phase 1); 403 auto-logout on invalid session |
| V3 Session Management | yes | Token persistence via flutter_secure_storage (Phase 1); no session-specific state in Phase 2 |
| V4 Access Control | yes | Owner-gating via `Band.ownerId` comparison to `UserProfile.id` (D-01/D-02); no role-based access beyond owner/member |
| V5 Input Validation | yes | `name` field (band creation/update) validated for non-empty on form + API rejects invalid input; `inviteCode` trimmed before send; no client-side length validation needed (API contract defines limits) |
| V6 Cryptography | no | No new cryptography introduced; token transport via HTTPS (assumes API endpoint is HTTPS); no local encryption beyond flutter_secure_storage's platform handling |
| V7 Data Protection | yes | Cached data stored via Hive on device (platform-specific encryption handled by OS); no PII beyond usernames/band names in cache; clear-on-logout via `CacheService.clearAll()` |
| V8 Data Validation & Sanitization | yes | All responses from `publicapi.yml` validated against schema on client (decoded from JSON); `ApiException` on parse failure; no dynamic code execution |
| V9 Communications | no | Handled by http client (Phase 1); TLS/certificate validation assumed |

### Known Threat Patterns for Riverpod + Hive Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Ownership bypass via ID substitution | Tampering + Elevation of Privilege | Never trust user-submitted IDs for ownership checks; always compare server-returned `Band.ownerId` to server-returned `UserProfile.id` (D-01). No client-side ID forgery possible. |
| Token leakage via cache dumps | Information Disclosure | Token stored in flutter_secure_storage, not in Hive cache. Cache contains only responses (usernames, band names, no secrets). Cleared on logout. |
| Cache poisoning (stale band data) | Tampering | Cache-first load fires silent background refresh (D-06). Phase 5 adds visible staleness UI. Phase 2 accepts stale-data risk in exchange for offline read capability. |
| Permission check TOCTOU race | Race Condition | Owner-gating performed server-side (403 if not owner); client-side check hides UI but server is authoritative. No window for escalation. |
| Invite code enumeration | Information Disclosure | Invite codes come from backend; client only displays/copies. No client-side code generation or prediction. Server should rate-limit join attempts. |
| Concurrent mutations (delete + join same band) | Race Condition | API handles concurrency; client doesn't. If band is deleted while user is joining, API returns 404 or 400; client shows error. Acceptable per Phase 2 scope (no offline mutation queue). |

**No changes to existing auth/crypto/TLS stack.** Phase 2 adds data-access control (ownership gating) and input validation (invite code trimming, band name non-empty check).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Band.ownerId` field exists in API response and equals the creating user's id | D-01, API Contract | If backend hasn't shipped this field, owner-gating (BAND-05/BAND-09) can't be implemented proactively; must fall back to reactive 403 handling |
| A2 | `UserProfile.id` field exists in profile response (from Phase 1) | D-04 | If missing, can't identify current user for ownership comparison; must use username-match fallback (fragile) |
| A3 | Invite code is a simple string, not a one-time-use token | CONTEXT.md, API contract | If backend invalidates codes after join, UI must show "code expired" error instead of generic "invalid" |
| A4 | Band member list order from API is stable (or doesn't matter) | Pitfalls, CONTEXT.md | If members reorder unexpectedly, UI should accept and display as-is; no client-side sorting specified |
| A5 | Creating/joining a band via API succeeds or fails atomically (no partial state) | Pitfalls, CONTEXT.md | If API returns 201 but doesn't add the band to the user's list, client-side invalidation won't help; this is a backend issue |
| A6 | Invite codes are URL-safe and don't contain spaces | Pitfalls 4, CONTEXT.md | If codes can contain spaces, trim() might break them; preserve as-is and let API validation reject if needed |
| A7 | Phase 1's cache infrastructure (CacheService, Riverpod) is ready | Standard Stack | If Phase 1 is incomplete, band providers won't have anything to depend on; must complete Phase 1 first |

**If this table is empty:** See rows above — all claims depend on API contract accuracy and Phase 1 completion.

## Open Questions

1. **Single `bandsBox` vs. separate per-band boxes**
   - What we know: D-07 says "per-band keyed cache following the same one-box-per-endpoint pattern"; D-02 established one box per endpoint in Phase 1.
   - What's unclear: Does "per-band" mean separate Hive boxes (one per band), or one shared `bandsBox` with per-band keys (e.g., `band_123`)?
   - Recommendation: Use single `bandsBox` with keys `'bands'` (for list) and `'band_{bandId}'` (for detail). Simpler initialization, matches D-02's pattern. If per-band versioning becomes important in Phase 5, refactor then.

2. **Avatar color assignment**
   - What we know: D-06 specifies a reusable `BandAvatar` widget; no color scheme specified.
   - What's unclear: Should avatar colors be deterministic (same band always gets same color) or random?
   - Recommendation: Use deterministic colors based on band name hash: `Color((band.hashCode % colors.length).abs())`. Matches user expectation that "The Clash" always looks the same.

3. **Invite code display format**
   - What we know: Code comes from API as a string; needs to be copyable (D-07).
   - What's unclear: Should it be displayed in uppercase, lowercase, or monospace for clarity?
   - Recommendation: Display in monospace font; preserve API's casing; no formatting applied. Users copy as-is.

4. **After-delete navigation target**
   - What we know: D-15 says "return to Bands list"; what if the user is deep in a navigation stack?
   - What's unclear: Should we pop the detail screen once (back to list) or use `pushReplacementNamed` to clear the stack?
   - Recommendation: `Navigator.of(context).pop()` (simple, predictable) if list is the previous screen; if not, use `pushReplacementNamed('bands')` to ensure we land on the list no matter the navigation history.

5. **Empty bands list state**
   - What we know: D-07 from Phase 1 says follow empty-state pattern; CONTEXT.md defers exact copy to implementation.
   - What's unclear: Should the empty state show a "Create a band" button, or rely on the FAB?
   - Recommendation: Show a centered empty-state card ("No bands yet") with a button to open the Create action menu (same as FAB action). Matches common patterns.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | App runtime | ✓ | ≥3.12.2 | — |
| Dart | Language runtime | ✓ | 3.12.2+ (via Flutter) | — |
| Hive | Local caching (bands_box) | ✓ | 2.2.3 (pubspec.yaml) | None (locked dependency) |
| flutter_riverpod | State management | ✓ | 2.6.1 (pubspec.yaml) | None (locked dependency) |
| http package | HTTP client | ✓ | 1.6.0 (pubspec.yaml) | None (locked dependency) |
| build_runner | Codegen (riverpod providers) | ✓ | 2.5.4 (pubspec.yaml) | None; must run before build |
| Device storage | Hive data persistence | ✓ | Platform-native (iOS/Android) | In-memory (tests only) |

**Missing dependencies with no fallback:** None — all required dependencies are locked in pubspec.yaml from Phase 1.

**Missing dependencies with fallback:** None.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ChangeNotifier + prop drilling | Riverpod providers | Phase 1 | Eliminates manual dependency passing; enables silent background refresh; codegen reduces boilerplate |
| Constructor injection of ApiClient | Provider construction via Riverpod | Phase 1 | Single source of truth for ApiClient config; easier testing with provider overrides |
| No caching (online-only) | Hive-backed cache-first load | Phase 1 | Enables offline read; adds client complexity but unlocks core value (app usable offline) |
| Manual JSON serialization | Raw `Map<String, dynamic>` (no TypeAdapters) | Phase 1 | Reuses same decode path for cache-hit and cache-miss; no schema version migrations |

**Deprecated/outdated:**
- `GetIt` service locator pattern: Riverpod replaces this for state management (Phase 1 decision D-10).
- Hand-written `Provider` declarations: Riverpod codegen with `@riverpod` + `riverpod_generator` is now standard (Phase 1 D-10, locked).
- `shared_preferences` for complex cache: Hive is superior for Map<String, dynamic> storage (Phase 1 D-01).

## Metadata

**Confidence breakdown:**
- **Standard stack: HIGH** — All dependencies locked in pubspec.yaml from Phase 1; Riverpod/Hive versions verified via `pub.dev` registry.
- **Architecture: HIGH** — Phase 1's AsyncNotifier + cache-first pattern is proven; Phase 2 applies it to a new domain with no new techniques.
- **API contract: HIGH** — `publicapi.yml` reviewed; all band endpoints and schemas documented; `ownerId` and `UserProfile.id` fields confirmed present.
- **Pitfalls: MEDIUM** — Derived from careful reading of Phase 1 patterns; some edge cases (invite code whitespace, ownership race conditions) may not surface until execution.
- **Decisions: HIGH** — All locked in CONTEXT.md; no open alternatives being considered.

**Research date:** 2026-08-15
**Valid until:** 2026-09-14 (30 days; Riverpod/Hive ecosystem moves slowly; Phase 2 adds no cutting-edge tech)

---

*Phase: 2-Bands*
*Research completed: 2026-08-15*
*Next: Planning phase (PLAN.md) and execution*
