---
phase: 05-offline-trust-connectivity-ux
plan: 03
subsystem: offline-infra
tags: [riverpod, connectivity_plus, hive, flutter, offline-cache, tracks]

# Dependency graph
requires:
  - phase: 05-offline-trust-connectivity-ux
    provides: "isOnlineProvider (05-01) — single global connectivity signal; SyncStatusBadge widget; cache_service.dart's {data|items, syncedAt} envelope + readXSyncedAt() methods for all Tracks cache keys"
provides:
  - "TrackListSyncedAt/TrackDetailSyncedAt/UserTracksSyncedAt companion Riverpod notifiers on tracks_provider.dart"
  - "SyncStatusBadge wired into all 3 Tracks screens (global tab, per-band list, detail), independently timestamped"
  - "isOnlineProvider-gated Add-track FAB and Edit/Delete controls on track_list_screen.dart/track_detail_screen.dart"
  - "Live connectivity reactivity (D-14) on create/edit/delete Tracks Save/Delete buttons"
affects: [05-04, tracks-provider, tracks-screens]

# Actuals (#2632)
actuals:
  tokens: 17652
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TrackListSyncedAt/TrackDetailSyncedAt (family)/UserTracksSyncedAt (plain) companion notifiers replicate 05-01's ProfileSyncedAt/HomepageSyncedAt shape 1:1 for a family provider — build() => null, public set() method, bumped unconditionally in _fetchAndCache() and in every local-mutation method that also calls its paired write*() (removeFromList, updateFields)"
    - "Test wrap() helpers gained an isOnline (default true) override param wherever a screen/form now watches isOnlineProvider — isOnlineProvider resolves fail-safe-false in flutter_test (connectivity_plus has no platform-channel mock registered), so every pre-existing test exercising a now-gated button needed this override to keep passing"

key-files:
  created: []
  modified:
    - lib/providers/tracks_provider.dart
    - lib/features/songs/tracks_screen.dart
    - lib/features/tracks/track_list_screen.dart
    - lib/features/tracks/track_detail_screen.dart
    - lib/features/tracks/create_track_screen.dart
    - lib/features/tracks/edit_track_screen.dart
    - lib/features/tracks/confirm_delete_track_dialog.dart

key-decisions:
  - "05-02 (Bands, sibling wave-2 plan) was executing concurrently in its own worktree and its bands_provider.dart/create_band_screen.dart changes were not visible in this worktree — implemented the SyncedAt/isOnline patterns independently from 05-01's Profile/Home precedent (profile_provider.dart's ProfileSyncedAt shape) rather than reading 05-02's actual code, per the plan's literal action text"
  - "Confirmed empirically (via a throwaway widget-test probe) that isOnlineProvider resolves to false by default inside flutter_test — connectivity_plus has no platform-channel mock registered in this test environment, so checkConnectivity() throws MissingPluginException and the fail-safe-offline default kicks in. Every pre-existing test that taps a now-isOnline-gated button therefore required its wrap() helper to gain an isOnline (default true) override to keep passing — documented as a deviation below"

patterns-established:
  - "Same TrackListSyncedAt/TrackDetailSyncedAt/UserTracksSyncedAt shape is now proven for family + plain SyncedAt notifiers together in one provider file — any future cached provider can copy either shape directly"

requirements-completed: [OFFL-03, OFFL-04]

coverage:
  - id: D1
    description: "tracks_provider.dart gains TrackListSyncedAt (family)/TrackDetailSyncedAt (family)/UserTracksSyncedAt (plain) companion notifiers, set from cache on cache-hit and bumped unconditionally on every successful write (_fetchAndCache, removeFromList, updateFields)"
    requirement: "OFFL-04"
    verification:
      - kind: unit
        ref: "test/providers/tracks_provider_test.dart#trackListSyncedAtProvider/trackDetailSyncedAtProvider/userTracksSyncedAtProvider resolve cached syncedAt and update after refresh"
        status: pass
    human_judgment: false
  - id: D2
    description: "All 3 Tracks screens (global cross-band tab, per-band list, detail) show independently-timestamped SyncStatusBadge; the global tab has no FAB (view-only, TRACK-06)"
    requirement: "OFFL-04"
    verification:
      - kind: automated_ui
        ref: "test/features/tracks/tracks_screen_test.dart#populated cross-band list — SyncStatusBadge found, FloatingActionButton absent"
        status: pass
    human_judgment: false
  - id: D3
    description: "track_list_screen.dart's Add-track FAB and track_detail_screen.dart's Edit icon/Delete tile are source-blocked (onPressed/onTap: null) with a 'Requires connection' tooltip while isOnlineProvider is false"
    requirement: "OFFL-03"
    verification:
      - kind: automated_ui
        ref: "test/features/tracks/track_list_screen_test.dart#FAB disabled/enabled by isOnlineProvider; test/features/tracks/track_detail_screen_test.dart#Edit IconButton + Delete ListTile disabled/enabled by isOnlineProvider"
        status: pass
    human_judgment: false
  - id: D4
    description: "create_track_screen.dart/edit_track_screen.dart/confirm_delete_track_dialog.dart's Save/Delete FilledButton watches isOnlineProvider live (D-14) — disables immediately if connectivity drops after the form/dialog is already open, with tooltip + label swap to 'Requires connection'"
    requirement: "OFFL-03"
    verification:
      - kind: automated_ui
        ref: "test/features/tracks/create_track_screen_test.dart, edit_track_screen_test.dart, confirm_delete_track_dialog_test.dart#Save/Delete button disabled/enabled by isOnlineProvider"
        status: pass
    human_judgment: false
  - id: D5
    description: "Backstop truth requiring real-device/visual QA: airplane-mode manual walk of all 3 Tracks screens confirms FAB/Edit/Delete grey out with visible tooltips"
    verification: []
    human_judgment: true
    rationale: "No automated test was planned for the visual/manual airplane-mode walkthrough — this sandboxed worktree has no emulator/device to drive it, mirroring 05-01's D6 backstop item."

