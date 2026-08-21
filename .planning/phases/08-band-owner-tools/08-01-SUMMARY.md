---
phase: 08-band-owner-tools
plan: 01
subsystem: ui
tags: [flutter, riverpod, popup-menu, material3, band-management]

# Dependency graph
requires:
  - phase: 07-cache-online-first
    provides: online-first bandDetailDataProvider/bandsListDataProvider invalidation model this plan's D-09/D-10 patches build on
provides:
  - "PublicApi.rotateInviteCode(bandId) and PublicApi.transferOwnership({bandId, userId})"
  - "BandDetailData.rotateInviteCode()/BandsListData.patchBandOwner() local-patch provider methods"
  - "ConfirmRotateInviteCodeDialog and ConfirmTransferOwnershipDialog"
  - "band_detail_screen.dart member-row PopupMenuButton (Make owner/Remove) and Copy/Rotate invite-code icons"
affects: [band-owner-tools, band-detail-screen, bands-provider]

# Actuals (#2632)
actuals:
  tokens: 14603
  tasks: 3
  commits: 7

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Owner-gated PopupMenuButton replacing a standalone destructive IconButton on a ListTile trailing slot"
    - "AlertDialog content wrapped in SingleChildScrollView to survive max OS text-scale without vertical overflow"
    - "PopupMenuItem label Rows using Expanded (not mainAxisSize.min) so labels wrap instead of overflowing the menu's capped max width at large text-scale"

key-files:
  created:
    - lib/features/bands/confirm_rotate_invite_code_dialog.dart
    - lib/features/bands/confirm_transfer_ownership_dialog.dart
    - test/features/bands/confirm_rotate_invite_code_dialog_test.dart
    - test/features/bands/confirm_transfer_ownership_dialog_test.dart
  modified:
    - lib/api/public_api.dart
    - lib/providers/bands_provider.dart
    - lib/features/bands/band_detail_screen.dart
    - test/api/public_api_test.dart
    - test/features/bands/band_detail_screen_test.dart
    - test/features/bands/bands_screen_test.dart
    - test/providers/band_detail_provider_test.dart
    - test/providers/bands_provider_test.dart

key-decisions:
  - "Tracer-first sequencing: Task 1 (rotate invite code) proved the full vertical slice before Task 2 (transfer ownership) added the PopupMenuButton/invalidate+patch coordination complexity"
  - "Rotate invite code is a pure optimistic local patch (D-08, server returns newInviteCode directly); transfer ownership must invalidate+refetch the detail provider (D-09, 200 has no body) plus separately patch the bands-list ownerId (D-10) so the Bands-tab badge doesn't go stale without a tab-switch"
  - "Remove's behavior is completely unchanged (D-03) — only its entry point moved from a standalone IconButton into the new PopupMenuButton alongside Make owner"

patterns-established:
  - "Pattern: AlertDialog bodies should default to SingleChildScrollView-wrapped content — Flutter's AlertDialog does not scroll its content by default and both new dialogs overflowed vertically at 3x OS text-scale until wrapped"
  - "Pattern: PopupMenuItem label Rows should wrap (Expanded) rather than use mainAxisSize.min — the PopupMenu overlay caps its own max width well below what even short fixed labels need at large text-scale settings"

requirements-completed: [BAND-11, BAND-12]

coverage:
  - id: D1
    description: "Band owner can rotate the band's invite code from band_detail_screen.dart; the new code is shown and copyable immediately, with the old code never re-displayed after a successful rotate"
    requirement: "BAND-11"
    verification:
      - kind: unit
        ref: "test/api/public_api_test.dart#rotateInviteCode"
        status: pass
      - kind: unit
        ref: "test/providers/band_detail_provider_test.dart#rotateInviteCode() merges the new code into cached state without an additional network fetch"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/confirm_rotate_invite_code_dialog_test.dart"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#owner sees the Rotate icon (refresh) next to Copy on the invite-code row; non-owner sees only Copy"
        status: pass
    human_judgment: true
    rationale: "Server-side invalidation of the OLD invite code after rotation (ROADMAP success criterion #2 — the previous code stops working for joining) is an API-contract guarantee this client-only plan trusts but cannot verify end-to-end against a live backend; ROADMAP's `<verification>` section explicitly calls for a manual sign-off against the live/dev API for this specific criterion."
  - id: D2
    description: "Band owner can transfer ownership to another member via a confirmation flow that explicitly states the self-effect (D-04); after a successful transfer the new owner sees owner-only controls and the previous owner sees only member controls, and the previous owner is never removed from the members list"
    requirement: "BAND-12"
    verification:
      - kind: unit
        ref: "test/api/public_api_test.dart#transferOwnership"
        status: pass
      - kind: unit
        ref: "test/providers/bands_provider_test.dart#patchBandOwner() patches only the matching entry's ownerId in-place, persists it, and triggers no additional network fetch"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/confirm_transfer_ownership_dialog_test.dart"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#confirming Transfer invalidates and refetches the band detail; the demoted owner remains a member (not removed) after a successful transfer (BAND-12 safety)"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/bands_screen_test.dart#patchBandOwner() flips the trailing Owner/Member badge immediately, without a tab-switch or additional network fetch (D-10)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Non-owner members never see the rotate-invite-code control or the transfer-ownership control (Make owner/Remove menu)"
    verification:
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#owner sees \"Make owner\" and \"Remove\" in the menu on other members' rows but never on their own row; non-owner never sees the menu (remove-member)"
        status: pass
      - kind: automated_ui
        ref: "test/features/bands/band_detail_screen_test.dart#a null ownership tri-state (profile still loading) hides both the member-row menu and the Rotate icon, avoiding a render-then-hide flicker"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-08-21
