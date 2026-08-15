---
phase: 02-bands
plan: 06
subsystem: cache
tags: [hive, riverpod, asyncnotifier, error-handling, race-condition]

requires:
  - phase: 02-bands
    provides: BandsListData/BandDetailData AsyncNotifiers, CacheService Hive-backed store, EditBandScreen and the 6 band-mutation screens/dialogs (02-01 through 02-05)
provides:
  - Recursive Hive deserialization (_deepConvert) closing the CR-01 blocker on nested cached collections
  - Version-guarded background refresh preventing local-edit clobbering (WR-02)
  - BandsListData.renameBand() propagating a rename to the cached list (WR-01)
  - Fallback non-ApiException error handling across all 6 band-mutation call sites (WR-03)
affects: [phase-03-tracks, phase-04-setlists, phase-05-offline-staleness]

actuals:
  tokens: 40000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Recursive deep-conversion of Hive's untyped Map<dynamic,dynamic>/List<dynamic> read shapes, applied once at the _KeyValueStore boundary rather than at each call site"
    - "Monotonic per-notifier _version counter captured before a network await and compared after, to discard stale background-refresh results without blocking user-initiated refreshes"
    - "ref.exists() guard before reading a sibling provider's .notifier from an unrelated screen, avoiding an unintended provider instantiation + network fetch as a side effect"

key-files:
  created: []
  modified:
    - lib/cache/cache_service.dart
    - lib/providers/bands_provider.dart
    - lib/features/bands/edit_band_screen.dart
    - lib/features/bands/create_band_screen.dart
    - lib/features/bands/join_band_dialog.dart
    - lib/features/bands/confirm_delete_band_dialog.dart
    - lib/features/bands/confirm_leave_band_dialog.dart
    - lib/features/bands/confirm_remove_member_dialog.dart
    - test/cache/cache_service_test.dart
    - test/providers/bands_provider_test.dart
    - test/providers/band_detail_provider_test.dart
    - test/features/bands/edit_band_screen_test.dart
    - test/features/bands/create_band_screen_test.dart
    - test/features/bands/join_band_dialog_test.dart
    - test/features/bands/band_detail_screen_test.dart

key-decisions:
  - "Guarded EditBandScreen's new bandsListDataProvider.notifier read with ref.exists() (deviation from the plan's literal 'no guard needed' instruction) — the unconditional read was found to instantiate a never-before-watched provider and trigger an unplanned GET /api/band/list network call as a side effect, which broke 3 pre-existing tests by polluting their shared mock request-capture variables"

patterns-established:
  - "Pattern 1: _deepConvert recursion at the store boundary — any future Hive-backed box gets nested-collection safety for free without per-call-site casting"
  - "Pattern 2: _version-counter guard on AsyncNotifier background refreshes — reusable for any future cache-first provider with a local-mutation method"

requirements-completed: [BAND-01, BAND-02, BAND-03, BAND-04, BAND-05, BAND-06, BAND-08, BAND-09]

