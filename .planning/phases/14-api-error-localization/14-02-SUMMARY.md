---
phase: 14-api-error-localization
plan: 02
subsystem: ui
tags: [flutter, dart, l10n, error-handling, api-exception]

# Dependency graph
requires:
  - phase: 14-01
    provides: ApiExceptionLocalization extension (localizedMessage) on ApiException, ARB error-code keys, generated AppLocalizations getters
provides:
  - All 7 Bands-feature `on ApiException catch (e)` sites (edit band, delete band, remove member, leave band, rotate invite code, transfer ownership, join band) call `e.localizedMessage(l10n)` instead of `e.message`
  - Regression tests proving known-error-code -> localized-message mapping on 2 representative Bands-feature sites (edit-band `permission_denied`, rotate-invite-code `operation_rejected`)
affects: [14-03, 14-04]

# Actuals (#2632)
actuals:
  tokens: 1784
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mechanical call-site swap: `on ApiException catch (e) { setState(() => _errorMessage = e.message); }` -> `e.localizedMessage(l10n)` with no other changes to the catch/finally blocks, using the already-in-scope `l10n` local at each site."

key-files:
  created: []
  modified:
    - lib/features/bands/edit_band_screen.dart
    - lib/features/bands/confirm_delete_band_dialog.dart
    - lib/features/bands/confirm_remove_member_dialog.dart
    - lib/features/bands/confirm_leave_band_dialog.dart
    - lib/features/bands/confirm_rotate_invite_code_dialog.dart
    - lib/features/bands/confirm_transfer_ownership_dialog.dart
    - lib/features/bands/join_band_dialog.dart
    - test/features/bands/edit_band_screen_test.dart
    - test/features/bands/confirm_rotate_invite_code_dialog_test.dart

key-decisions: []

patterns-established: []

requirements-completed: [I18N-05]

coverage:
  - id: D1
    description: "All 7 Bands-feature `on ApiException catch (e)` sites show the ARB-localized generic message for a known error code (edit band, delete band, remove member, leave band, rotate invite code, transfer ownership, join band)"
    requirement: "I18N-05"
    verification:
      - kind: unit
        ref: "test/features/bands/edit_band_screen_test.dart#a known-error-code updateBand() failure renders the localized message, not the raw server text"
        status: pass
      - kind: unit
        ref: "test/features/bands/confirm_rotate_invite_code_dialog_test.dart#a known-error-code rotate failure renders the localized message, not the raw server text"
        status: pass
    human_judgment: false

# Metrics
duration: 18min
completed: 2026-08-26
status: complete
---

# Phase 14 Plan 2: Bands Catch-Site Localization Summary

**Mechanical one-line swap of `e.message` -> `e.localizedMessage(l10n)` across all 7 remaining Bands-feature `on ApiException catch (e)` sites, proven with 2 new known-error-code regression tests.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-26T17:56:00Z
- **Completed:** 2026-08-26T18:14:44Z
- **Tasks:** 2 completed
- **Files modified:** 9

## Accomplishments
- `edit_band_screen.dart`, `confirm_delete_band_dialog.dart`, `confirm_remove_member_dialog.dart`, `confirm_leave_band_dialog.dart` now show the ARB-localized generic message for known API error codes instead of raw server text
- `confirm_rotate_invite_code_dialog.dart`, `confirm_transfer_ownership_dialog.dart`, `join_band_dialog.dart` likewise wired to `localizedMessage(l10n)`
- New regression test on edit-band (`permission_denied` -> `commonErrorPermissionDenied`) and rotate-invite-code (`operation_rejected` -> `commonErrorOperationRejected`) prove the mapping end-to-end and confirm raw server text is no longer shown for known codes

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire edit/delete-band/remove-member/leave-band catch sites** - `7d064a1` (feat)
2. **Task 2: Wire rotate-invite-code/transfer-ownership/join-band catch sites** - `622379d` (feat)

_Note: no TDD tasks in this plan; single commit per task._

## Files Created/Modified
- `lib/features/bands/edit_band_screen.dart` - `_submit()` catch block calls `e.localizedMessage(l10n)`
- `lib/features/bands/confirm_delete_band_dialog.dart` - `_delete()` catch block calls `e.localizedMessage(l10n)`
- `lib/features/bands/confirm_remove_member_dialog.dart` - `_remove()` catch block calls `e.localizedMessage(l10n)`
- `lib/features/bands/confirm_leave_band_dialog.dart` - `_leave()` catch block calls `e.localizedMessage(l10n)`
- `lib/features/bands/confirm_rotate_invite_code_dialog.dart` - `_rotate()` catch block calls `e.localizedMessage(l10n)`
- `lib/features/bands/confirm_transfer_ownership_dialog.dart` - `_transfer()` catch block calls `e.localizedMessage(l10n)`
- `lib/features/bands/join_band_dialog.dart` - `_submit()` catch block calls `e.localizedMessage(l10n)`
- `test/features/bands/edit_band_screen_test.dart` - added known-error-code (`permission_denied`) regression test
- `test/features/bands/confirm_rotate_invite_code_dialog_test.dart` - added known-error-code (`operation_rejected`) regression test

## Decisions Made
None - plan executed exactly as written. All 7 sites already had `l10n` fetched in scope before their `try` block, matching the plan's stated assumption; no new `l10n` fetch was added anywhere.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- 14-01's `ApiExceptionLocalization` extension is now proven across two independent feature areas (auth/profile in 14-01, bands in 14-02), de-risking the identical mechanical swap still pending in 14-03 (auth/profile overrides + tracks) and 14-04 (setlists).
- No blockers for 14-03/14-04, which touch disjoint files (tracks/setlists/auth/profile) and share no state with this plan's changes.

---
*Phase: 14-api-error-localization*
*Completed: 2026-08-26*
