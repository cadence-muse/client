---
phase: 02-bands
plan: 05
subsystem: ui
tags: [flutter, riverpod, dart, rest-api, destructive-actions]

requires:
  - phase: 02-bands (02-02)
    provides: BandDetailData family AsyncNotifier, BandDetailScreen
  - phase: 02-bands (02-04)
    provides: BandDetailScreen structure to extend with owner-gated actions

provides:
  - "PublicApi.deleteBand(bandId) — DELETE /api/band/{bandId}"
  - "PublicApi.removeMember({bandId, userId}) — DELETE /api/band/{bandId}/remove-member/{userId} (shared by self-leave and owner-remove)"
  - "BandDetailScreen._isOwner/_ownershipStatus — tri-state owner gate (owner/member/unresolved) computed inside profileDataProvider's .when(data:) branch"
  - "ConfirmDeleteBandDialog — type-to-confirm exact-match dialog, owner-only"
  - "ConfirmLeaveBandDialog — standard confirm dialog for self-leave"
  - "ConfirmRemoveMemberDialog — standard confirm dialog for owner-remove"
affects: [02-bands]

actuals:
  tokens: 8457
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Tri-state ownership gate (bool?): true=owner, false=resolved-non-owner, null=profile-not-yet-loaded — owner-only AND member-only UI both stay hidden while null, so neither Delete nor Leave ever renders before profile data resolves (RESEARCH.md Pitfall 2)"
    - "Destructive-action navigation depth is always dialog -> detail -> list; success handlers invalidate the relevant provider first, then perform a literal double Navigator.pop() (dialog, then detail) rather than popUntil"
    - "Member removal always targets BandMember.id (server-returned), never a username match — same principle as the ownerId comparison"

key-files:
  created:
    - lib/features/bands/confirm_delete_band_dialog.dart
    - lib/features/bands/confirm_leave_band_dialog.dart
    - lib/features/bands/confirm_remove_member_dialog.dart
  modified:
    - lib/api/public_api.dart
    - lib/features/bands/band_detail_screen.dart
    - test/features/bands/band_detail_screen_test.dart

key-decisions:
  - "deleteBand()/removeMember() both return void — both operations are '204' no content per publicapi.yml, matching the established updateBand() void-return pattern from 02-04"
  - "Delete/Leave rendered as ListTile rows within the detail screen's ListView (matching UI-SPEC's 'Actions' section), not as AppBar icons like Edit — their copy (band-name-interpolated titles) needs more room than an AppBar action affords"
  - "Remove member uses an IconButton (Icons.person_remove) on the member's own row rather than a swipe-to-delete or separate list, matching UI-SPEC E3's 'trailing Remove icon shown only when current user is the band owner'"
  - "Leave/Delete success invalidates bandsListDataProvider (the list the user returns to); Remove-member success invalidates bandDetailDataProvider(bandId) only (the acting owner stays on the detail screen) — per D-15 vs. RESEARCH.md Pitfall 5 respectively"

patterns-established:
  - "Tri-state (bool?) ownership gate for TOCTOU-safe owner/non-owner UI: computed once per build from profileAsync.maybeWhen(data: ..., orElse: () => null), consumed by both 'show if true' (Delete, Remove) and 'show if false' (Leave) branches so a null (unresolved) state never leaks into either"

requirements-completed: [BAND-05, BAND-08, BAND-09]

