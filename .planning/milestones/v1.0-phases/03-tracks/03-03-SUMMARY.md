---
phase: 03-tracks
plan: 03
subsystem: tracks
tags: [riverpod, hive-cache, tracks, cross-band-aggregate]
dependency graph:
  requires: [lib/providers/bands_provider.dart, lib/providers/tracks_provider.dart, lib/api/api_client.dart, lib/cache/cache_service.dart, lib/features/tracks/track_detail_screen.dart, lib/features/tracks/track_formatting.dart]
  provides: [TracksScreen, SelectedBandIdFilter, UserTracksListData, PublicApi.listUserTracks, ApiClient.queryParameters, CacheService.readUserTracks, CacheService.writeUserTracks]
  affects: [lib/navigation/root_scaffold.dart]
tech-stack:
  added: []
  patterns: [cross-entity-aggregate-provider, query-parameter-threading, add-alongside-not-promote]
key-files:
  created:
    - lib/features/songs/tracks_screen.dart
    - test/features/tracks/tracks_screen_test.dart
  modified:
    - lib/api/api_client.dart
    - lib/api/public_api.dart
    - lib/cache/cache_service.dart
    - lib/providers/tracks_provider.dart
    - lib/navigation/root_scaffold.dart
    - test/providers/tracks_provider_test.dart
    - test/cache/cache_service_test.dart
    - test/providers/auth_provider_test.dart
  deleted:
    - lib/features/songs/songs_screen.dart
decisions:
  - "03-03: Added SelectedBandIdFilter.setFilter(bandId) as a public method instead of the plan's literal `notifier.state = value` instruction — the latter fails flutter analyze (invalid_use_of_protected_member/visible_for_testing) when called from outside the notifier, matching the precedent BandsListData.setBands() established in 02-03 for the same reason."
metrics:
  duration: 35min
  completed: 2026-08-16
actuals:
  tokens: 8388
  tasks: 2
  commits: 2
status: complete
---

# Phase 03 Plan 03: Global cross-band Tracks tab Summary

Closed TRACK-06 (the last Phase 3 requirement) by repurposing the placeholder "Songs" bottom-nav tab into "Tracks": a flat, cross-band track list backed by a new `GET /api/track/list` endpoint, a band-name badge per row, and a filter dropdown that narrows the list to one band — proving the "add-alongside, not promote" pattern for a cross-entity aggregate view layered on top of Phase 3's existing per-band-scoped `(bandId, trackId)` identity model.

## What Was Built