duration: ~55min
completed: 2026-08-17
status: complete
---

# Phase 5 Plan 3: Tracks Offline Trust & Connectivity UX Summary

**Tracks entity gains the same Wave-1 staleness-badge and Wave-2 connectivity-gated-mutation shape proven on Bands (05-02) and Profile/Home (05-01): per-cache-key `syncedAt` on `tracks_provider.dart`, `SyncStatusBadge` on all 3 Tracks screens, and `isOnlineProvider`-gated Add-track FAB / Edit / Delete with live in-form reactivity.**

## Performance

- **Duration:** ~55 min
- **Tasks:** 2
- **Files modified:** 7 lib files + 6 test files (13 total)

## Accomplishments

- `tracks_provider.dart`: `TrackListSyncedAt` (family, keyed per `bandId`), `TrackDetailSyncedAt` (family, keyed per `(bandId, trackId)`), and `UserTracksSyncedAt` (plain) companion notifiers — set from cache on cache-hit, bumped unconditionally inside `_fetchAndCache()` and inside the two existing local-mutation methods (`removeFromList`, `updateFields`) right after their paired `write*()` calls
- All 3 Tracks screens (`tracks_screen.dart` global tab, `track_list_screen.dart` per-band, `track_detail_screen.dart`) now render `SyncStatusBadge` with independent timestamps; the global tab stays mutation-free (TRACK-06) with no gating added
- `track_list_screen.dart`'s Add-track FAB and `track_detail_screen.dart`'s Edit icon + Delete tile are source-blocked (`onPressed`/`onTap: null`) with a "Requires connection" tooltip while offline (D-12/D-13)
- `create_track_screen.dart`, `edit_track_screen.dart`, `confirm_delete_track_dialog.dart`'s Save/Delete `FilledButton` watches `isOnlineProvider` live (D-14) — a connectivity drop after the form is already open disables the button immediately, independent of `_isSubmitting`

## Task Commits

Each task was committed atomically:

1. **Task 1: Tracks syncedAt exposure + staleness badges (3 screens) + source-blocked FAB/Edit/Delete** - `b98495b` (feat)
2. **Task 2: Live connectivity reactivity (D-14) on the 3 in-form/in-dialog Tracks mutation buttons** - `1065b3c` (feat)

**Plan metadata:** (this commit, once created)

## Files Created/Modified

- `lib/providers/tracks_provider.dart` - `TrackListSyncedAt`/`TrackDetailSyncedAt`/`UserTracksSyncedAt` companion notifiers, wired into `build()`/`_fetchAndCache()`/`removeFromList()`/`updateFields()`
- `lib/features/songs/tracks_screen.dart` - `SyncStatusBadge` in the global tab's `data:` branch (no gating, view-only)
- `lib/features/tracks/track_list_screen.dart` - `SyncStatusBadge` + Add-track FAB gated on `isOnlineProvider`
- `lib/features/tracks/track_detail_screen.dart` - `SyncStatusBadge` + Edit `IconButton`/Delete `ListTile` gated on `isOnlineProvider`
- `lib/features/tracks/create_track_screen.dart` - Save `FilledButton` gated live on `isOnlineProvider` (D-14)
- `lib/features/tracks/edit_track_screen.dart` - Save `FilledButton` gated live on `isOnlineProvider` (D-14)
- `lib/features/tracks/confirm_delete_track_dialog.dart` - Delete `FilledButton` gated live on `isOnlineProvider` (D-14), existing `_isSubmitting` gating preserved
- `test/providers/tracks_provider_test.dart` - 3 new `*SyncedAt` cache-hit + post-refresh assertions
- `test/features/tracks/tracks_screen_test.dart` - `SyncStatusBadge` present / `FloatingActionButton` absent assertion
- `test/features/tracks/track_list_screen_test.dart` - `wrap()` gained `isOnline` override param; 2 new FAB-gating tests
- `test/features/tracks/track_detail_screen_test.dart` - `wrap()` gained `isOnline` override param; 2 new Edit/Delete-gating tests
- `test/features/tracks/create_track_screen_test.dart` - `wrap()` gained `isOnline` override param; 2 new Save-button-gating tests
- `test/features/tracks/edit_track_screen_test.dart` - `wrap()` gained `isOnline` override param; 2 new Save-button-gating tests
- `test/features/tracks/confirm_delete_track_dialog_test.dart` - `wrap()` gained `isOnline` override param; 2 new Delete-button-gating tests

