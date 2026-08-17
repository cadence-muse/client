---
phase: 05-offline-trust-connectivity-ux
plan: 02
subsystem: offline-infra
tags: [riverpod, flutter, offline-cache, connectivity, bands]

# Dependency graph
requires:
  - phase: 05-offline-trust-connectivity-ux
    provides: "05-01: isOnlineProvider, OfflineBanner/SyncStatusBadge widgets, cache_service.dart {data|items, syncedAt} envelope, XSyncedAt companion-notifier pattern"
provides:
  - "BandsListSyncedAt / BandDetailSyncedAt(bandId) companion notifiers — the Bands entity's syncedAt exposure, mirroring ProfileSyncedAt 1:1"
  - "Proven OFFL-03 'disabled + blocked at source' mutation-gating shape across every Bands entry-point form (FAB behind a bottom sheet, an AppBar icon, plain ListTiles, and confirm dialogs) — the template Plans 03/04 (Tracks, Setlists) replicate"
affects: [05-03, 05-04, tracks-provider, setlists-provider]

# Actuals (#2632)
actuals:
  tokens: 15311
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "BandsListSyncedAt/BandDetailSyncedAt(bandId) companion notifiers mirror ProfileSyncedAt's shape (build() => null, public set() method) but a family provider for BandDetailSyncedAt to match BandDetailData's build(String bandId) key"
    - "syncedAt bump lives inside _fetchAndCache() (called by build()'s cache-miss path, _refresh(), and _doRefresh()) so it is NOT gated by the _version WR-02 guard — the cache write already succeeded regardless of whether the fetched result gets discarded by a slower in-flight local mutation (05-RESEARCH.md Pitfall 6)"
    - "Local-mutation methods (setBands, renameBand, updateName) also bump their SyncedAt notifier directly — a successful local mutation is itself a fresh sync point, independent of any network fetch"
    - "Source-blocked mutation entry point: onPressed/onTap set to `isOnline ? handler : null` (never just visually disabled) plus a Tooltip('Requires connection') wrapper — applied uniformly across FloatingActionButton, IconButton, ListTile.enabled, and FilledButton"
    - "In-form/in-dialog D-14 live reactivity: every submit button's onPressed condition becomes `(!isOnline || _isSubmitting) ? null : _submit`, with the button's own label swapping to 'Requires connection' while offline — proven across 6 different widgets (2 screens, 1 stateful dialog helper, 3 confirm dialogs) with zero special-casing"
    - "Test wrap() helpers default isOnlineProvider to true (`isOnlineProvider.overrideWithValue(isOnline)` with `isOnline = true` as the named-parameter default) — connectivity_plus resolves to AsyncLoading/false forever in this sandboxed test environment (no platform-channel mock), so every widget test touching a gated control needs an explicit online-by-default override or it silently disables"

key-files:
  created: []
  modified:
    - lib/providers/bands_provider.dart
    - lib/providers/bands_provider.g.dart
    - lib/features/bands/bands_screen.dart
    - lib/features/bands/band_detail_screen.dart
    - lib/features/bands/create_band_screen.dart
    - lib/features/bands/join_band_dialog.dart
    - lib/features/bands/edit_band_screen.dart
    - lib/features/bands/confirm_delete_band_dialog.dart
    - lib/features/bands/confirm_leave_band_dialog.dart
    - lib/features/bands/confirm_remove_member_dialog.dart
    - test/providers/bands_provider_test.dart
    - test/providers/band_detail_provider_test.dart
    - test/features/bands/bands_screen_test.dart
    - test/features/bands/band_detail_screen_test.dart
    - test/features/bands/create_band_screen_test.dart
    - test/features/bands/join_band_dialog_test.dart
    - test/features/bands/edit_band_screen_test.dart

key-decisions:
  - "setBands() bumps BandsListSyncedAt directly even though it never calls writeBands() itself (its caller, join_band_dialog.dart, already wrote the cache before invoking it) — treats 'state changed via a successful local mutation' as the sync-point trigger rather than requiring setBands() to own the cache write, since the plan's stated rationale ('both already call writeBands()') didn't literally hold for this method"
  - "The D-14 test for ConfirmDeleteBandDialog drives connectivityProvider via a StreamController override (not a static isOnlineProvider.overrideWithValue rebuild) so the dialog stays mounted across the online->offline transition — proves genuine live reactivity to a provider value change, not just a fresh widget tree picking up a new default"