- **`lib/api/api_client.dart`**: `send()` gained an optional `Map<String, String>? queryParameters` parameter; the URI construction changed from `Uri.parse('$baseUrl$path')` to `Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters)`, which is a no-op on every existing call site since none pass the new argument.
- **`lib/api/public_api.dart`**: added `listUserTracks({String? bandIdFilter})` (`GET /api/track/list`, optional `bandId` query param), returning `UserTrackListItem` maps (id/title/artist/durationSeconds/bandId/bandName).
- **`lib/cache/cache_service.dart`**: added `readUserTracks(bandIdFilter)`/`writeUserTracks(bandIdFilter, data)` on the existing `_tracksStore`, keyed via `_userTracksKey` (`user_tracks_all` or `user_tracks_{bandId}`) — distinct from the per-band `band_$bandId` key so the two never collide.
- **`lib/providers/tracks_provider.dart`**: added `SelectedBandIdFilter` (plain provider, `null` = all bands, with a `setFilter()` method — see Deviations) and `UserTracksListData` (plain, non-family `AsyncNotifier` mirroring `TrackListData`'s cache-first/`_version`/dedup shape, but `build()` watches `selectedBandIdFilterProvider` so a filter change automatically triggers a full rebuild with the new cache key/fetch — no manual invalidation needed).
- **`lib/features/songs/tracks_screen.dart`** (new, replaces `songs_screen.dart`): `TracksScreen extends ConsumerWidget`. Watches `bandsListDataProvider`; when the resolved band list is empty, renders the "No tracks" empty state directly with a visual-only "View bands" button and no dropdown. When ≥1 band exists, renders a `DropdownButton<String?>` ("All bands" + one entry per band) above the list; selecting an entry calls `SelectedBandIdFilter.setFilter()`. Populated rows show a `Chip` band badge, title, artist, and formatted duration; tapping a row pushes `TrackDetailScreen(bandId: track['bandId'], trackId: track['id'])` (Plan 01's detail screen, reused unmodified). Error state matches `TrackListScreen`'s "Couldn't load tracks" + Retry copy exactly.
- **`lib/navigation/root_scaffold.dart`**: import, widget instantiation, and `NavigationDestination` label all changed from `SongsScreen`/`'Songs'` to `TracksScreen`/`'Tracks'`; icons unchanged.
- **`lib/features/songs/songs_screen.dart`**: deleted (fully replaced by `tracks_screen.dart`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `SelectedBandIdFilter` needed a public `setFilter()` method instead of the plan's literal `notifier.state = value` call site**
- **Found during:** Task 1, `flutter analyze` after wiring the dropdown's `onChanged`
- **Issue:** The plan's literal instruction (`ref.read(selectedBandIdFilterProvider.notifier).state = v`) fails `flutter analyze` with `invalid_use_of_protected_member`/`invalid_use_of_visible_for_testing_member` — Riverpod's generated `Notifier.state` setter is protected and can't be assigned from outside the notifier class.
- **Fix:** Added `SelectedBandIdFilter.setFilter(String? bandId) => state = bandId;` and called that from the widget instead — the exact same pattern the codebase already established for `BandsListData.setBands()` in 02-03, for the identical reason.
- **Files modified:** `lib/providers/tracks_provider.dart`, `lib/features/songs/tracks_screen.dart`
- **Commit:** 923b019

**2. [Rule 3 - Blocking] `_FakeCacheService implements CacheService` in `auth_provider_test.dart` failed to compile**
- **Found during:** Task 1 (`flutter analyze` after adding `readUserTracks`/`writeUserTracks` to `CacheService`)
- **Issue:** Same pattern as 03-01's deviation #1 — the test's full-interface spy double was missing the two new required overrides (`non_abstract_class_inherits_abstract_member`).
- **Fix:** Added matching in-memory-map-backed implementations of `readUserTracks`/`writeUserTracks` to `_FakeCacheService`, plus clearing the new map in its `clearAll()` override.
- **Files modified:** `test/providers/auth_provider_test.dart`
- **Commit:** 923b019

No other deviations — the rest of the plan executed as written.

## Known Stubs

None. All artifacts specified in `must_haves.artifacts` are wired end-to-end (real `GET /api/track/list` call, real cache read/write, real navigation to `TrackDetailScreen`) and covered by passing tests.

## Verification

- `flutter analyze`: 0 errors/warnings (15 pre-existing-pattern info-level `use_null_aware_elements`/`prefer_final_fields` lints, same style already present from Plans 01/02).
- `flutter test` (full suite): 135 passed, 0 failed — zero regressions in Phase 1/2/3.
- Acceptance-criteria greps (all matched): `queryParameters` threaded into `send()`'s signature and the `Uri.replace` call; `Future<List<Map<String, dynamic>>> listUserTracks` present in `public_api.dart`; `grep -c "SongsScreen" root_scaffold.dart` = `0`; `grep -c "TracksScreen" root_scaffold.dart` = `1`; `lib/features/songs/songs_screen.dart` confirmed deleted.
- Widget behavior confirmed by tests: `TracksScreen` with 0 bands renders the empty state with no `DropdownButton<String?>`; a populated cross-band list shows both bands' badges/titles/artists/durations; selecting a band in the dropdown re-issues `listUserTracks` with that band's id as the `bandId` query parameter; a network failure with no cache shows "Couldn't load tracks" + Retry.
- Provider behavior confirmed by tests: `UserTracksListData` cache-hit-with-background-refresh, no-cache-network-failure → `AsyncError`, two rapid `refresh()` calls → one network call, and a `selectedBandIdFilterProvider` state change → a rebuild whose `listUserTracks` call carries the new `bandId` filter.
- Cache behavior confirmed by tests: `writeUserTracks`/`readUserTracks` round-trip both the `null`-filter (`user_tracks_all`) and a specific-`bandIdFilter` (`user_tracks_{id}`) cache entries without colliding with each other or with Plan 01's band-scoped `tracksBox` entries.

## Self-Check: PASSED

- FOUND: lib/features/songs/tracks_screen.dart
- FOUND: test/features/tracks/tracks_screen_test.dart
- MISSING (expected — deleted by design): lib/features/songs/songs_screen.dart
- FOUND commit 923b019 (feat(03-03): add global cross-band Tracks tab (TRACK-06))
- FOUND commit 72828bf (test(03-03): add global tracks test coverage and cache round-trip)
