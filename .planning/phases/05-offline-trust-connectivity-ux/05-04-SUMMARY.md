---
phase: 05-offline-trust-connectivity-ux
plan: 04
subsystem: offline-infra
tags: [riverpod, connectivity_plus, flutter, offline-cache, setlists]

# Dependency graph
requires:
  - phase: 05-offline-trust-connectivity-ux (05-01)
    provides: "isOnlineProvider, OfflineBanner/SyncStatusBadge widgets, cache_service.dart's {data|items, syncedAt} envelope, XSyncedAt notifier pattern"
provides:
  - "SetlistListSyncedAt/SetlistDetailSyncedAt/UserSetlistsSyncedAt companion notifiers on setlists_provider.dart's 3 cache-first providers"
  - "Staleness badges on all 3 Setlists screens (global tab, per-band list, detail)"
  - "Connectivity gating on every Setlists mutation entry point: Add-setlist FAB, Edit icon, Edit/Done toggle (source-blocked entry to reorder/remove), Delete tile, and the 4 in-form/dialog Create/Save/Delete/Add buttons"
affects: [05-05]

# Actuals (#2632)
actuals:
  tokens: 22349
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SetlistListSyncedAt/SetlistDetailSyncedAt/UserSetlistsSyncedAt companion notifiers — 1:1 mirror of 05-01's ProfileSyncedAt/HomepageSyncedAt shape, extended to the family-provider case (SetlistListSyncedAt keyed by bandId, SetlistDetailSyncedAt keyed by (bandId, setlistId))"
    - "D-12 extended from a button to a UI-mode toggle: setlist detail's Edit/Done TextButton can always exit edit mode offline but can't enter it — entry to the mode that exposes reorder/remove is blocked at the source, not just the buttons inside it"
    - "D-14 live-drop collapse: (_editMode && isOnline) swaps ReorderableListView back to the plain read-only ListView the instant connectivity drops mid-session, taking the remove-track icon and Add-tracks button down with it (both live only inside that branch)"

key-files:
  created: []
  modified:
    - lib/providers/setlists_provider.dart
    - lib/providers/setlists_provider.g.dart
    - lib/features/setlists/setlists_screen.dart
    - lib/features/setlists/setlist_list_screen.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - lib/features/setlists/create_setlist_screen.dart
    - lib/features/setlists/edit_setlist_screen.dart
    - lib/features/setlists/confirm_delete_setlist_dialog.dart
    - lib/features/setlists/add_setlist_tracks_dialog.dart
    - test/providers/setlists_provider_test.dart
    - test/features/setlists/setlists_screen_test.dart
    - test/features/setlists/setlist_list_screen_test.dart
    - test/features/setlists/setlist_detail_screen_test.dart
    - test/features/setlists/create_setlist_screen_test.dart
    - test/features/setlists/edit_setlist_screen_test.dart
    - test/features/setlists/confirm_delete_setlist_dialog_test.dart
    - test/features/setlists/add_setlist_tracks_dialog_test.dart

key-decisions:
  - "Left the per-band empty-state 'Add setlist' ElevatedButton in setlist_list_screen.dart ungated, matching the plan's threat register (T-05-09) which scopes gating to the FAB/Edit-icon/Edit-Done-toggle/remove/Delete/Add-tracks list only — the empty-state button's downstream CreateSetlistScreen Create button is already gated (Task 3), providing defense in depth without duplicating the entry-point block"
  - "setlist_detail_screen.dart's Task 1 (badge + Edit-icon gating) and Task 2 (Edit/Done toggle, reorder-branch swap, Delete tile, Add-tracks visibility) landed in one commit — both tasks needed simultaneous changes to build()/_buildContent() (the isOnline parameter threading) to remain compileable as separate commits without a broken intermediate state"
  - "All 8 Setlists test files' wrap() helpers now default isOlineProvider to true — connectivity_plus has no platform-channel mock in the flutter_test environment, so an unoverridden isOnlineProvider resolves to its fail-safe-offline default (AsyncError -> false) and silently broke every pre-existing test that assumed unrestricted mutation capability"