patterns-established:
  - "Every future Bands-shaped CRUD entity (Tracks, Setlists in Wave 2) replicates this plan's exact shape: XSyncedAt companion notifier + SyncStatusBadge on list/detail screens, source-blocked entry points (isOnline ? handler : null + Tooltip), and D-14 live-reactive submit buttons in every form/dialog — no new design decisions needed"

requirements-completed: [OFFL-03, OFFL-04]

coverage:
  - id: D1
    description: "BandsListSyncedAt/BandDetailSyncedAt(bandId) resolve to the cache's stored syncedAt on a cache hit and update after a successful background/foreground refresh, mirroring ProfileSyncedAt's proven shape"
    requirement: "OFFL-04"
    verification:
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#on a cache hit, bandsListSyncedAtProvider resolves..., test/providers/band_detail_provider_test.dart#on a cache hit, bandDetailSyncedAtProvider(bandId) resolves..."
        status: pass
    human_judgment: false
  - id: D2
    description: "Bands list and Band detail screens each render an independent SyncStatusBadge once their data loads"
    requirement: "OFFL-04"
    verification:
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#SyncStatusBadge is present once the bands list loads, test/features/bands/band_detail_screen_test.dart#SyncStatusBadge is present once the band detail loads"
        status: pass
    human_judgment: false
  - id: D3
    description: "Bands FAB (gates both Create and Join via the bottom sheet), band detail's Edit icon, Delete/Leave ListTiles, and per-member Remove icon are all source-blocked (onPressed/onTap null, not just visually disabled) with a 'Requires connection' tooltip while offline"
    requirement: "OFFL-03"
    verification:
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#FAB is disabled and tooltipped while offline / FAB is enabled while online, test/features/bands/band_detail_screen_test.dart#Edit icon is disabled while offline..., Delete and Leave tiles are disabled while offline..., Remove icon on a member row is disabled while offline..."
        status: pass
    human_judgment: false
  - id: D4
    description: "Every in-form/in-dialog submit button (Create, Join, Save, Delete, Leave, Remove) watches isOnlineProvider live and self-disables with a 'Requires connection' label if connectivity drops after the form/dialog was opened while online (D-14); ConfirmDeleteBandDialog's exact-name-match gate is preserved as a separate AND condition"
    requirement: "OFFL-03"
    verification:
      - kind: automated_ui
        ref: "test/features/bands/create_band_screen_test.dart#Create button is disabled..., test/features/bands/join_band_dialog_test.dart#Join button is disabled..., test/features/bands/edit_band_screen_test.dart#Save button is disabled..., test/features/bands/band_detail_screen_test.dart#D-14: losing connectivity while ConfirmDeleteBandDialog is already open disables the Delete button live..."
        status: pass
    human_judgment: false
  - id: D5
    description: "Backstop truth: if connectivity drops while a create/join/edit/delete/leave/remove request is already in flight (submitted while online), the in-flight request is allowed to complete rather than being cancelled — the button's disabled state only prevents NEW submissions, not already-dispatched ones."
    verification: []
    human_judgment: true
    rationale: "Explicitly marked 'verification: backstop' in 05-02-PLAN.md's must_haves — no in-flight-cancellation logic exists anywhere in the codebase (the disabled-onPressed pattern structurally cannot cancel a Future already awaited inside _submit/_delete/_leave/_remove), so the property holds by construction rather than by a dedicated test; confirming it end-to-end requires a real network-drop mid-request scenario this sandboxed environment cannot simulate."
  - id: D6
    description: "Backstop truth: manual airplane-mode walkthrough confirming every Bands FAB/icon/tile/dialog button is visibly grayed and shows 'Requires connection' on tap, and re-enables without needing to reopen the screen when airplane mode toggles off."
    verification: []
    human_judgment: true
    rationale: "Explicitly marked as the plan's manual verification step — no emulator/device available in this sandboxed environment to drive a real airplane-mode walkthrough."

duration: 13min
completed: 2026-08-17
status: complete
---