coverage:
  - id: D1
    description: "Band owner sees and can use 'Delete', with type-to-confirm requiring an exact (case-sensitive, untrimmed) match to the band name before the Delete button enables; non-owners never see it (BAND-05)"
    requirement: "BAND-05"
    verification:
      - kind: unit
        ref: 'test/features/bands/band_detail_screen_test.dart#owner sees a "Delete" action, non-owner does not (delete)'
        status: pass
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#Delete button stays disabled until typed text exactly matches the band name (delete)"
        status: pass
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#confirming Delete calls deleteBand, invalidates the bands list, and returns to the Bands list (delete)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Any non-owner member sees and can use 'Leave' via a standard confirm dialog, targeting their own id from profileDataProvider; the owner never sees it (BAND-08)"
    requirement: "BAND-08"
    verification:
      - kind: unit
        ref: 'test/features/bands/band_detail_screen_test.dart#non-owner sees a "Leave" action, owner does not (leave)'
        status: pass
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#confirming Leave calls removeMember with the current user's own id, invalidates the bands list, and returns to the Bands list (leave)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Band owner sees a per-member 'Remove' icon on every other member's row (never their own), and can remove a member via a standard confirm dialog; the members list refreshes without leaving the detail screen (BAND-09)"
    requirement: "BAND-09"
    verification:
      - kind: unit
        ref: 'test/features/bands/band_detail_screen_test.dart#owner sees a "Remove" icon on other members'' rows but never on their own row; non-owner never sees it (remove-member)'
        status: pass
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#confirming Remove calls removeMember with that member's id, invalidates the band detail, and the removed member disappears from the members list without leaving the detail screen (remove-member)"
        status: pass
    human_judgment: false
  - id: D4
    description: "All three destructive dialogs (Delete/Leave/Remove) surface an ApiException's message inline on mutation failure and re-enable their confirm button (UI-SPEC E7/E8/E9 Error backstop)"
    verification:
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#a Delete failure surfaces an inline error and re-enables the Delete button (remove-member error backstop)"
        status: pass
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#a Leave failure surfaces an inline error and re-enables the Leave button (remove-member error backstop)"
        status: pass
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#a Remove failure surfaces an inline error and re-enables the Remove button (remove-member error backstop)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Owner-gating race condition (TOCTOU): Delete/Leave/Remove never render before profileDataProvider resolves, avoiding a race-conditioned Leave/Delete button on stale data"
    verification:
      - kind: unit
        ref: "code review: BandDetailScreen._ownershipStatus returns null (hides both Delete and Leave) via profileAsync.maybeWhen(data: ..., orElse: () => null) until profile data resolves"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-08-15
status: complete
---

# Phase 02 Plan 05: Delete/Leave/Remove-Member Summary

**Owner-gated Delete band (type-to-confirm), self-Leave, and owner-Remove-member all wired end-to-end onto `BandDetailScreen`, sharing a single `PublicApi.removeMember` endpoint and a tri-state (`bool?`) ownership gate that never renders owner/member-only actions before `profileDataProvider` resolves.**

## Performance

- **Duration:** 20 min
- **Tasks:** 3
- **Files modified:** 6 (3 created, 3 modified)

## Accomplishments
- `PublicApi.deleteBand(bandId)` — `DELETE /api/band/{bandId}`, 204 no content
- `PublicApi.removeMember({bandId, userId})` — `DELETE /api/band/{bandId}/remove-member/{userId}`, 204 no content, shared by self-leave and owner-remove
- `BandDetailScreen` gained a tri-state `_isOwner`/`_ownershipStatus` gate (`true`=owner, `false`=resolved-non-owner, `null`=profile still loading) computed inside `profileDataProvider`'s `.when(data:)` branch — Delete/Leave/Remove never render optimistically before ownership resolves
- `ConfirmDeleteBandDialog` — exact-match (case-sensitive, untrimmed) type-to-confirm dialog; on success invalidates `bandsListDataProvider` then double-pops (dialog → detail) back to the Bands list
- `ConfirmLeaveBandDialog` — standard confirm dialog targeting the current user's own id from `profileDataProvider`; same invalidate + double-pop pattern
- `ConfirmRemoveMemberDialog` — standard confirm dialog interpolating username + band name; on success invalidates only `bandDetailDataProvider(bandId)`, keeping the acting owner on the detail screen
- Per-member "Remove" `IconButton` shown only when `isOwner == true && memberUserId != ownerId` — never on the owner's own row
- All three destructive dialogs have error-path coverage (inline `ApiException.message`, re-enabled confirm button)

## Task Commits

Each task was committed atomically:

1. **Task 1: Owner-gating helper + end-to-end DELETE /api/band/{bandId} with type-to-confirm (BAND-05)** - `ebf67bd` (feat)
2. **Task 2: End-to-end self-leave via removeMember (BAND-08)** - `7698f88` (feat)
3. **Task 3: End-to-end owner-remove-member + destructive-action error coverage (BAND-09)** - `74f4408` (feat)