## Decisions Made

- 05-02 (Bands) was executing concurrently in a sibling worktree and its `bands_provider.dart`/`create_band_screen.dart` changes weren't visible here, so the `SyncedAt`/`isOnline` patterns were implemented directly from the plan's literal action text and 05-01's Profile/Home precedent, not by reading 05-02's committed code
- Confirmed empirically (throwaway probe test) that `isOnlineProvider` resolves fail-safe-`false` by default inside `flutter_test` — `connectivity_plus` has no platform-channel mock registered in this environment. Documented as a deviation below since it required touching every affected test file's `wrap()` helper.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added `isOnline` override param to `wrap()` in all 5 Tracks screen/form/dialog test files**
- **Found during:** Task 1 verification (track_list_screen_test.dart, track_detail_screen_test.dart) and Task 2 verification (create_track_screen_test.dart, edit_track_screen_test.dart, confirm_delete_track_dialog_test.dart)
- **Issue:** None of these test files' `wrap()` helpers overrode `isOnlineProvider`. Once the FAB/Edit-icon/Delete-tile/Save-button `onPressed`/`onTap` became gated on `isOnlineProvider`, every pre-existing test that taps one of those controls started failing — `isOnlineProvider` resolves to `false` by default in `flutter_test` (no `connectivity_plus` platform-channel mock is registered, so `checkConnectivity()` throws `MissingPluginException` and the provider's documented fail-safe-offline default applies), disabling the button the test expected to be enabled.
- **Fix:** Added an `isOnline` parameter (default `true`) to each affected `wrap()` helper (and to the two inline `ProviderScope` blocks used by the CR-03 "invalidates global tab" tests in `create_track_screen_test.dart`/`edit_track_screen_test.dart`/`confirm_delete_track_dialog_test.dart`), overriding `isOnlineProvider` so existing tests keep exercising the "online" path unchanged while new tests explicitly pass `isOnline: false` to prove the gating.
- **Files modified:** `test/features/tracks/track_list_screen_test.dart`, `test/features/tracks/track_detail_screen_test.dart`, `test/features/tracks/create_track_screen_test.dart`, `test/features/tracks/edit_track_screen_test.dart`, `test/features/tracks/confirm_delete_track_dialog_test.dart`
- **Verification:** Full `flutter test` suite (247 tests) passes; `flutter analyze` reports zero issues.
- **Committed in:** `b98495b` (Task 1, track_list/track_detail test files) and `1065b3c` (Task 2, create/edit/confirm-delete test files)

---

**Total deviations:** 1 auto-fixed (blocking test-compatibility fix, applied across 5 files)
**Impact on plan:** Necessary to keep every task's `flutter test`/`flutter analyze` acceptance criteria green. No scope creep — the fix only extends existing test helpers to explicitly control a provider that source code now reads, matching the exact intent of the plan's new gating assertions.

## Issues Encountered

- 05-02 (Bands, sibling wave-2 plan) was executing concurrently in its own worktree; its `bands_provider.dart` still showed the pre-05-02 shape from this worktree's perspective throughout this plan's execution. This is expected wave-parallel isolation (each worktree has an independent copy of `main` at dispatch time) — not a blocker, since 05-03's plan text specifies the target pattern in full detail independent of 05-02's actual diff.
- No other issues — `flutter test` (247 tests, full suite) and `flutter analyze` (zero issues) both pass at the end of every task.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `TrackListSyncedAt`/`TrackDetailSyncedAt`/`UserTracksSyncedAt` and the `isOnlineProvider`-gated FAB/Edit/Delete/Save patterns are now proven for a third entity (after Profile/Home in 05-01) — 05-04 (Setlists, if following the same shape) can copy this plan's tracks_provider.dart diff almost verbatim.
- Manual/backstop verification (D5 in coverage: airplane-mode walkthrough of all 3 Tracks screens) still needs a real device/emulator pass — flagged `human_judgment: true`, not blocking for this plan's completion, mirroring 05-01's D6 backstop item.
- This plan's diff does not touch `bands_provider.dart`/Bands screens (05-02's scope) or Setlists (05-04's scope) — no merge-conflict risk expected beyond the standard wave-parallel worktree merge.

---
*Phase: 05-offline-trust-connectivity-ux*
*Completed: 2026-08-17*

## Self-Check: PASSED

All modified files verified present on disk; both commit hashes (`b98495b`, `1065b3c`) verified present in `git log --oneline --all`.
