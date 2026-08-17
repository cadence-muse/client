---
phase: 04-setlists
fixed_at: 2026-08-17T06:30:19Z
review_path: .planning/phases/04-setlists/04-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-08-17T06:30:19Z
**Source review:** .planning/phases/04-setlists/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4 (WR-01 .. WR-04 — `fix_scope: critical_warning`; REVIEW.md reported 0 Critical findings, 3 Info findings out of scope)
- Fixed: 4
- Skipped: 0

## Fixed Issues

### WR-01: Global cross-band Setlists tab cache never invalidated after band-scoped mutations

**Files modified:** `lib/features/setlists/create_setlist_screen.dart`, `lib/features/setlists/edit_setlist_screen.dart`, `lib/features/setlists/confirm_delete_setlist_dialog.dart`, `lib/features/setlists/add_setlist_tracks_dialog.dart`, `lib/features/setlists/setlist_detail_screen.dart`
**Commit:** `2d0e979`
**Applied fix:** Added `if (ref.exists(userSetlistsListDataProvider)) { ref.invalidate(userSetlistsListDataProvider); }` alongside every existing `setlistListDataProvider`/`setlistDetailDataProvider` invalidate/refresh call site across all six mutation flows (create, edit, delete, add-tracks, remove-track, reorder), mirroring the existing `ref.exists(...)` guard pattern already used in this feature.

### WR-02: Track-list load failures are silently rendered as "no tracks" rather than surfaced as errors

**Files modified:** `lib/features/setlists/create_setlist_screen.dart`, `lib/features/setlists/add_setlist_tracks_dialog.dart`
**Commit:** `3b22388`
**Applied fix:** Replaced the `error:` branch of `trackListDataProvider(bandId)`'s `AsyncValue.when` in both `CreateSetlistScreen` and `AddSetlistTracksDialog` — previously identical to the empty-list copy — with a distinct "Couldn't load tracks" message plus an inline Retry button that calls `ref.invalidate(trackListDataProvider(bandId))`. Verified this doesn't collide with the two existing tests that assert on the empty-list-specific copy (those cover the `data: (tracks) { if (tracks.isEmpty) ... }` branch, untouched here).

### WR-03: No client-side enforcement of the documented 100-track cap for bulk track operations

**Files modified:** `lib/features/setlists/add_setlist_tracks_dialog.dart`, `lib/features/setlists/create_setlist_screen.dart`, `lib/features/setlists/setlist_detail_screen.dart`
**Commit:** `4fb5d01`
**Applied fix:** The API contract (`publicapi.yml`) does not expose a distinguishable error `code` for the 100-track-cap violation, so pursued the review's "ideally" alternative — client-side cap enforcement — rather than the "at minimum" error-code-inspection option:
- `AddSetlistTracksDialog`: computes `remainingSlots = 100 - currentTrackIds.length`; disables further selection once the remaining-slot budget is reached (checkbox `onChanged: null` past the cap), shows "already has the maximum of 100 tracks" when no slots remain, and an inline "N slots remaining" hint as the budget is approached.
- `CreateSetlistScreen`: same flat-100 guard on its track checklist (no pre-existing tracks to offset against).
- `SetlistDetailScreen._handleReorder`: added a pre-flight guard — since `_handleReorder` always submits the *entire* current track list (by design, per its doc comment), a setlist that has grown past 100 tracks would otherwise have every future reorder deterministically fail behind the misleading "Failed to reorder tracks. Refreshing..." copy. Now short-circuits before the doomed network call with a specific "Can't reorder — this setlist has more than 100 tracks." message.

### WR-04: `_removeTrack` has no in-flight guard against rapid repeated taps

**Files modified:** `lib/features/setlists/setlist_detail_screen.dart`
**Commit:** `c0edb80`
**Applied fix:** Added a `Set<String> _removingTrackIds` field tracking in-flight removals. `_removeTrack` no-ops (returns early) if the given `trackId` is already mid-removal, and the row's remove `IconButton` is swapped for a small `CircularProgressIndicator` while that track's removal is in flight — consistent with the `_isSubmitting`-disables-trigger pattern used by every other mutating action in this feature (create/edit/delete/add-tracks).

## Skipped Issues

None — all in-scope findings were fixed.

---

**Verification performed:**
- `dart analyze lib/` — no issues found (ran with a `.dart_tool` copied from the main checkout into the isolated worktree to enable full package-resolved analysis, since the worktree has no independent `flutter pub get` history).
- `flutter analyze` — no issues found (0 warnings/lints across the full project after all four fixes).
- `flutter test` — full suite (211 tests) passes, including all pre-existing `test/features/setlists/*_test.dart` suites (49 tests) that exercise the modified files.
- All verification ran inside the isolated `git worktree` created for this fix run (`.claude/worktrees/rf-04-*`), not the main checkout; results are reproducible by re-running `flutter analyze && flutter test` against the fast-forwarded `main` branch after cleanup.

_Fixed: 2026-08-17T06:30:19Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