_Note: Task 1 was `type="tracer"` with `tdd="true"`; its automated `<verify>` (`flutter test test/features/bands/band_detail_screen_test.dart --plain-name "delete"`) passed before proceeding to Task 2's expansion. This executor ran as a sequential main-tree agent with `human_verify_mode: end-of-phase` configured project-wide, and the plan is `autonomous: true` with no `checkpoint:*` tasks — consistent with 02-04's precedent, the automated `<verify>` pass was treated as satisfying the tracer feedback gate, with the tracer's `<human-check>` deferred to phase-level sign-off._

**Plan metadata:** (this commit)

## Files Created/Modified
- `lib/api/public_api.dart` - Added `deleteBand(bandId)` and `removeMember({bandId, userId})`
- `lib/features/bands/band_detail_screen.dart` - Added `_isOwner`/`_ownershipStatus` tri-state gate, Delete/Leave ListTile actions, per-member Remove `IconButton`
- `lib/features/bands/confirm_delete_band_dialog.dart` - New: type-to-confirm Delete dialog
- `lib/features/bands/confirm_leave_band_dialog.dart` - New: standard confirm Leave dialog
- `lib/features/bands/confirm_remove_member_dialog.dart` - New: standard confirm Remove dialog
- `test/features/bands/band_detail_screen_test.dart` - Added `wrapWithListRoot`/`buildRoutedApiClient` test helpers, delete/leave/remove-member visibility, success-flow, and error-backstop tests (13 new tests)

## Decisions Made
- `deleteBand()`/`removeMember()` both return `void` — both are `'204'` no-content operations per `publicapi.yml`, matching `updateBand()`'s established void-return pattern from 02-04
- Delete/Leave rendered as `ListTile` rows inside the ListView's Actions section (not AppBar icons like Edit) — their interpolated copy needs more horizontal room than an AppBar action affords
- Remove-member success invalidates `bandDetailDataProvider(bandId)` only (not the list) since the acting owner stays on the detail screen — Leave/Delete invalidate `bandsListDataProvider` since those return the user to the list (RESEARCH.md Pitfall 5 vs. D-15)
- Added a `wrapWithListRoot` test helper (a fake list-root screen with a push button) so the delete/leave success tests can assert the full dialog → detail → list double-pop actually lands on the underlying screen, not just that the dialog closed

## Deviations from Plan

None — plan executed exactly as written. One minor tooling note: the plan's stated verification commands use `flutter test ... -k "delete"`, but Flutter's test runner doesn't support a `-k` flag (that's a `dart test`/pytest-ism); the equivalent and actually-supported flag is `--plain-name`. All three tasks' acceptance criteria were verified with `--plain-name` instead, with identical filtering semantics (substring match on the test description).

## Issues Encountered
None.

## Next Phase Readiness
- BAND-05, BAND-08, and BAND-09 are fully satisfied: the band owner can delete the band (type-to-confirm) or remove any other member; any non-owner member can leave; owner-gating is TOCTOU-safe (tri-state, never renders before profile resolves) in all three cases.
- Phase 02 (Bands) is now feature-complete per its ROADMAP.md success criteria: list/create/view/update/delete bands, join via invite code, leave/remove-member — all wired end-to-end with cache-first loading.
- The `human-check` items from Task 1's tracer `<verify>` (owner-only Delete visibility, type-to-confirm gating, successful delete) and Task 3's `<human-check>` (per-row Remove icon visibility, member disappearing without leaving the detail screen) are deferred to end-of-phase manual sign-off per `human_verify_mode: end-of-phase` — flagging for the phase verifier.
- No blockers for Phase 02 sign-off or Phase 3 (Tracks) kickoff.

---
*Phase: 02-bands*
*Completed: 2026-08-15*

## Self-Check: PASSED

All claimed files verified present on disk (`lib/api/public_api.dart`, `lib/features/bands/band_detail_screen.dart`, `lib/features/bands/confirm_delete_band_dialog.dart`, `lib/features/bands/confirm_leave_band_dialog.dart`, `lib/features/bands/confirm_remove_member_dialog.dart`, `test/features/bands/band_detail_screen_test.dart`). All claimed commit hashes (`ebf67bd`, `7698f88`, `74f4408`) verified present in `git log`.
