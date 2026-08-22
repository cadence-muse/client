---
phase: 06-foundation-info-settings-polish
plan: 04
subsystem: ui
tags: [flutter, riverpod, setlists, icon-row]

# Dependency graph
requires:
  - phase: 06-01
    provides: "SetlistListItem.eventLocation field on the setlist list API response"
provides:
  - "Setlist list rows show location (Icons.location_on, tap-to-expand) and duration (Icons.timer) icon indicators, replacing the old 'N tracks, Xm Ys' trailing text"
  - "Setlist detail screen shows icon rows for location and duration, replacing plain/prefixed text"
affects: [setlist-display, setlists-tab]

# Actuals (#2632)
actuals:
  tokens: 2879
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Trailing icon-row pattern for list screens: SizedBox(width: N) constraining a Row(mainAxisAlignment: end), with a Flexible-wrapped optional field (icon+text) and an always-shown field (icon+text) — Text needing ellipsis truncation must itself be wrapped in a nested Flexible, since a bounded-width ancestor alone does not propagate a max-width constraint through an intermediate mainAxisSize.min Row"
    - "Detail screen icon rows: Row(children: [Icon(size: 20, color: colorScheme.primary), SizedBox(width: 8), Text/Expanded(Text)]) replacing prefixed/plain Text, mirroring Plan 06-03's Track detail pattern"

key-files:
  created: []
  modified:
    - lib/features/setlists/setlist_list_screen.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - test/features/setlists/setlist_list_screen_test.dart
    - test/features/setlists/setlist_detail_screen_test.dart

key-decisions:
  - "Removed the now-unused tracksCount local variable in setlist_list_screen.dart's itemBuilder rather than keeping a dead read, since the new trailing icon row no longer displays track count and no other part of the row uses it"
  - "Wrapped the location GestureDetector in an outer Flexible and its inner Text in a further nested Flexible — the plan's literal widget tree (SizedBox(150) -> Row(mainAxisSize.min) -> GestureDetector -> Row(mainAxisSize.min) -> Text(maxLines/overflow)) overflowed by up to 1102px in testing because ellipsis truncation requires a bounded max-width ancestor, which mainAxisSize.min rows alone do not provide to a non-flex child"

requirements-completed: [SETL-11]

coverage:
  - id: D1
    description: "Setlist list rows show a location icon+value only when eventLocation is present (tap-to-expand via SnackBar, no navigation triggered), and always show a duration icon+value"
    requirement: SETL-11
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#a setlist with eventLocation shows the location icon+value alongside the duration icon"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#a setlist with no eventLocation omits the location icon but still shows duration"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_list_screen_test.dart#tapping a long location text shows a SnackBar with the full text and does not navigate to SetlistDetailScreen"
        status: pass
    human_judgment: false
  - id: D2
    description: "Setlist detail screen shows icon rows (not label-prefixed text) for location (when present) and duration (always)"
    requirement: SETL-11
    verification:
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#a full BandSetlist response renders name/location/date/duration/tracks"
        status: pass
      - kind: automated_ui
        ref: "test/features/setlists/setlist_detail_screen_test.dart#eventLocation/eventDate are omitted entirely (no placeholder) when both are null"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-21
status: complete
---

# Phase 06 Plan 04: Setlist Location/Duration Icons Summary

**Setlist list and detail screens now show `Icons.location_on`/`Icons.timer` icon-based indicators for event location and duration, replacing the old "N tracks, Xm Ys" trailing text and "Duration: ..." prefixed label.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-21
- **Completed:** 2026-08-21
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Setlist list rows now show a `location_on` icon + value only when `eventLocation` is present (tap-to-expand via SnackBar, does not trigger row navigation) and a `timer` icon + duration value always, replacing `tracksAndDuration`'s old trailing text on this screen only.
- Setlist detail screen now shows icon rows for location (when present) and duration (always), dropping the "Duration:" text prefix, matching the Track detail screen's icon+inline-row style established in Plan 06-03.
- `lib/features/setlists/setlist_formatting.dart` (`tracksAndDuration`/`pluralizeTracks`) is untouched — the separate cross-band Setlists tab (`setlists_screen.dart`) still calls it directly and its tests still pass.

## Task Commits

Each task was committed atomically:

1. **Task 1: Setlist list -- location + duration icon row** - `604af27` (feat)
2. **Task 2: Setlist detail -- icon rows for location/duration** - `8f44922` (feat)

**Plan metadata:** (this SUMMARY commit, made separately per parallel-executor convention)

