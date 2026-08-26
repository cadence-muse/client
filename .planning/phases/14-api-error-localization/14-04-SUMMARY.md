---
phase: 14-api-error-localization
plan: 04
subsystem: ui
tags: [flutter, i18n, error-handling, api-exception, setlists]

# Dependency graph
requires:
  - phase: 14-01
    provides: "ApiExceptionLocalization extension (e.localizedMessage(l10n)) and the 5 commonErrorX ARB keys"
provides:
  - "All 5 remaining setlist-feature on ApiException catch sites (create, edit, delete, remove-track, add-tracks) call e.localizedMessage(l10n) for the 5 known ErrorCode values, falling back to raw e.message for unknown/null codes"
  - "setlist_detail_screen.dart's remove-track SnackBar preserved as-is, only its message source changed"
affects: []

# Actuals (#2632)
actuals:
  tokens: 1711
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Catch sites whose l10n local is declared only inside the try block's success path (or not at all) get a fresh `final l10n = AppLocalizations.of(context)!;` fetch added directly inside the on ApiException catch block itself, mirroring the sibling catch (_) block's own pre-existing fetch."
    - "SnackBar-based error display (setlist_detail_screen.dart's remove-track) keeps its display mechanism unchanged — only the message source swaps to e.localizedMessage(l10n), guarded by the same pre-existing mounted check."

key-files:
  created: []
  modified:
    - lib/features/setlists/create_setlist_screen.dart
    - lib/features/setlists/edit_setlist_screen.dart
    - lib/features/setlists/confirm_delete_setlist_dialog.dart
    - lib/features/setlists/setlist_detail_screen.dart
    - lib/features/setlists/add_setlist_tracks_dialog.dart
    - test/features/setlists/create_setlist_screen_test.dart
    - test/features/setlists/add_setlist_tracks_dialog_test.dart

key-decisions:
  - "No mounted guard added to create_setlist_screen.dart's or add_setlist_tracks_dialog.dart's new l10n fetch inside their on ApiException blocks, matching those blocks' own pre-existing behavior (only the sibling catch (_) block guards with mounted in those two files)."
  - "setlist_detail_screen.dart's new l10n fetch in _removeTrack() is placed after the existing if (!mounted) return; guard, matching that file's own local convention (unlike the other two files in this plan)."

patterns-established: []

requirements-completed: [I18N-05]

coverage:
  - id: D1
    description: "create_setlist_screen.dart's on ApiException catch site shows the ARB-localized generic message for a known error code (permission_denied), not raw server text"
    requirement: "I18N-05"
    verification:
      - kind: unit
        ref: "test/features/setlists/create_setlist_screen_test.dart#a createSetlist() ApiException with a known error code renders the localized generic message, not the raw server text"
        status: pass
    human_judgment: false
  - id: D2
    description: "edit_setlist_screen.dart and confirm_delete_setlist_dialog.dart on ApiException catch sites call e.localizedMessage(l10n) with no new l10n fetch (already in scope)"
    requirement: "I18N-05"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/setlists/edit_setlist_screen.dart lib/features/setlists/confirm_delete_setlist_dialog.dart"
        status: pass
    human_judgment: true
    rationale: "No existing widget test exercises edit_setlist_screen.dart's or confirm_delete_setlist_dialog.dart's ApiException catch path with a known error code; the call-site swap is proven correct by analyzer + code inspection, not by a dedicated failing-path test, so a human should visually confirm the localized string renders."
  - id: D3
    description: "setlist_detail_screen.dart's remove-track SnackBar shows the localized generic message for a known error code, preserving its SnackBar (not inline-Text) display mechanism"
    requirement: "I18N-05"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/setlists/setlist_detail_screen.dart"
        status: pass
    human_judgment: true
    rationale: "No existing widget test exercises _removeTrack()'s ApiException catch path; verified by analyzer + code inspection only. Recommend a human spot-check the remove-track SnackBar with a simulated known-code failure."
  - id: D4
    description: "add_setlist_tracks_dialog.dart's on ApiException catch site shows the ARB-localized generic message for a known error code (operation_rejected), not raw server text"
    requirement: "I18N-05"
    verification:
      - kind: unit
        ref: "test/features/setlists/add_setlist_tracks_dialog_test.dart#an addSetlistTracks() ApiException with a known error code renders the localized generic message, not the raw server text"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-08-26