coverage:
  - id: D1
    description: "_HiveStore.get() recursively normalizes nested Map/List values read from a real (closed-and-reopened) Hive box, closing CR-01"
    requirement: "BAND-03"
    verification:
      - kind: unit
        ref: "test/cache/cache_service_test.dart#readBandDetail after a real Hive close+reopen returns fully typed nested collections (CR-01)"
        status: pass
      - kind: unit
        ref: "test/cache/cache_service_test.dart#readBands after a real Hive close+reopen returns a fully typed list of maps (CR-01)"
        status: pass
    human_judgment: false
  - id: D2
    description: "BandsListData/BandDetailData discard a stale in-flight background-refresh result if a local mutation landed first, via a captured _version counter"
    requirement: "BAND-04"
    verification:
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#a local setBands() mutation is not clobbered by a slower in-flight background refresh (WR-02)"
        status: pass
      - kind: unit
        ref: "test/providers/band_detail_provider_test.dart#a local updateName() mutation is not clobbered by a slower in-flight background refresh (WR-02)"
        status: pass
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#a background refresh with no intervening local mutation still updates state to the fetched data"
        status: pass
      - kind: unit
        ref: "test/providers/band_detail_provider_test.dart#a background refresh with no intervening local mutation still updates state to the fetched data"
        status: pass
    human_judgment: false
  - id: D3
    description: "Renaming a band from EditBandScreen propagates to bandsListDataProvider's cached list entry via the new renameBand() method"
    requirement: "BAND-04"
    verification:
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#renameBand() patches only the matching entry in-place and persists it"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/edit_band_screen_test.dart#a successful save propagates the rename to bandsListDataProvider's cached list entry (WR-01)"
        status: pass
    human_judgment: false
  - id: D4
    description: "All 6 band-mutation call sites (create, join, edit, delete, leave, remove-member) surface a generic error message on non-ApiException failures instead of silently re-enabling the submit button"
    requirement: "BAND-02"
    verification:
      - kind: automated_ui
        ref: "test/features/bands/create_band_screen_test.dart#a non-ApiException failure (e.g. offline) shows the generic fallback message and re-enables the Create button"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/join_band_dialog_test.dart#a non-ApiException failure (e.g. offline) shows the generic fallback message and re-enables the Join button"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/edit_band_screen_test.dart#a non-ApiException failure (e.g. offline) shows the generic fallback message and re-enables the Save button"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#a Delete failure from a non-ApiException error (e.g. offline) shows the generic fallback message and re-enables the Delete button"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#a Leave failure from a non-ApiException error (e.g. offline) shows the generic fallback message and re-enables the Leave button"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#a Remove failure from a non-ApiException error (e.g. offline) shows the generic fallback message and re-enables the Remove button"
        status: pass
    human_judgment: true
    rationale: "The plan's Task 3 <verify> also specifies a human-check: manually triggering a mutation with the device offline to visually confirm the fallback message renders correctly in the real app, beyond what the automated widget tests assert."

duration: 27min
completed: 2026-08-15
status: complete
---

# Phase 02 Plan 06: Gap-Closure Summary

**Recursive Hive deserialization, a version-guarded background-refresh race fix, band-rename list propagation, and fallback error handling across all 6 band mutations — closing all 4 verification gaps from 02-VERIFICATION.md**

## Performance

- **Duration:** 27 min
- **Started:** 2026-08-15T18:20:00Z
- **Completed:** 2026-08-15T18:47:09Z
- **Tasks:** 3
- **Files modified:** 15

## Accomplishments
- CR-01 (blocker): `_HiveStore.get()` now recursively deep-converts every nested Map/List value read from Hive via a new `_deepConvert` helper, closing the TypeError that a real (non-in-memory) Hive disk round-trip would throw on `readBands()`/`readBandDetail()`'s nested collections. Proven by two new tests that explicitly `Hive.close()` + reopen mid-test to force a real `BinaryReaderImpl` deserialization pass — the exact gap the original 53 passing (in-memory-only) tests missed.
- WR-02: `BandsListData`/`BandDetailData` each carry a monotonic `_version` counter, captured before their background-refresh network await and checked before applying the fetched result — a slower in-flight refresh can no longer silently revert a local mutation (`setBands`/`renameBand`/`updateName`) that landed first.
- WR-01: New `BandsListData.renameBand(bandId, newName)` patches the matching entry in-place and persists it; `EditBandScreen._submit()` calls it after a successful rename (guarded by `ref.exists()`, mirroring the existing `bandDetailDataProvider` guard) so the still-mounted Bands list reflects the new name immediately.
- WR-03: All 6 band-mutation call sites (create, join, edit, delete, leave, remove-member) now have a fallback `catch (e)` after their existing `on ApiException` clause, setting a generic "Something went wrong. Please try again." message instead of silently re-enabling the submit button on SocketException/FormatException/TypeError.

## Task Commits

Each task was committed atomically:

1. **Task 1: CR-01 — recursive Hive deserialization fix + real disk-round-trip regression test** - `540fc15` (fix)
2. **Task 2: WR-02 — background-refresh race guard, plus WR-01 — rename propagation to Bands list** - `53236a2` (fix)
3. **Task 3: WR-03 — fallback error handling across all 6 mutation call sites** - `0fc49ca` (fix)

_Note: these were single-commit `type="auto"`/`type="tracer"` tasks, not TDD RED/GREEN/REFACTOR — each task's tests and implementation were committed together after its own acceptance-criteria gate passed._