## Files Created/Modified
- `lib/features/setlists/setlist_list_screen.dart` - Trailing row replaced with location/duration icon row
- `lib/features/setlists/setlist_detail_screen.dart` - Header location/duration rows replaced with icon rows
- `test/features/setlists/setlist_list_screen_test.dart` - Rewrote 2 old-format assertions; added 3 new tests
- `test/features/setlists/setlist_detail_screen_test.dart` - Updated duration assertions in 2 tests, added icon assertions

## Decisions Made
- Removed the unused `tracksCount` local variable from the list screen's `itemBuilder` since the new trailing content no longer reads it and no other part of the row does either.
- Fixed a layout overflow bug in the plan's literal widget tree: nested the location `GestureDetector` in an outer `Flexible` and its `Text` in a further inner `Flexible` so ellipsis truncation actually takes effect within the `SizedBox(width: 150)` trailing slot — the plan's as-written structure (bounded `SizedBox` -> `mainAxisSize.min` rows -> `Text(maxLines/overflow)` with no `Flexible` ancestor) overflowed the `RenderFlex` by up to 1102px during test execution because ellipsis clipping requires a bounded max-width constraint that intermediate `mainAxisSize.min` rows do not propagate to a non-flex child on their own.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Location text overflowed the trailing icon row instead of truncating with ellipsis**
- **Found during:** Task 1 (running `flutter test test/features/setlists/setlist_list_screen_test.dart` after implementing the plan's literal widget tree)
- **Issue:** The plan's specified widget tree wraps `eventLocation`'s `Text(maxLines: 1, overflow: TextOverflow.ellipsis)` inside two `mainAxisSize: MainAxisSize.min` `Row`s, with no `Flexible`/`Expanded` ancestor giving the `Text` a bounded max width. `maxLines`/`overflow` on `Text` only clip when the widget actually receives a bounded width constraint; without one, `Text` sizes to its natural (unclipped) width, causing `RenderFlex` overflow (140px in the basic present-location test, 1102px in the long-location tap test) and a failed hit-test on the overflowed `Text` in the tap-to-expand test.
- **Fix:** Wrapped the location `GestureDetector` in an outer `Flexible` (letting it shrink within the outer bounded `SizedBox(width: 150)` `Row`) and wrapped its inner `Text` in a further nested `Flexible` (letting the icon keep its natural size while the text alone absorbs the remaining space and truncates). No visible-text or icon changes — same string, same icons, same tap behavior; only the layout constraints changed.
- **Files modified:** `lib/features/setlists/setlist_list_screen.dart`
- **Verification:** `flutter test test/features/setlists/setlist_list_screen_test.dart` — all 9 tests pass, no `RenderFlex overflowed` errors; `flutter analyze` clean.
- **Committed in:** `604af27` (Task 1 commit)

**2. [Rule 1 - Bug] "zero tracks" detail test still asserted the removed "Duration:" prefix**
- **Found during:** Task 2 (running `flutter test test/features/setlists/setlist_detail_screen_test.dart` after implementing the plan's action for the "full BandSetlist" test)
- **Issue:** The plan's `<action>` only named the `'a full BandSetlist response...'` test for updating the duration assertion, but the production change (dropping the `'Duration: '` prefix) also broke the separate `'zero tracks shows "No tracks in this setlist" and "Duration: 0m 0s"'` test, which asserts `find.text('Duration: 0m 0s')` — a directly in-scope consequence of this task's own file change, not a pre-existing unrelated failure.
- **Fix:** Updated the test name and its assertion to `find.text('0m 0s')`, matching the same unprefixed format applied to the other test.
- **Files modified:** `test/features/setlists/setlist_detail_screen_test.dart`
- **Verification:** `flutter test test/features/setlists/setlist_detail_screen_test.dart` — all 17 tests pass.
- **Committed in:** `8f44922` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs directly caused by this plan's own changes)
**Impact on plan:** Both fixes were necessary for the plan's stated `<verify>`/`<acceptance_criteria>` to actually pass; no scope creep beyond the two touched screens/tests.

## Issues Encountered
None beyond the two auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 06's third and final display vertical (Track icons in 06-03, Setlist icons here) is complete; all three of `flutter test test/features/setlists/`, `flutter test test/features/setlists/setlists_screen_test.dart` (untouched cross-band tab), and `flutter analyze` (whole repo) pass clean.
- No blockers for subsequent Phase 06 plans or later phases.

---
*Phase: 06-foundation-info-settings-polish*
*Completed: 2026-08-21*
