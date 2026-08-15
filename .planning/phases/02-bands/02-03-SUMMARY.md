---
phase: 02-bands
plan: 03
subsystem: ui
tags: [riverpod, flutter, bands, fab, bottom-sheet, dialog]

requires:
  - phase: 02-bands
    provides: "02-01: BandsListData cache-first provider, bandsBox Hive cache, BandsScreen shell; 02-02: BandDetailScreen, BandDetailData family provider"
provides:
  - PublicApi.createBand({required String name}) (POST /api/band)
  - PublicApi.joinBand({required String inviteCode}) (POST /api/band/join)
  - CreateBandScreen (full-screen create form)
  - showJoinBandDialog(BuildContext, WidgetRef) (Join a band dialog)
  - BandsScreen FAB + _showCreateJoinMenu bottom-sheet action menu (D-09)
  - BandsListData.setBands() — public setter for provider state after an already-fetched refresh
affects: [02-04 (edit/delete band, likely reuses CreateBandScreen's form/submit pattern), any future band-scoped mutation screen]

actuals:
  tokens: 8355
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Dialogs that need to navigate/snackbar after closing return a result via Navigator.pop(result) and let the OUTER function (the one that called showDialog, still backed by a persistent context) handle post-close effects — avoids using the dialog's own BuildContext after it's torn down"
    - "AsyncNotifier state should only be set via a public method the class defines (e.g. BandsListData.setBands()), never via notifier.state = ... from outside — the latter trips invalid_use_of_protected_member/visible_for_testing analyzer errors"

key-files:
  created:
    - lib/features/bands/create_band_screen.dart
    - lib/features/bands/join_band_dialog.dart
    - test/features/bands/create_band_screen_test.dart
    - test/features/bands/join_band_dialog_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/features/bands/bands_screen.dart
    - lib/providers/bands_provider.dart
    - test/features/bands/bands_screen_test.dart

key-decisions:
  - "JoinBandDialog resolves the joined band's id client-side by diffing PublicApi.listBands() before/after the join, since POST /api/band/join returns no response body per publicapi.yml — an explicit, documented API-contract gap (see 02-03-PLAN.md Flagged Assumptions), not a client bug"
  - "Added BandsListData.setBands() rather than following the plan's literal 'ref.read(bandsListDataProvider.notifier).state = AsyncData(...)' instruction — the literal approach fails flutter analyze (invalid_use_of_protected_member + invalid_use_of_visible_for_testing_member), so a public setter method was added to the notifier class instead, achieving the same no-extra-network-call goal cleanly"
  - "join_band_dialog.dart's private _JoinBandDialog widget pops with a small _JoinOutcome result object instead of doing navigation/snackbar work inside its own build context — the dialog's context is torn down once Navigator.pop() completes its transition, so post-join navigation/snackbar happens in the outer showJoinBandDialog function using the caller's still-mounted context"

requirements-completed: [BAND-02, BAND-06]

coverage:
  - id: D1
    description: "A single FAB on BandsScreen opens a bottom-sheet action menu with exactly two options: 'Create band' and 'Join with code' (D-09)"
    requirement: BAND-02
    verification:
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#tapping the FAB shows a bottom sheet with exactly \"Create band\" and \"Join with code\""
        status: pass
    human_judgment: false
  - id: D2
    description: "'Create band' opens a full-screen CreateBandScreen; empty/whitespace name rejected client-side; Create button disabled while in flight; successful submit invalidates the bands list, shows a snackbar, and navigates (pushReplacement) straight to the new band's detail screen (D-10/D-12)"
    requirement: BAND-02
    verification:
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#starts with an empty name field"
        status: pass
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#Create button is disabled while submitting"
        status: pass
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#submitting a valid name calls createBand and navigates to BandDetailScreen"
        status: pass
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#empty/whitespace-only name is rejected without an API call"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#tapping \"Create band\" in the FAB menu navigates to CreateBandScreen"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#tapping the empty-state \"Create Band\" button navigates to CreateBandScreen"
        status: pass
    human_judgment: false
  - id: D3
    description: "BAND-02 edge probes: createBand() submit failure renders an inline error and re-enables the Create button; a long band name doesn't break the form's layout"
    requirement: BAND-02
    verification:
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#a createBand() failure renders an inline error and re-enables the Create button"
        status: pass
      - kind: unit
        ref: "test/features/bands/create_band_screen_test.dart#a band name longer than 30 characters does not break the TextFormField's layout"
        status: pass
    human_judgment: false
  - id: D4
    description: "'Join with code' opens a dialog with an autofocused, empty invite-code field; Join button disabled while in flight; on success, resolves the joined band's id via a list-diff and navigates to its detail screen when unambiguous, else falls back to the refreshed Bands list (D-11/D-12)"
    requirement: BAND-06
    verification:
      - kind: unit
        ref: "test/features/bands/join_band_dialog_test.dart#invite-code field is empty and autofocused on open"
        status: pass
      - kind: unit
        ref: "test/features/bands/join_band_dialog_test.dart#submitting a code calls joinBand with the code trimmed"
        status: pass
      - kind: unit
        ref: "test/features/bands/join_band_dialog_test.dart#exactly one new band id navigates to that band's detail screen"
        status: pass
      - kind: unit
        ref: "test/features/bands/join_band_dialog_test.dart#an ambiguous diff (0 new ids) falls back to the refreshed Bands list"
        status: pass
      - kind: unit
        ref: "test/features/bands/join_band_dialog_test.dart#an ambiguous diff (2+ new ids) falls back to the refreshed Bands list"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#tapping \"Join with code\" in the FAB menu opens the join dialog"
        status: pass
    human_judgment: false
  - id: D5
    description: "BAND-06 edge probes: joinBand() submit failure (e.g. invalid code) renders an inline error and re-enables the Join button; a long/pasted invite code doesn't break the dialog's field layout"
    requirement: BAND-06
    verification:
      - kind: unit
        ref: "test/features/bands/join_band_dialog_test.dart#a joinBand() failure renders an inline error and re-enables the Join button"
        status: pass
      - kind: unit
        ref: "test/features/bands/join_band_dialog_test.dart#a long/pasted invite code does not break the TextField's layout"
        status: pass
    human_judgment: false
  - id: D6
    description: "Visual/UAT backstop dimensions not independently automated: real end-to-end FAB->Create/Join->detail flow against a real backend, and finer visual polish of the bottom sheet/dialog/form"
    verification: []
    human_judgment: true
    rationale: "Plan classified submit-failure and overflow rows as 'backstop' verification, satisfied above by widget tests using mocked API responses; the full flow against a real running backend (network latency, real invite codes, real server error shapes) is best confirmed visually in end-of-phase UAT, per workflow.human_verify_mode=end-of-phase and the same judgment-call pattern used in 02-01/02-02."

duration: 35min
completed: 2026-08-15
status: complete
---

# Phase 2 Plan 3: Create/Join Band (BAND-02, BAND-06) Summary

**Single-FAB Create/Join entry point wired end-to-end — `POST /api/band` via a new full-screen CreateBandScreen and `POST /api/band/join` via a JoinBandDialog that resolves the joined band's id through a client-side list-diff, since the join endpoint returns no response body**

## Performance

- **Duration:** 35 min
- **Tasks:** 3
- **Files modified:** 8 (4 created, 4 modified)

## Accomplishments
- `PublicApi.createBand({required String name})` calls `POST /api/band`, returning the raw `CreateBandResponseBody` map (`{id}`)
- `PublicApi.joinBand({required String inviteCode})` calls `POST /api/band/join` (no response body per `publicapi.yml`)
- `CreateBandScreen` — full-screen form mirroring `login_screen.dart`'s `Form`/`TextFormField`/`_isSubmitting`/`_errorMessage` shape; on success invalidates `bandsListDataProvider`, shows a `'$name created!'` snackbar, and `pushReplacement`s to `BandDetailScreen` (D-12: back doesn't return to the form)
- `showJoinBandDialog` + private `_JoinBandDialog` — dialog with an autofocused invite-code field; on success, diffs a pre-join id snapshot against a fresh post-join `listBands()` call to resolve the newly-joined band's id (no invented API field), navigating to its detail screen on an unambiguous single new id or falling back to the (refreshed) Bands list otherwise
- `BandsScreen` gained a `FloatingActionButton` opening a bottom sheet with exactly "Create band" / "Join with code" (D-09), and its 02-01-deferred empty-state "Create Band" button now navigates directly to `CreateBandScreen`
- `BandsListData.setBands()` — new public method letting the join dialog push its already-fetched refresh into the provider without a protected-member analyzer violation or a redundant network call
- Full edge-state coverage: submit-failure inline errors + re-enabled buttons on both Create and Join, long-text layout on both fields, FAB menu exact-two-options + navigation wiring for all three entry points (FAB→Create, FAB→Join, empty-state→Create)

## Task Commits

Each task was committed atomically:

1. **Task 1: End-to-end POST /api/band — FAB + action menu + CreateBandScreen (BAND-02)** - `48bc4f7` (feat)
2. **Task 2: End-to-end POST /api/band/join — JoinBandDialog with list-diff band-id resolution (BAND-06)** - `33e8c75` (feat)
3. **Task 3: FAB interaction + full form/dialog edge-state test coverage (BAND-02, BAND-06)** - `a5cbc3f` (test)

_Note: Task 1 is a `tracer` task; its `<verify>` (`flutter test test/features/bands/create_band_screen_test.dart`) was run and passed before proceeding to Task 2._

## Files Created/Modified
- `lib/api/public_api.dart` - Added `createBand()` and `joinBand()`
- `lib/features/bands/create_band_screen.dart` - New `CreateBandScreen`
- `lib/features/bands/join_band_dialog.dart` - New `showJoinBandDialog` + `_JoinBandDialog`
- `lib/features/bands/bands_screen.dart` - Added FAB, `_showCreateJoinMenu` bottom sheet, wired empty-state Create Band button
- `lib/providers/bands_provider.dart` - Added `BandsListData.setBands()`
- `test/features/bands/create_band_screen_test.dart` - 6 tests (empty state, disabled-while-submitting, submit-success+navigation, empty-name validation, submit-failure error, long-name overflow)
- `test/features/bands/join_band_dialog_test.dart` - 7 tests (empty+autofocus, trimmed submit, single-new-id navigation, 0-new-ids fallback, 2+-new-ids fallback, submit-failure error, long-code overflow)
- `test/features/bands/bands_screen_test.dart` - 4 new tests (FAB menu exact-two-options, Create band navigation, Join with code dialog opens, empty-state button navigation)

## Decisions Made
- Resolved the join endpoint's missing response-id via a client-side list-diff (pre-join snapshot vs. fresh post-join fetch) rather than inventing an API field — an explicit, documented gap (see plan's "Flagged Assumptions"), with a graceful non-guessing fallback to the Bands list on any ambiguous diff (0 or 2+ new ids)
- Deviated from the plan's literal `ref.read(bandsListDataProvider.notifier).state = AsyncData(...)` instruction: that line fails `flutter analyze` (`invalid_use_of_protected_member`, `invalid_use_of_visible_for_testing_member`). Added `BandsListData.setBands()` instead — a public method on the notifier itself that achieves the same "push an already-fetched refresh into the provider without a second network call" goal cleanly.
- `_JoinBandDialog` never does navigation/snackbar work using its own `BuildContext` after `Navigator.pop()` — it pops with a small `_JoinOutcome` result object, and the outer `showJoinBandDialog` function (holding the caller's persistent context) performs the post-close effects. Avoids a "widget torn down before you finished using its context" crash.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's literal `notifier.state = AsyncData(...)` instruction fails `flutter analyze`**
- **Found during:** Task 2 (post-implementation `flutter analyze` run)
- **Issue:** `ref.read(bandsListDataProvider.notifier).state = AsyncData(freshBands)` from outside the `BandsListData` class trips `invalid_use_of_protected_member` and `invalid_use_of_visible_for_testing_member` (riverpod's `state` setter is `@protected`/`@visibleForTesting` on `AsyncNotifier`), causing `flutter analyze` to exit non-zero.
- **Fix:** Added a public `setBands(List<Map<String, dynamic>> bands)` method to `BandsListData` (`lib/providers/bands_provider.dart`) that sets `state = AsyncData(bands)` from within the class, where the assignment is permitted. `join_band_dialog.dart` now calls `ref.read(bandsListDataProvider.notifier).setBands(freshBands)`.
- **Files modified:** lib/providers/bands_provider.dart, lib/features/bands/join_band_dialog.dart
- **Verification:** `flutter analyze` clean (0 issues) on all touched files
- **Committed in:** 33e8c75 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — the plan's literal instruction for updating provider state after a client-side refresh didn't pass this project's own `flutter analyze` acceptance criterion; the fix preserves the exact intended behavior — no extra network call, immediate list refresh — through a public API instead of reaching into a protected member)
**Impact on plan:** Required for the plan's own acceptance criteria (`flutter analyze` reports no new errors). No scope creep beyond what Task 2's join-diff logic already necessitated.

## Issues Encountered
- Widget-test flakiness risk: the "exactly one new band id" test initially used response-call-counting to distinguish pre-/post-join `GET /api/band/list` responses, which is inherently racy against the provider's own background/cache-miss fetches. Switched to a `joined` boolean flag on the mock handler (state-based, not order-based) so any number of concurrent list calls resolve deterministically to the correct pre-/post-join snapshot.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `CreateBandScreen`'s form/submit pattern and `PublicApi.createBand()` are ready for 02-04 (edit/delete band) to mirror for an edit form.
- The list-diff pattern in `join_band_dialog.dart` is a documented, reusable answer to "API endpoint doesn't return an id I need" — worth reusing if a future endpoint has the same gap.
- BAND-02 and BAND-06 are fully satisfied: a user can create a band or join one via invite code from the single FAB entry point, landing on the resulting band's detail screen.
- No blockers.

---
*Phase: 02-bands*
*Completed: 2026-08-15*

## Self-Check: PASSED

All created/modified files exist on disk; all three task commits (`48bc4f7`, `33e8c75`, `a5cbc3f`) found in git log; `flutter analyze` clean (0 issues); `flutter test` full suite (61 tests) passes.