# Phase 5 Plan 2: Bands Offline Trust & Connectivity UX Summary

**BandsListSyncedAt/BandDetailSyncedAt companion notifiers plus source-blocked (`onPressed: null`, not just disabled-looking) connectivity gating applied across all 9 Bands mutation entry points — FAB, AppBar icon, ListTiles, and 6 in-form/in-dialog submit buttons with D-14 live reactivity — establishing the exact shape Tracks/Setlists (Plans 03/04) replicate with no new design decisions.**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-08-17T11:51:12Z
- **Completed:** 2026-08-17T12:04:23Z
- **Tasks:** 2
- **Files modified:** 17 (2 provider files, 8 feature/dialog files, 7 test files)

## Accomplishments

- `BandsListSyncedAt`/`BandDetailSyncedAt(bandId)` companion notifiers, mirroring 05-01's `ProfileSyncedAt` 1:1 — bumped unconditionally on every successful cache write (cache-hit read, fetch, or local mutation), independent of the `_version` WR-02 guard per 05-RESEARCH.md Pitfall 6
- Bands list and Band detail screens each show an independent `SyncStatusBadge`
- Every Bands mutation entry point is source-blocked while offline: the FAB (gating both Create and Join via its bottom sheet), the Edit `IconButton`, the Delete/Leave `ListTile`s, and the per-member Remove `IconButton` — all `onPressed`/`onTap` set to `null` (not just visually dimmed) with a `Tooltip('Requires connection')`
- All 6 in-form/in-dialog submit buttons (Create, Join, Save, Delete, Leave, Remove) watch connectivity live (D-14) — opening a form online then losing connectivity before submitting disables the button immediately, with the button's own label swapping to "Requires connection"

## Task Commits

Each task was committed atomically:

1. **Task 1: Bands syncedAt exposure + staleness badges + source-blocked mutation entry points** - `9f6730a` (feat)
2. **Task 2: Live connectivity reactivity (D-14) on the 6 in-form/in-dialog Bands mutation buttons** - `ddb361f` (feat)

**Plan metadata:** (this commit, once created)

## Files Created/Modified

- `lib/providers/bands_provider.dart` - `BandsListSyncedAt`/`BandDetailSyncedAt(bandId)` notifiers; sync-bump wiring in `build()`, `_fetchAndCache()`, `setBands()`, `renameBand()`, `updateName()`
- `lib/providers/bands_provider.g.dart` - Regenerated (riverpod_generator) for the two new providers
- `lib/features/bands/bands_screen.dart` - `SyncStatusBadge` + FAB gated on `isOnlineProvider`
- `lib/features/bands/band_detail_screen.dart` - `SyncStatusBadge` + Edit icon/Delete tile/Leave tile/Remove icon all gated on `isOnlineProvider`
- `lib/features/bands/create_band_screen.dart` - Create button live-gated (D-14)
- `lib/features/bands/join_band_dialog.dart` - Join button live-gated (D-14)
- `lib/features/bands/edit_band_screen.dart` - Save button live-gated (D-14)
- `lib/features/bands/confirm_delete_band_dialog.dart` - Delete button live-gated (D-14), exact-name-match gate preserved
- `lib/features/bands/confirm_leave_band_dialog.dart` - Leave button live-gated (D-14)
- `lib/features/bands/confirm_remove_member_dialog.dart` - Remove button live-gated (D-14)
- `test/providers/bands_provider_test.dart` / `band_detail_provider_test.dart` - New syncedAt cache-hit/refresh assertions
- `test/features/bands/bands_screen_test.dart` / `band_detail_screen_test.dart` - `isOnlineProvider` default-true `wrap()` helper + new gating/badge/D-14 tests
- `test/features/bands/create_band_screen_test.dart` / `join_band_dialog_test.dart` / `edit_band_screen_test.dart` - Same `wrap()` default + new gating tests

## Decisions Made