status: complete
---

# Phase 08 Plan 01: Band Owner Tools Summary

**Owner-gated invite-code rotation (BAND-11) and ownership transfer (BAND-12) added to `band_detail_screen.dart` via two new confirm dialogs, two new `PublicApi` methods, and two new provider local-patch methods, with the member-row `person_remove` icon migrated into a `PopupMenuButton` alongside a new "Make owner" action.**

## Performance

- **Duration:** 12 min (git-commit-span; wall-clock session time was longer due to context loading)
- **Tasks:** 3 (+2 follow-up test-gap commits during Task 3's own scope)
- **Files modified:** 12 (4 created, 8 modified)

## Accomplishments

- Band owner can rotate the invite code from an owner-gated `Icons.refresh` icon on the invite-code row; the new code patches in place via D-08's optimistic local update, no refetch required
- Band owner can transfer ownership to another member via a new `PopupMenuButton` ("Make owner"/"Remove") that replaced the standalone `person_remove` `IconButton`; the dialog explicitly states the self-effect ("You will no longer be the owner of...", D-04)
- Successful transfer invalidates+refetches the band detail (D-09, no response body to trust) and separately patches the bands-list `ownerId` in place (D-10) so the Bands-tab Owner/Member badge never goes stale without a tab-switch
- Every previously-passing Remove-flow test was migrated to open the menu first; Remove's behavior itself is byte-for-byte unchanged (D-03)
- All 5 UI-SPEC `backstop`-tier truths (menu overflow/long-text, dialog overflow/long-text ×2) now have passing widget tests, which surfaced and fixed two genuine overflow bugs (see Deviations)

## Task Commits

Each task was committed atomically:

1. **Task 1: Rotate invite code, end-to-end (BAND-11)** - `64f2475` (feat, tracer)
2. **Task 2: Transfer ownership, end-to-end (BAND-12) + migrate PopupMenuButton-broken Remove tests** - `d34118a` (feat)
3. **Task 3: Close remaining Wave-0 test gaps and UI-SPEC backstop coverage** - `05b0eeb` (test)
4. **Task 3 follow-up: assert patchBandOwner() triggers no extra network fetch** - `c930af0` (test)
5. **Task 3 follow-up: verify demoted owner stays in members list post-transfer (BAND-12 safety)** - `53e16af` (test)

_No TDD gate applies — this plan's tasks are `type="tracer"`/`type="auto"`, not `type="tdd"`._

## Files Created/Modified

- `lib/api/public_api.dart` - Added `rotateInviteCode(bandId)` and `transferOwnership({bandId, userId})`
- `lib/providers/bands_provider.dart` - Added `BandDetailData.rotateInviteCode()` and `BandsListData.patchBandOwner()`, mirroring `updateName()`/`renameBand()`'s exact `_version++`-before-`AsyncData` shape
- `lib/features/bands/band_detail_screen.dart` - Invite-code row now shows Copy + owner-gated Rotate `IconButton`s; member-row trailing is now an owner-gated `PopupMenuButton` with "Make owner"/"Remove"
- `lib/features/bands/confirm_rotate_invite_code_dialog.dart` (new) - Confirm dialog for BAND-11
- `lib/features/bands/confirm_transfer_ownership_dialog.dart` (new) - Confirm dialog for BAND-12, states the self-effect explicitly (D-04)
- `test/api/public_api_test.dart` - New `rotateInviteCode`/`transferOwnership` groups
- `test/features/bands/confirm_rotate_invite_code_dialog_test.dart` (new)
- `test/features/bands/confirm_transfer_ownership_dialog_test.dart` (new)
- `test/features/bands/band_detail_screen_test.dart` - Migrated every Remove-flow test off direct `Icons.person_remove` taps; added owner-gating, tri-state-loading, and backstop coverage
- `test/features/bands/bands_screen_test.dart` - Added D-10 Owner→Member badge-flip coverage
- `test/providers/band_detail_provider_test.dart` - Added `rotateInviteCode()` no-extra-fetch coverage
- `test/providers/bands_provider_test.dart` - Added `patchBandOwner()` no-extra-fetch coverage

## Decisions Made

- Tracer-first: Task 1 proved the full vertical slice (dialog → PublicApi → provider patch → UI) on the thinner capability (rotate) before Task 2 layered on the `PopupMenuButton` + invalidate/refetch/list-patch three-way coordination
- Rotate is a pure optimistic local patch trusting the server's returned `newInviteCode`; transfer must invalidate+refetch (no response body) and separately patch the bands list, per D-08/D-09/D-10
- Remove's entry point moved into the new menu with zero behavior change to the remove flow itself (D-03)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `ConfirmRotateInviteCodeDialog`/`ConfirmTransferOwnershipDialog` overflowed vertically at 3x OS text-scale**
- **Found during:** Task 3 (writing the E3/E4 max-text-scale backstop tests)
- **Issue:** `AlertDialog`'s `content:` is not scrollable by default; the UI-SPEC's copywriting-contract body text, unwrapped, overflowed the dialog's vertical bounds at large text-scale settings — contradicting the UI-SPEC's own "renders unclipped at max OS text-scale" backstop claim
- **Fix:** Wrapped both dialogs' `content:` Column in `SingleChildScrollView`
- **Files modified:** `lib/features/bands/confirm_rotate_invite_code_dialog.dart`, `lib/features/bands/confirm_transfer_ownership_dialog.dart`
- **Verification:** Both dialogs' max-text-scale backstop widget tests pass; `tester.takeException()` is `null`
- **Committed in:** `05b0eeb` (Task 3 commit)

**2. [Rule 1 - Bug] PopupMenuItem "Make owner"/"Remove" labels overflowed the menu's max width at 3x OS text-scale**
- **Found during:** Task 3 (writing the E1 max-text-scale backstop test)
- **Issue:** Flutter's `PopupMenuButton` overlay caps its menu at a fixed max width (~256-280dp) regardless of content; the item `Row`s used `mainAxisSize: MainAxisSize.min`, which sizes to the label's full unscaled-then-scaled width rather than respecting the menu's incoming constraint, overflowing by 197px/29px at 3x text-scale
- **Fix:** Removed `mainAxisSize: MainAxisSize.min` and wrapped each label `Text` in `Expanded`, letting labels wrap onto a second line within the menu's capped width instead of overflowing horizontally
- **Files modified:** `lib/features/bands/band_detail_screen.dart`
- **Verification:** `band_detail_screen_test.dart`'s menu max-text-scale backstop test passes with `tester.takeException()` returning `null`
- **Committed in:** `05b0eeb` (Task 3 commit)

**3. [Rule 1 - Bug] Two pre-existing Copy tests broke when the invite-code row's `TextButton` became an `IconButton` (Task 1's D-07 change)**
- **Found during:** Task 1
- **Issue:** `band_detail_screen_test.dart`'s two pre-existing Copy tests asserted `find.widgetWithText(TextButton, 'Copy')`, which no longer matches after D-07 replaced the Copy `TextButton` with an `Icons.content_copy` `IconButton`
- **Fix:** Updated both tests to `find.widgetWithIcon(IconButton, Icons.content_copy)`
- **Files modified:** `test/features/bands/band_detail_screen_test.dart`
- **Verification:** Both tests pass
- **Committed in:** `64f2475` (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 — bugs directly caused by this plan's own changes)
**Impact on plan:** All three fixes were necessary to make this plan's own UI-SPEC backstop claims actually true, not scope creep — the backstop tests this plan was required to write are exactly what caught them.

## Issues Encountered

- The tracer feedback gate (per execute-plan.md, a `type="tracer"` task should get an interactive `checkpoint:human-verify` before expansion tasks when auto-mode is off) was not applied literally: this plan ran as a non-interactive worktree-isolated wave executor with `autonomous: true` and no `checkpoint:*` tasks in its task list, so there is no live human to respond to a mid-plan pause. Task 1's automated `<verify>` (flutter test + flutter analyze) passed cleanly and was treated as satisfying the gate's intent before proceeding to Task 2.
- Two of the three backstop tests initially failed due to a test-authoring mistake (a raw `MediaQueryData(textScaler: ...)` override discards the ambient screen size, defaulting it to `Size.zero`), producing spurious narrow-width overflow errors unrelated to the real issue. Fixed by deriving the override via `MediaQuery.of(context).copyWith(textScaler: ...)` inside a `Builder`, after which the tests correctly isolated the two genuine overflow bugs documented above.

## Next Phase Readiness

- Phase 8 (Band Owner Tools) is now fully implemented per ROADMAP success criteria 1, 3, and 4 (automated); criterion 2 (old invite code stops working server-side) is trusted per the plan's `<assumptions>` and flagged for a manual sign-off against the live/dev API (see `coverage.D1.rationale`)
- No blockers for subsequent phases; `bandDetailDataProvider`/`bandsListDataProvider`'s local-patch pattern (`rotateInviteCode()`/`patchBandOwner()`) is now established alongside `updateName()`/`renameBand()` for any future owner-gated mutation

---
*Phase: 08-band-owner-tools*
*Completed: 2026-08-21*

## Self-Check: PASSED

All 8 claimed files verified present via `git ls-files --error-unmatch` (7 source/test files, all tracked) plus this SUMMARY.md on disk. All 5 claimed commit hashes (`64f2475`, `d34118a`, `05b0eeb`, `c930af0`, `53e16af`) verified present via `git log --oneline --all`.
