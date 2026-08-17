---
phase: 03-tracks
plan: 01
subsystem: tracks
tags: [riverpod, hive-cache, tracks, family-provider]
dependency graph:
  requires: [lib/providers/bands_provider.dart, lib/cache/cache_service.dart, lib/api/public_api.dart]
  provides: [TrackListData, TrackDetailData, TrackListScreen, CreateTrackScreen, TrackDetailScreen]
  affects: [lib/features/bands/band_detail_screen.dart]
tech-stack:
  added: []
  patterns: [family-AsyncNotifier-per-band, tracksBox-Hive-store, cache-first-loading]
key-files:
  created:
    - lib/providers/tracks_provider.dart
    - lib/features/tracks/track_formatting.dart
    - lib/features/tracks/track_list_screen.dart
    - lib/features/tracks/create_track_screen.dart
    - lib/features/tracks/track_detail_screen.dart
    - test/providers/tracks_provider_test.dart
    - test/features/tracks/track_list_screen_test.dart
    - test/features/tracks/create_track_screen_test.dart
    - test/features/tracks/track_detail_screen_test.dart
  modified:
    - lib/cache/cache_service.dart
    - lib/api/public_api.dart
    - lib/features/bands/band_detail_screen.dart
    - test/cache/cache_service_test.dart
    - test/providers/auth_provider_test.dart
decisions:
  - "03-01: TrackListData/TrackDetailData keep the _version WR-02 guard field-for-field per bands_provider.dart, even though no local-mutation method exists yet to bump it in this plan (edit/delete land in Plans 02/03) — left non-final to match the mirrored shape those later plans will extend."
metrics:
  duration: 45min
  completed: 2026-08-16
actuals:
  tokens: 17963
  tasks: 2
  commits: 2
status: complete
---

# Phase 03 Plan 01: Track catalog end-to-end (view, add, detail) Summary

Stood up the per-band track catalog tracer slice: `TrackListData`/`TrackDetailData` Riverpod family providers backed by a new `tracksBox` Hive store, three new screens (`TrackListScreen`, `CreateTrackScreen`, `TrackDetailScreen`), and a "Tracks" nav entry on `BandDetailScreen` visible to every band member — proving the Riverpod + Hive cache-store pattern generalizes to a third per-band-keyed entity.

## What Was Built

- **`lib/cache/cache_service.dart`**: added `_tracksStore` (fourth backing store, threaded through the constructor, `inMemory()`, and `initialize()` opening `tracksBox`), plus `readBandTracks`/`writeBandTracks` (keyed `band_$bandId`) and `readBandTrackDetail`/`writeBandTrackDetail` (keyed via `_trackDetailKey` = `detail_${bandId}_$trackId`), mirroring the bands equivalents exactly. `clearAll()` now also clears `_tracksStore`.
- **`lib/api/public_api.dart`**: added `listBandTracks(bandId)` (`GET /api/band/{bandId}/track/list`), `getBandTrack(bandId, trackId)` (`GET /api/band/{bandId}/track/{trackId}`), and `createBandTrack({bandId, title, artist, durationSeconds, tempo, key, notes})` (`POST /api/band/{bandId}/track`, optional fields included only when non-null) — all field names verified against `publicapi.yml`'s `TrackListItem`/`BandTrack`/`CreateBandTrackRequestBody`/`CreateBandTrackResponseBody` schemas.
- **`lib/providers/tracks_provider.dart`** (new): `TrackListData` (family keyed by `bandId`) and `TrackDetailData` (family keyed by `(bandId, trackId)`), each mirroring `BandsListData`/`BandDetailData` field-for-field — cache-first `build()`, silent background `_refresh()`, deduped user-initiated `refresh()`, and the WR-02 `_version` guard.
- **`lib/features/tracks/track_formatting.dart`** (new): `DurationFormatting` extension (`asMinutesSeconds` mm:ss getter) and the 24-value `musicalKeys` constant (12 root notes × major/minor, D-10).
- **`lib/features/tracks/track_list_screen.dart`** (new): populated/empty/error states mirroring `BandsScreen`; FAB and empty-state CTA both push `CreateTrackScreen`; row tap pushes `TrackDetailScreen`.
- **`lib/features/tracks/create_track_screen.dart`** (new): 6-field full-screen form (title/artist required, duration/tempo/key/notes optional) mirroring `CreateBandScreen`'s submit/dispose/error-handling structure; on success invalidates `trackListDataProvider(bandId)`, shows a SnackBar, and does a plain `pop()` back to the list (no `pushReplacement`, per D-08/D-09 — this screen was pushed from the list, not from a create flow needing to land on a detail screen).
- **`lib/features/tracks/track_detail_screen.dart`** (new): displays title/artist/duration/tempo/key/notes; no edit/delete UI yet (Plan 02 scope).
- **`lib/features/bands/band_detail_screen.dart`**: added a "Tracks" `ListTile` after the Invite code section and before the `isOwner`-gated blocks — verified via grep that it is NOT nested inside an ownership conditional, since TRACK-01/02/03 carry no owner qualifier.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `_FakeCacheService implements CacheService` in `auth_provider_test.dart` failed to compile**
- **Found during:** Task 1 (`flutter analyze` after adding the four new `CacheService` methods)
- **Issue:** `test/providers/auth_provider_test.dart`'s spy double implements the full `CacheService` interface; adding `readBandTracks`/`writeBandTracks`/`readBandTrackDetail`/`writeBandTrackDetail` to the real class left the fake missing four required overrides (`non_abstract_class_inherits_abstract_member`).
- **Fix:** Added matching in-memory-map-backed implementations of all four methods to `_FakeCacheService`, plus clearing them in its `clearAll()` override.
- **Files modified:** `test/providers/auth_provider_test.dart`
- **Commit:** 2fd3156

No other deviations — plan executed as written.

## Known Stubs

None. All artifacts specified in `must_haves.artifacts` are wired end-to-end and covered by passing tests.

## Verification

- `flutter analyze`: 0 errors/warnings (6 pre-existing-pattern info-level lints: `use_null_aware_elements` on the new `createBandTrack` optional-field map literal, `prefer_final_fields` on `TrackListData`/`TrackDetailData`'s `_version` field — left non-final since Plans 02/03 will add local-mutation methods that bump it, matching the mirrored `bands_provider.dart` shape).
- `flutter test` (full suite): 112 passed, 0 failed — zero regressions in Phase 1/2 tests.
- Acceptance-criteria greps (all matched): `_tracksStore` threaded through constructor/`inMemory()`/`initialize()`; `TrackListData`/`TrackDetailData` classes present; `listBandTracks`/`getBandTrack`/`createBandTrack` signatures present; "Tracks" `ListTile` confirmed not nested inside an `isOwner` block.

## Self-Check: PASSED

- FOUND: lib/providers/tracks_provider.dart
- FOUND: lib/providers/tracks_provider.g.dart
- FOUND: lib/features/tracks/track_formatting.dart
- FOUND: lib/features/tracks/track_list_screen.dart
- FOUND: lib/features/tracks/create_track_screen.dart
- FOUND: lib/features/tracks/track_detail_screen.dart
- FOUND: test/providers/tracks_provider_test.dart
- FOUND: test/features/tracks/track_list_screen_test.dart
- FOUND: test/features/tracks/create_track_screen_test.dart
- FOUND: test/features/tracks/track_detail_screen_test.dart
- FOUND commit 2fd3156 (feat(03-01): stand up per-band track catalog end-to-end)
- FOUND commit f2ce293 (test(03-01): add track cache-store coverage and edge-state tests)
