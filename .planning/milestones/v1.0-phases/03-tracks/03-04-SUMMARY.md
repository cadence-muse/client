---
phase: 03-tracks
plan: 04
subsystem: ui
tags: [flutter, riverpod, dropdown-validation, cache-invalidation, form-validation]

# Dependency graph
requires:
  - phase: 03-tracks (03-01/03-02/03-03)
    provides: per-band track CRUD screens, global cross-band Tracks tab, TrackListData/TrackDetailData/UserTracksListData providers
provides:
  - EditTrackScreen no longer crashes on a track whose key isn't in the client's 24-value musicalKeys list
  - Clearing an optional track field (Duration/Tempo/Key/Notes) on edit now persists as cleared (explicit null sent, not omitted)
  - Track create/edit/delete now invalidate the global cross-band Tracks tab's data provider
  - "View bands" button in the global Tracks tab's zero-bands empty state now switches to the Bands tab
  - Duration/Tempo fields reject non-numeric input with a visible validation error
affects: [03-tracks, setlists (any future phase reusing RootScaffold's tab-switching pattern)]

# Actuals (#2632)
actuals:
  tokens: 9143
  tasks: 5
  commits: 5

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SelectedTabIndex Riverpod notifier (navigation_provider.dart) lets a screen switch RootScaffold's bottom-nav tab without a direct reference to RootScaffold's state — mirrors ThemeController's default+public-setter shape"
    - "Always-send-all-fields request body (not conditional if-not-null) is required whenever the API's partial-update semantics treat an omitted field as 'keep' and an explicit null as 'clear' — applies to any future PUT/PATCH mutation with optional clearable fields"

key-files:
  created:
    - lib/providers/navigation_provider.dart
    - lib/providers/navigation_provider.g.dart
    - test/providers/navigation_provider_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/features/tracks/edit_track_screen.dart
    - lib/features/tracks/create_track_screen.dart
    - lib/features/tracks/confirm_delete_track_dialog.dart
    - lib/features/songs/tracks_screen.dart
    - lib/navigation/root_scaffold.dart

key-decisions:
  - "updateBandTrack's title/artist parameters changed from optional nullable to required non-nullable — EditTrackScreen is the method's only caller and always has both from its form, so the stricter signature costs nothing and documents the always-send-all-fields contract at the type level"
  - "CR-03's global-provider invalidate is ref.exists()-guarded in all three mutation flows, not unconditional — reading .notifier or invalidating a never-instantiated provider would trigger an unwanted network fetch as a side effect (mirrors the existing trackDetailDataProvider guard pattern from 03-02)"
  - "createBandTrack intentionally left with its original conditional-guard body — there is no 'old value' to clear on create, so the always-send-all-fields fix only applies to updateBandTrack"

requirements-completed: [TRACK-02, TRACK-04, TRACK-05, TRACK-06]

coverage:
  - id: D1
    description: "EditTrackScreen no longer crashes when a track's key value isn't in the 24-entry musicalKeys list (CR-01)"
    requirement: "TRACK-04"
    verification:
      - kind: unit
        ref: "test/features/tracks/edit_track_screen_test.dart#CR-01: a track whose key is not in musicalKeys builds without throwing and leaves the key dropdown unselected"
        status: pass
    human_judgment: false
  - id: D2
    description: "Clearing an optional track field (Duration/Tempo/Key/Notes) on edit sends an explicit null and persists as cleared, instead of being silently omitted and kept stale by the server's merge semantics (CR-02)"
    requirement: "TRACK-04"
    verification:
      - kind: unit
        ref: "test/features/tracks/edit_track_screen_test.dart#CR-02: clearing optional fields sends explicit null instead of omitting them"
        status: pass
    human_judgment: false
  - id: D3
    description: "Track create/edit/delete each invalidate the global cross-band Tracks tab's data provider (when already instantiated), so the global tab reflects per-band mutations without a manual filter change (CR-03)"
    requirement: "TRACK-06"
    verification:
      - kind: unit
        ref: "test/features/tracks/create_track_screen_test.dart#CR-03: creating a track invalidates the global Tracks tab so it refetches"
        status: pass
      - kind: unit
        ref: "test/features/tracks/edit_track_screen_test.dart#CR-03: editing a track invalidates the global Tracks tab so it refetches"
        status: pass
      - kind: unit
        ref: "test/features/tracks/confirm_delete_track_dialog_test.dart#CR-03: deleting a track invalidates the global Tracks tab so it refetches"
        status: pass
    human_judgment: false
  - id: D4
    description: "The 'View bands' button in the global Tracks tab's zero-bands empty state switches the app to the Bands tab instead of being a no-op (WR-01)"
    requirement: "TRACK-06"
    verification:
      - kind: unit
        ref: "test/providers/navigation_provider_test.dart#SelectedTabIndex"
        status: pass
      - kind: automated_ui
        ref: "test/widget_test.dart#WR-01: tapping \"View bands\" on the empty Tracks tab switches to the Bands tab"
        status: pass
    human_judgment: false
  - id: D5
    description: "Duration/Tempo fields reject non-numeric input with a visible \"Enter a whole number\" error instead of silently discarding it (WR-02)"
    requirement: "TRACK-02"
    verification:
      - kind: unit
        ref: "test/features/tracks/create_track_screen_test.dart#WR-02: non-numeric Duration input is rejected without an API call"
        status: pass
      - kind: unit
        ref: "test/features/tracks/edit_track_screen_test.dart#WR-02: non-numeric Tempo input is rejected without an API call"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-08-16
status: complete
---

# Phase 03 Plan 04: Gap Closure (CR-01/02/03, WR-01/02) Summary

**Closed all 5 track-management gaps found by code review/verification: an EditTrackScreen crash on unrecognized keys, a data-loss bug where cleared optional fields silently stayed stale, a global Tracks tab that never synced with per-band mutations, a no-op "View bands" button, and unvalidated numeric input.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-08-16T12:57:28Z
- **Tasks:** 5
- **Files modified:** 13 (3 new, 10 modified)

## Accomplishments
- EditTrackScreen's `_selectedKey` now guards against unrecognized `key` values (only pre-selects a value that's a member of `musicalKeys`), so a track edited/created via another client no longer crashes `DropdownButtonFormField`'s `initialValue` assertion (CR-01)
- `PublicApi.updateBandTrack` now unconditionally sends all 6 editable fields (title/artist/durationSeconds/tempo/key/notes) instead of omitting null ones, and `title`/`artist` are now required — clearing an optional field on edit sends an explicit JSON `null`, which the server's merge semantics correctly treat as "clear this field" (CR-02)
- Create/edit/delete track mutation flows now each guard-invalidate `userTracksListDataProvider` (`ref.exists()`-gated to avoid instantiating a never-visited global tab), so the global cross-band Tracks tab stays in sync with per-band mutations for the rest of the session (CR-03)
- New `SelectedTabIndex` Riverpod notifier (`navigation_provider.dart`) backs `selectedTabIndexProvider`; `RootScaffold` converted from `StatefulWidget` to `ConsumerWidget` reading it for both `IndexedStack.index` and `NavigationBar.selectedIndex`; `TracksScreen`'s "View bands" empty-state button now calls `setIndex(2)` to switch to the Bands tab instead of being a no-op (WR-01)
- Duration/Tempo `TextFormField`s in both `CreateTrackScreen` and `EditTrackScreen` gained a `_wholeNumberValidator` that rejects non-empty, non-integer input with "Enter a whole number" while keeping empty fields valid (WR-02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix CR-01 — guard EditTrackScreen's key dropdown against unrecognized values** - `5442431` (fix)
2. **Task 2: Fix CR-02 — always send all editable fields on track update** - `687657b` (fix)
3. **Task 3: Fix CR-03 — invalidate the global Tracks tab after every track mutation** - `93cae88` (fix)
4. **Task 4: Fix WR-01 — wire the "View bands" empty-state button to the Bands tab** - `c611a34` (fix)
5. **Task 5: Fix WR-02 — validate non-numeric Duration/Tempo input** - `8e44655` (fix)

**Plan metadata:** pending (this commit)

## Files Created/Modified
- `lib/providers/navigation_provider.dart` - New `SelectedTabIndex` Riverpod notifier backing `selectedTabIndexProvider` (default 0, public `setIndex(int)` method)
- `lib/providers/navigation_provider.g.dart` - riverpod_generator output for the above
- `lib/api/public_api.dart` - `updateBandTrack` rewritten to always send all 6 fields; `title`/`artist` now required
- `lib/features/tracks/edit_track_screen.dart` - CR-01 dropdown guard, CR-02 always-send patch map, CR-03 global invalidate, WR-02 validators
- `lib/features/tracks/create_track_screen.dart` - CR-03 global invalidate, WR-02 validators
- `lib/features/tracks/confirm_delete_track_dialog.dart` - CR-03 global invalidate
- `lib/features/songs/tracks_screen.dart` - "View bands" wired to `selectedTabIndexProvider`; `_buildEmptyState`/`_buildContent` threaded with `WidgetRef`
- `lib/navigation/root_scaffold.dart` - Converted to `ConsumerWidget` reading `selectedTabIndexProvider`
- `test/features/tracks/edit_track_screen_test.dart` - CR-01/CR-02/CR-03/WR-02 regression tests + parametrized `wrap()` helper
- `test/features/tracks/create_track_screen_test.dart` - CR-03/WR-02 regression tests
- `test/features/tracks/confirm_delete_track_dialog_test.dart` - CR-03 regression test
- `test/providers/navigation_provider_test.dart` - New file, `SelectedTabIndex` unit tests
- `test/widget_test.dart` - WR-01 end-to-end regression test

## Decisions Made
- `updateBandTrack`'s `title`/`artist` parameters changed from optional nullable to required non-nullable — the method's only caller (`EditTrackScreen`) always has both from its form; the stricter signature documents the always-send-all-fields contract at the type level and costs no call-site changes
- `createBandTrack` intentionally left unchanged (still conditional-guard body) — there is no "old value" to clear on create, so the CR-02 fix applies only to `updateBandTrack`
- All three CR-03 global-invalidate call sites use `ref.exists(userTracksListDataProvider)` as a guard rather than an unconditional invalidate, mirroring the existing `trackDetailDataProvider` exists-guard pattern from 03-02 — avoids instantiating (and network-fetching) a global tab the user hasn't visited yet in the current session

## Deviations from Plan

None - plan executed exactly as written. All 5 tasks matched their `<action>`/`<acceptance_criteria>` blocks; no Rule 1-4 auto-fixes or architectural changes were needed.

## Issues Encountered

Task 1 and Task 2 both modify `edit_track_screen.dart` and its test file in different, non-overlapping regions. To keep each task's commit atomic and isolated (per the executor's one-commit-per-task protocol), Task 2's edits were temporarily reverted before Task 1's commit, then re-applied for Task 2's commit — no functional impact, both tasks' verification passed independently before each commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- TRACK-04 (edit a track) and TRACK-06 (global Tracks tab) — both `BLOCKED` in `03-VERIFICATION.md`'s Requirements Coverage table — are now unblocked: editing no longer crashes or silently drops clears, and the global tab stays in sync with per-band mutations with a working "View bands" affordance
- `flutter analyze` and `flutter test` (145 tests, up from 135 pre-existing) both pass clean
- Phase 03's goal ("Band members can maintain their band's song catalog") is now fully achieved per `03-VERIFICATION.md`'s 5 identified gaps; no further gap-closure plans expected for this phase
- No scope beyond the 5 named gaps was introduced

---
*Phase: 03-tracks*
*Completed: 2026-08-16*

## Self-Check: PASSED

All created files verified present on disk (lib/providers/navigation_provider.dart, lib/providers/navigation_provider.g.dart, test/providers/navigation_provider_test.dart, this SUMMARY.md). All 5 task commit hashes (5442431, 687657b, 93cae88, c611a34, 8e44655) verified present in `git log --oneline --all`.