patterns-established:
  - "Family-keyed SyncedAt notifiers (SetlistListSyncedAt(bandId), SetlistDetailSyncedAt(bandId, setlistId)) generalize 05-01's non-family ProfileSyncedAt/HomepageSyncedAt shape for any future per-entity cache-first provider"
  - "D-12/D-14 UI-mode-toggle gating: an offline-sensitive boolean can gate a StatefulWidget's mode flag the same way it gates a button's onPressed — the toggle's own onPressed asymmetrically allows exit but blocks entry, and any UI branch keyed off that mode also gets the isOnline term ANDed in so a live connectivity drop mid-session degrades gracefully instead of leaving a stale mutation surface mounted"

requirements-completed: [OFFL-03, OFFL-04]

coverage:
  - id: D1
    description: "setlists_provider.dart's 3 cache-first providers (SetlistListData/SetlistDetailData/UserSetlistsListData) each expose a companion SyncedAt notifier, set on cache-hit and bumped unconditionally on every successful write (including removeFromList/updateFields/reorderTracks)"
    requirement: "OFFL-04"
    verification:
      - kind: unit
        ref: "test/providers/setlists_provider_test.dart#on a cache hit, {setlistList,setlistDetail,userSetlists}SyncedAtProvider resolves to the pre-seeded cache's syncedAt... then updates to a later value"
        status: pass
    human_judgment: false
  - id: D2
    description: "All 3 Setlists screens (global tab, per-band list, detail) render SyncStatusBadge; the global tab has no FAB (SETL-10 view-only)"
    requirement: "OFFL-04"
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlists_screen_test.dart#SyncStatusBadge is present once the global list loads; no FloatingActionButton is present"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#with isOnlineProvider false, the Edit IconButton is disabled... and SyncStatusBadge is present"
        status: pass
    human_judgment: false
  - id: D3
    description: "Add-setlist FAB (setlist_list_screen.dart) and setlist detail's Edit AppBar icon are disabled + tooltipped offline"
    requirement: "OFFL-03"
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#with isOnlineProvider false, the FAB is disabled with a Requires connection tooltip"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#with isOnlineProvider false, the Edit IconButton is disabled with a Requires connection tooltip"
        status: pass
    human_judgment: false
  - id: D4
    description: "Setlist detail's Edit/Done toggle can exit edit mode offline but cannot enter it (D-12 source block); if connectivity drops while already in edit mode, the ReorderableListView collapses to the plain read-only ListView, taking the remove-track icon and Add-tracks button down with it (D-14)"
    requirement: "OFFL-03"
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#with isOnlineProvider false and _editMode initially false, tapping Edit does not enter edit mode"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#entering edit mode online then connectivity dropping mid-session collapses the ReorderableListView back to a plain read-only ListView and hides the Add tracks button (D-14)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Setlist detail's Delete ListTile and the 4 in-form/dialog mutation buttons (Create, Save, Delete-confirm, Add-tracks) are all disabled + tooltipped offline, with existing non-connectivity guards (empty-selection, _isSubmitting) preserved unchanged"
    requirement: "OFFL-03"
    verification:
      - kind: unit
        ref: "test/features/setlists/setlist_detail_screen_test.dart#with isOnlineProvider false, the Delete ListTile is disabled"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/create_setlist_screen_test.dart, edit_setlist_screen_test.dart, confirm_delete_setlist_dialog_test.dart, add_setlist_tracks_dialog_test.dart — offline/online FilledButton onPressed assertions + empty-selection guard preserved"
        status: pass
    human_judgment: false
  - id: D6
    description: "Backstop truth requiring real-device/visual QA: airplane-mode manual walk of the Setlists tab and a setlist detail screen confirms badge persistence, FAB/Edit-icon/Edit-Done-toggle/Delete-tile inertness, and the mid-session edit-mode collapse, matching 05-01's D6 backstop pattern"
    verification: []
    human_judgment: true
    rationale: "No automated test was planned for real airplane-mode connectivity transitions — this sandboxed environment has no emulator/device to drive a manual walkthrough, consistent with 05-01-SUMMARY.md's D6 rationale."

duration: 52min
completed: 2026-08-17
status: complete
---

# Phase 5 Plan 4: Setlists Offline Trust & Connectivity UX Summary

**Setlists gains the same staleness-badge and connectivity-gated-mutation treatment as Bands/Tracks, extended to a UI-mode toggle: setlist detail's Edit/Done switch is itself blocked at the source offline (D-12), and live-collapses the reorder/remove surface back to a read-only list if connectivity drops mid-session (D-14).**

## Performance