status: complete
---

# Phase 14 Plan 04: Setlist-Feature API Error Localization Summary

**Wired the last 5 setlist-feature `on ApiException catch (e)` sites (create/edit/delete-setlist, remove-track SnackBar, add-tracks) to `ApiExceptionLocalization.localizedMessage()`, completing Phase 14's full-app catch-site coverage.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-08-26 (worktree execution)
- **Completed:** 2026-08-26
- **Tasks:** 2
- **Files modified:** 7 (5 source, 2 test)

## Accomplishments
- `create_setlist_screen.dart` and `add_setlist_tracks_dialog.dart` each gained a local `l10n` fetch inside their `on ApiException catch (e)` block (their pre-existing `l10n` local was only in scope inside the try block's success path).
- `edit_setlist_screen.dart` and `confirm_delete_setlist_dialog.dart` were mechanical call-site swaps — `l10n` was already in scope.
- `setlist_detail_screen.dart`'s `_removeTrack()` SnackBar now shows `e.localizedMessage(l10n)` instead of raw `e.message`, with the SnackBar display mechanism and its existing `mounted` guard preserved unchanged.
- Added a `permission_denied` regression test to `create_setlist_screen_test.dart` and an `operation_rejected` regression test to `add_setlist_tracks_dialog_test.dart`, both asserting the localized generic message renders and the raw server text does not.
- With this plan, all ~20 in-scope `on ApiException catch (e)` sites across the app (Phases 14-01 through 14-04) now call `localizedMessage()` — ROADMAP Phase 14 success criteria 1 and 2 are fully met.

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire create/edit/delete-setlist catch sites (one needs a new l10n fetch)** - `c53269c` (feat)
2. **Task 2: Wire remove-track (SnackBar) and add-tracks catch sites (both need a new l10n fetch)** - `481e821` (feat)

_No plan-metadata commit — orchestrator owns STATE.md/ROADMAP.md updates centrally after all wave agents complete (parallel worktree execution)._

## Files Created/Modified
- `lib/features/setlists/create_setlist_screen.dart` - `on ApiException catch (e)` block gained its own `l10n` fetch and now calls `e.localizedMessage(l10n)`
- `lib/features/setlists/edit_setlist_screen.dart` - `on ApiException catch (e)` block swapped to `e.localizedMessage(l10n)` using the already-in-scope `l10n`
- `lib/features/setlists/confirm_delete_setlist_dialog.dart` - `on ApiException catch (e)` block swapped to `e.localizedMessage(l10n)` using the already-in-scope `l10n`
- `lib/features/setlists/setlist_detail_screen.dart` - `_removeTrack()`'s `on ApiException catch (e)` block gained a local `l10n` fetch (after its `mounted` guard) and its SnackBar now shows `e.localizedMessage(l10n)`
- `lib/features/setlists/add_setlist_tracks_dialog.dart` - `on ApiException catch (e)` block gained its own `l10n` fetch and now calls `e.localizedMessage(l10n)`
- `test/features/setlists/create_setlist_screen_test.dart` - added a `permission_denied` case asserting the localized message renders, raw server text does not
- `test/features/setlists/add_setlist_tracks_dialog_test.dart` - added an `operation_rejected` case asserting the localized message renders, raw server text does not

## Decisions Made
- No `mounted` guard added ahead of the new `l10n` fetch in `create_setlist_screen.dart`'s or `add_setlist_tracks_dialog.dart`'s `on ApiException` blocks — matches those blocks' own pre-existing behavior (only their sibling `catch (_)` blocks guard with `mounted`).
- `setlist_detail_screen.dart`'s new `l10n` fetch is placed after the existing `if (!mounted) return;` guard in `_removeTrack()`, matching that file's own local convention (its `catch (_)` block one branch below already does this).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 14's full catch-site sweep (14-01 through 14-04) is complete once all wave plans land — every in-scope `on ApiException catch (e)` site in the app now routes through `localizedMessage()`. No blockers for downstream work. This was the last plan in Phase 14's scope.

---
*Phase: 14-api-error-localization*
*Completed: 2026-08-26*