- `setBands()` bumps `BandsListSyncedAt` directly (a successful local-mutation state change is itself a fresh sync point) even though it doesn't itself call `writeBands()` — its only caller (`join_band_dialog.dart`) already writes the cache before invoking it
- The D-14 in-dialog live-reactivity test for `ConfirmDeleteBandDialog` drives `connectivityProvider` via a `StreamController` override rather than a static `isOnlineProvider` value, so the dialog stays mounted across the online→offline transition — proves genuine reactive rebuild, not just a fresh widget tree

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test `wrap()` helpers needed an explicit `isOnlineProvider` default**
- **Found during:** Task 2 (running the pre-existing test suite after wiring connectivity gating into the 6 form/dialog buttons)
- **Issue:** `connectivity_plus` resolves to `AsyncLoading`/`false` indefinitely in this sandboxed test environment (no platform-channel mock exists anywhere in the repo), so `isOnlineProvider` defaults to `false` in every widget test unless explicitly overridden. Every pre-existing test that taps a now-gated control (FAB, Edit icon, Delete/Leave/Remove, Create/Join/Save buttons) would otherwise fail with `onPressed: null`.
- **Fix:** Added `isOnlineProvider.overrideWithValue(isOnline)` (named parameter, default `true`) to the shared `wrap()`/`wrapWithListRoot()` helpers in `bands_screen_test.dart`, `band_detail_screen_test.dart`, `create_band_screen_test.dart`, `join_band_dialog_test.dart`, and `edit_band_screen_test.dart`, plus the manually-constructed `ProviderContainer` in `edit_band_screen_test.dart`'s WR-01 test.
- **Files modified:** `test/features/bands/bands_screen_test.dart`, `test/features/bands/band_detail_screen_test.dart`, `test/features/bands/create_band_screen_test.dart`, `test/features/bands/join_band_dialog_test.dart`, `test/features/bands/edit_band_screen_test.dart`
- **Verification:** Full `flutter test` suite (248 tests) passes; `flutter analyze` reports zero issues.
- **Committed in:** `9f6730a` (Task 1, for `bands_screen_test.dart`/`band_detail_screen_test.dart`) and `ddb361f` (Task 2, for the remaining 3 files)

**2. [Rule 1 - Bug] `setBands()`'s syncedAt bump adjusted from the plan's literal instruction**
- **Found during:** Task 1
- **Issue:** The plan's action text claimed `setBands()` "already calls `writeBands(...)`" (implying the bump should sit right after that call), but `setBands()` in the actual codebase never calls `writeBands()` itself — only `renameBand()` does. `setBands()`'s only caller (`join_band_dialog.dart`) writes the cache before invoking it.
- **Fix:** Added the sync-bump directly inside `setBands()`, independent of any `writeBands()` call in that method, treating "state changed via a successful local mutation" as the trigger (matches the plan's stated rationale — "a successful local mutation is itself a fresh sync point" — even though the literal premise about the write call didn't hold).
- **Files modified:** `lib/providers/bands_provider.dart`
- **Verification:** `test/providers/bands_provider_test.dart`'s existing `setBands()`-exercising tests still pass; no regression.
- **Committed in:** `9f6730a`

---

**Total deviations:** 2 auto-fixed (1 test-infrastructure bug fix, 1 plan-inaccuracy bug fix)
**Impact on plan:** Both necessary to keep `flutter analyze`/`flutter test` green per every task's acceptance criteria. No scope creep — neither changes the plan's intended behavior.

## Issues Encountered

- None beyond the deviations above — `flutter test` (248 tests, full suite) and `flutter analyze` (zero issues) both pass at the end of every task.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The Bands entity's full OFFL-03/OFFL-04 shape (syncedAt exposure, staleness badge, source-blocked entry points, D-14 live reactivity) is proven end-to-end and ready to serve as the literal template for Plans 03 (Tracks) and 04 (Setlists) — no new design decisions needed, just the same pattern applied to each entity's provider/screens/dialogs.
- Backstop truths (D5: in-flight-request completion on connectivity drop; D6: manual airplane-mode walkthrough) remain `human_judgment: true` and unverified by automation in this sandboxed environment — flagged for end-of-phase manual/device verification per the plan's own `must_haves`.

---
*Phase: 05-offline-trust-connectivity-ux*
*Completed: 2026-08-17*

## Self-Check: PASSED

All modified files verified present on disk; both commit hashes (`9f6730a`, `ddb361f`) verified present in `git log --oneline --all`.