- **Duration:** ~52 min
- **Started:** 2026-08-17 (session start)
- **Completed:** 2026-08-17
- **Tasks:** 3
- **Files modified:** 17 (9 lib files, 8 test files)

## Accomplishments

- `setlists_provider.dart`: `SetlistListSyncedAt`/`SetlistDetailSyncedAt`/`UserSetlistsSyncedAt` companion notifiers, mirroring 05-01's `ProfileSyncedAt`/`HomepageSyncedAt` shape, generalized to the family-provider case; bumped unconditionally on every successful write across `_fetchAndCache`, `removeFromList`, `updateFields`, and `reorderTracks`
- All 3 Setlists screens (global cross-band tab, per-band list, detail) render `SyncStatusBadge` independently
- Add-setlist FAB and setlist detail's Edit AppBar icon disabled + tooltipped offline
- Setlist detail's Edit/Done toggle extends D-12's "entry blocked at source" principle to a UI-mode flag: offline, it can exit edit mode but never enter it; if connectivity drops while already in edit mode, the `ReorderableListView` collapses back to the plain read-only `ListView` (D-14), taking the remove-track icon and "Add tracks" button down with it
- Delete `ListTile` and all 4 in-form/dialog mutation buttons (Create, Save, Delete-confirm, Add-tracks) gated live on `isOnlineProvider`, preserving every pre-existing non-connectivity guard (`_isSubmitting`, empty-track-selection) unchanged

## Task Commits

Each task was committed atomically (with one intentional consolidation — see Deviations):

1. **Task 1 (partial — provider + 2 non-shared screens):** `ba4178d` (feat) — `setlists_provider.dart` syncedAt exposure, `setlists_screen.dart` global badge, `setlist_list_screen.dart` badge + FAB gating
2. **Task 1 (remainder) + Task 2 (combined — shared file):** `772e0b5` (feat) — `setlist_detail_screen.dart` syncedAt badge, Edit-icon gating, Edit/Done toggle source-block, reorder-branch D-14 swap, Delete-tile gating, Add-tracks visibility
3. **Task 3:** `3d8ed0d` (feat) — D-14 live gating on `create_setlist_screen.dart`, `edit_setlist_screen.dart`, `confirm_delete_setlist_dialog.dart`, `add_setlist_tracks_dialog.dart`

**Plan metadata:** (this commit, once created)

## Files Created/Modified

- `lib/providers/setlists_provider.dart` / `.g.dart` — 3 `SyncedAt` companion notifiers wired into `build()`/`_fetchAndCache()`/mutation methods
- `lib/features/setlists/setlists_screen.dart` — `SyncStatusBadge` in the `data:` branch (view-only, no FAB)
- `lib/features/setlists/setlist_list_screen.dart` — `SyncStatusBadge` + FAB gated on `isOnlineProvider`
- `lib/features/setlists/setlist_detail_screen.dart` — `SyncStatusBadge`, Edit icon, Edit/Done toggle (D-12), reorder/read-only branch swap (D-14), Delete tile, "Add tracks" visibility all gated
- `lib/features/setlists/create_setlist_screen.dart` — Create `FilledButton` gated (D-14)
- `lib/features/setlists/edit_setlist_screen.dart` — Save `FilledButton` gated (D-14)
- `lib/features/setlists/confirm_delete_setlist_dialog.dart` — Delete `FilledButton` gated, `_isSubmitting` guard preserved
- `lib/features/setlists/add_setlist_tracks_dialog.dart` — Add `FilledButton` gated, empty-selection guard preserved
- 8 test files extended with `isOnlineProvider` overrides and new offline/online assertions

## Decisions Made