## Files Created/Modified
- `lib/cache/cache_service.dart` - `_HiveStore._deepConvert()` recursive normalization helper
- `lib/providers/bands_provider.dart` - `_version` counters, `renameBand()` method, guarded refresh overwrites
- `lib/features/bands/edit_band_screen.dart` - calls `renameBand()` (guarded) + fallback `catch (e)`
- `lib/features/bands/create_band_screen.dart` - fallback `catch (e)`
- `lib/features/bands/join_band_dialog.dart` - fallback `catch (e)`
- `lib/features/bands/confirm_delete_band_dialog.dart` - fallback `catch (e)`
- `lib/features/bands/confirm_leave_band_dialog.dart` - fallback `catch (e)`
- `lib/features/bands/confirm_remove_member_dialog.dart` - fallback `catch (e)`
- `test/cache/cache_service_test.dart` - 2 new real-Hive close+reopen round-trip tests
- `test/providers/bands_provider_test.dart` - race, regression, and `renameBand()` tests
- `test/providers/band_detail_provider_test.dart` - race and regression tests
- `test/features/bands/edit_band_screen_test.dart` - rename-propagation + fallback-error tests
- `test/features/bands/create_band_screen_test.dart` - fallback-error test
- `test/features/bands/join_band_dialog_test.dart` - fallback-error test
- `test/features/bands/band_detail_screen_test.dart` - 3 fallback-error tests (Delete/Leave/Remove)

## Decisions Made
- Guarded the new `bandsListDataProvider.notifier` read in `EditBandScreen._submit()` with `ref.exists(bandsListDataProvider)`, deviating from the plan's literal "no `ref.exists()` guard needed" instruction — see Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Guarded the unconditional `renameBand()` call with `ref.exists()`**
- **Found during:** Task 2 (WR-02/WR-01 implementation)
- **Issue:** The plan's Task 2 `<action>` specified calling `ref.read(bandsListDataProvider.notifier).renameBand(...)` unconditionally, reasoning that `renameBand()` "already no-ops safely if there's no cached list state to patch." In practice, merely reading `.notifier` on a provider that has never been watched instantiates it and kicks off its own `build()` — including an unawaited network fetch — as a side effect, before `renameBand()`'s own no-op check ever runs. This broke 3 pre-existing `edit_band_screen_test.dart` tests (their shared mock-request-capturing variables got overwritten by the stray `GET /api/band/list` call), and made the new WR-01 propagation test itself flaky (the freshly-instantiated notifier's `build()` hadn't resolved yet when `renameBand()` ran, so `state.valueOrNull` was still null and the rename silently no-op'd).
- **Fix:** Wrapped the call in `if (ref.exists(bandsListDataProvider)) { ... }`, mirroring the existing guard already used one block above for `bandDetailDataProvider(widget.bandId)` in the same function. In real usage this is a no-op change — `BandsScreen` (and therefore `bandsListDataProvider`) is always mounted in `RootScaffold`'s `IndexedStack` per D-15, so the provider already exists whenever `EditBandScreen` is reachable.
- **Files modified:** `lib/features/bands/edit_band_screen.dart`, `test/features/bands/edit_band_screen_test.dart` (added `container.listen(bandsListDataProvider, (_, _) {})` to the WR-01 test to hold the autoDispose provider alive across the pump, matching the existing pattern in `bands_provider_test.dart`)
- **Verification:** `flutter test test/features/bands/edit_band_screen_test.dart` — all 18 tests pass, including the 3 previously-broken pre-existing tests and the new WR-01/WR-03 tests
- **Committed in:** `53236a2` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Necessary for correctness — the unguarded call had a real, observable side effect (an unintended network request) inconsistent with the read-only-cache-first design this phase establishes, and its absence would have left 3 pre-existing tests broken. No scope creep: the guard is a one-line, same-pattern addition, not a redesign.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All 4 verification gaps from `02-VERIFICATION.md` (CR-01, WR-01, WR-02, WR-03) are closed with passing regression tests; full suite is 93 tests green, `flutter analyze` clean project-wide.
- Task 3's plan-level `<verify>` also specifies a `<human-check>`: manually triggering a mutation with the device/dev-server offline to visually confirm the fallback message renders in the real app. This is UI-judgment verification beyond what the automated widget tests assert — flagged in this SUMMARY's `coverage:` block (D4, `human_judgment: true`) for `/gsd-verify-work` to route to the human.
- Phase 02 (bands) is now feature-complete and gap-closure-complete; ready for Phase 3 (tracks) planning.

---
*Phase: 02-bands*
*Completed: 2026-08-15*