- Left `setlist_list_screen.dart`'s empty-state "Add setlist" `ElevatedButton` ungated — the plan's threat register (T-05-09) scopes gating explicitly to the FAB/Edit-icon/Edit-Done-toggle/remove/Delete/Add-tracks list, and this button's downstream `CreateSetlistScreen` Create button is already gated by Task 3, giving defense in depth without a redundant entry-point block outside plan scope
- Combined setlist_detail_screen.dart's Task 1 and Task 2 work into one commit (`772e0b5`) — both tasks required simultaneous changes to `build()`/`_buildContent()` (the `isOnline` parameter threading) to keep the file in a compiling state; splitting them would have required an artificial intermediate signature
- Defaulted every Setlists test file's `wrap()` helper to `isOnlineProvider.overrideWithValue(true)` unless a test explicitly overrides it — `connectivity_plus` has no platform-channel mock under `flutter_test`, so an unoverridden `isOnlineProvider` resolves to its fail-safe-offline default and silently broke every pre-existing mutation-path test

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Defaulted `isOnlineProvider` to `true` in all 8 Setlists test files' `wrap()` helpers**
- **Found during:** Task 1 verification (`setlist_detail_screen_test.dart` — 6 pre-existing tests failed after adding `isOnline`-gated `onPressed` to the Edit icon and Edit/Done toggle)
- **Issue:** None of the 8 Setlists test files' `ProviderScope` overrides included `isOnlineProvider`. Under `flutter_test`, `connectivity_plus`'s platform channel is unmocked, so `connectivityProvider`/`isOnlineProvider` resolve to `AsyncError` -> fail-safe `false` (05-01's documented fail-safe-offline default). Every pre-existing test that tapped a now-gated control (Edit, FAB, Create, Save, Delete, Add) started failing because `onPressed` was unexpectedly `null`.
- **Fix:** Changed each `wrap()` helper's signature to accept an `isOnline` parameter defaulting to `true`, and added `isOnlineProvider.overrideWithValue(isOnline)` to each `ProviderScope`'s overrides.
- **Files modified:** `test/features/setlists/setlist_detail_screen_test.dart`, `create_setlist_screen_test.dart`, `edit_setlist_screen_test.dart`, `confirm_delete_setlist_dialog_test.dart`, `add_setlist_tracks_dialog_test.dart`, `setlist_list_screen_test.dart`
- **Verification:** Full `flutter test` (252 tests) and `flutter analyze` (zero issues) pass.
- **Committed in:** `772e0b5` (setlist_detail_screen_test.dart), `3d8ed0d` (the 4 in-form/dialog test files); `setlist_list_screen_test.dart`'s equivalent fix landed in `ba4178d`.

---

**Total deviations:** 1 auto-fixed (blocking test-infrastructure fix, spanning all Task 1–3 test files)
**Impact on plan:** Necessary to keep every task's `flutter test`/`flutter analyze` acceptance criteria passing; no scope creep — the fix only extends `wrap()` helpers to override a provider the plan's own gating logic newly depends on, using the exact override-default pattern `offline_banner_test.dart` (05-01) already established.

## Issues Encountered

- `05-03`'s `tracks_provider.dart`/screens (this plan's stated `read_first` reference for the `SyncedAt` companion pattern) had not yet merged into this worktree at execution time — Wave 2 plans run in parallel sibling worktrees. Used `profile_provider.dart`/`homepage_provider.dart` (05-01, already merged) as the reference implementation instead; the resulting `SetlistListSyncedAt`/`SetlistDetailSyncedAt`/`UserSetlistsSyncedAt` shape is identical to what the plan specified verbatim in its `<action>` block, so no functional deviation resulted.
- `ProviderContainer.updateOverrides()` combined with `isOnlineProvider.overrideWith((ref) => ...)` did not trigger a widget rebuild on the "connectivity drops mid-session" test (Riverpod's docs note `updateOverrides` reliably rebuilds listeners only for `overrideWithValue`, not `overrideWith`) — switched both the initial `ProviderContainer` override and the mid-test `updateOverrides` call to `overrideWithValue`, which resolved it.
- No other issues — `flutter test` (252 tests, full suite) and `flutter analyze` (zero issues) both pass at the end of every task.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Setlists now matches Bands (05-02) and Tracks (05-03)'s offline-trust treatment; all three entity types + Profile/Home (05-01) share the identical `SyncedAt`/`isOnlineProvider` pattern.
- 05-05 (final phase verification/manual walkthrough pass) can proceed — every OFFL-03/OFFL-04 mutation-gating and staleness-badge surface across the app is now wired.
- Manual/backstop verification (D6 in coverage: real airplane-mode walkthrough of the Setlists tab and a setlist detail screen, including the mid-session edit-mode collapse) still needs a real device/emulator pass — flagged `human_judgment: true`, not blocking for this plan's completion, consistent with 05-01's D6 precedent.

---
*Phase: 05-offline-trust-connectivity-ux*
*Completed: 2026-08-17*

## Self-Check: PASSED

All key created/modified files verified present on disk; all 3 commit hashes (`ba4178d`, `772e0b5`, `3d8ed0d`) verified present in `git log --oneline --all`.
