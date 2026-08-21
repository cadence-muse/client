---
phase: 06-foundation-info-settings-polish
plan: 02
subsystem: ui
tags: [flutter, riverpod, bands, ownership-tristate]

# Dependency graph
requires:
  - phase: 06-01
    provides: BandListItem.ownerId/membersCount schema extension, profileDataProvider
provides:
  - "BandDetailScreen.isOwner / BandDetailScreen.ownershipStatus made public (usable cross-file)"
  - "Band detail screen role + member-count row below band name"
  - "Bands list row trailing text showing member count + role"
affects: [bands, band-detail, profile-role-display]

actuals:
  tokens: 3570
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Cross-screen reuse of a tri-state ownership helper via a public static method on the owning screen class, rather than reimplementing id comparison per-screen"

key-files:
  created: []
  modified:
    - lib/features/bands/band_detail_screen.dart
    - lib/features/bands/bands_screen.dart
    - test/features/bands/band_detail_screen_test.dart
    - test/features/bands/bands_screen_test.dart

key-decisions:
  - "Renamed BandDetailScreen's private _isOwner/_ownershipStatus to public isOwner/ownershipStatus so BandsScreen can call them qualified, per D-05's explicit reuse instruction (leading-underscore identifiers are library-private in Dart, not just class-private, so the original PATTERNS.md snippet calling them cross-file would not compile)"
  - "Corrected a pluralization inconsistency in the plan's own Task 1 test text: the plan's action code computes singular '1 member' (no trailing s) for a 1-member band per the must_haves pluralization truth, but the plan's suggested test assertion literally said 'Owner • 1 members' (plural) for that same 1-member fixture -- fixed the test to assert the correct singular form matching the truths and the code, not the plan's inconsistent copy-paste text"
  - "Routed GET /api/me at the buildApiClient level in bands_screen_test.dart (rather than per-test handler edits), with a default profile ({'id': 'u1', 'username': 'tester'}) and an optional profile parameter for tests that need to assert owner vs. non-owner rendering -- avoids rewriting all 10 pre-existing test handlers individually while still exercising profileDataProvider real behavior"

requirements-completed: [BAND-10]

coverage:
  - id: D1
    description: "Band detail screen shows 'Owner • N members' or 'Member • N members' below the band name, only once ownership has resolved"
    requirement: "BAND-10"
    verification:
      - kind: unit
        ref: "test/features/bands/band_detail_screen_test.dart#shows \"Owner • N members\" below the band name when the current user is the owner, and \"Member • N members\" when they are not (BAND-10)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Bands list row trailing text shows member count alone, or member count + role once ownerId and profile have both resolved, degrading gracefully when ownerId is absent"
    requirement: "BAND-10"
    verification:
      - kind: unit
        ref: "test/features/bands/bands_screen_test.dart#a band whose ownerId matches the current profile shows \"N member(s) • Owner\" in trailing (BAND-10)"
        status: pass
      - kind: unit
        ref: "test/features/bands/bands_screen_test.dart#a band whose ownerId does not match the current profile shows \"N member(s) • Member\" in trailing (BAND-10)"
        status: pass
      - kind: unit
        ref: "test/features/bands/bands_screen_test.dart#a band with no ownerId key shows just the member count, with no bullet or role (BAND-10 graceful degradation)"
        status: pass
      - kind: unit
        ref: "test/features/bands/bands_screen_test.dart#a band with membersCount 5 shows the plural \"5 members\" (BAND-10)"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-08-21
status: complete
---

# Phase 06 Plan 02: Band Member Count & Role Display Summary

**Bands list rows and the Band detail screen both surface "N members • Owner/Member" by exposing `BandDetailScreen`'s tri-state ownership helper as a public static method reused across both screens (BAND-10).**

## Performance

- **Duration:** 8 min (commit timestamps: 09:23:37 -> 09:29:05 UTC+3)
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `BandDetailScreen._isOwner`/`_ownershipStatus` renamed to public `isOwner`/`ownershipStatus`, with identical tri-state contract, so `BandsScreen` can call them qualified (`BandDetailScreen.ownershipStatus(...)`) instead of reimplementing the id-comparison logic
- Band detail screen now renders a role + member-count row ("Owner • N members" / "Member • N members") below the band name/avatar, gated on `isOwner != null` so it never flashes an incorrect role before the profile resolves
- Bands list row trailing text now shows `"N member(s)"` alone (when `ownerId` is absent, i.e. backend hasn't shipped it for that record) or `"N member(s) • Owner|Member"` once both `ownerId` and the current user's profile have resolved
- Both screens reuse the exact same tri-state helper — no duplicated ownership-comparison logic between list and detail

## Task Commits

Each task was committed atomically:

1. **Task 1: Make BandDetailScreen's ownership helpers reusable and add its role/count row** - `24a2c22` (feat)
2. **Task 2: Bands list -- member count + role trailing text** - `34764e4` (feat)

_Note: as a parallel worktree executor, this SUMMARY and REQUIREMENTS.md updates are committed separately by the orchestrator after merge; STATE.md/ROADMAP.md are not touched by this agent._

## Files Created/Modified

- `lib/features/bands/band_detail_screen.dart` - Renamed ownership helpers to public; added role/count row in `_buildContent`
- `lib/features/bands/bands_screen.dart` - Watches `profileDataProvider`; computes per-row ownership via `BandDetailScreen.ownershipStatus`; new `_membersLabel` top-level helper; trailing text replaces the old chevron icon
- `test/features/bands/band_detail_screen_test.dart` - Added owner/non-owner role-row test
- `test/features/bands/bands_screen_test.dart` - `buildApiClient` now routes `/api/me` with an optional `profile` param; all existing band fixtures given `membersCount`; 4 new tests for owner/member/no-owner/plural trailing text

## Decisions Made

- Reused `BandDetailScreen.ownershipStatus`/`isOwner` (now public) directly from `bands_screen.dart` rather than duplicating the tri-state id-comparison logic, per D-05's explicit reuse instruction and the plan's `<threat_model>`/must_haves.
- Fixed a pluralization inconsistency baked into the plan's own Task 1 test suggestion: the plan's action code (correctly) produces singular `"1 member"` for a 1-member band per the must_haves truth ("1 member" singular vs "N members" plural, N != 1), but the plan's suggested test assertion said `'Owner • 1 members'` (plural) for that same 1-member fixture. Implemented the code as specified (correct singular), and wrote the test to match the correct singular output rather than the plan's inconsistent copy-paste text.
- Routed `/api/me` at the `buildApiClient` level (with a default profile and an optional override) in `bands_screen_test.dart`, rather than editing all 10 pre-existing test handlers individually — keeps the diff smaller while still exercising real `profileDataProvider` behavior in every test.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected plan's own test-assertion typo for pluralization**
- **Found during:** Task 1 (Band detail screen role/count row test)
- **Issue:** The plan's suggested test assertion (`find.text('Owner • 1 members')`) contradicts the plan's own must_haves pluralization truth and its own action code, which correctly produces singular `"1 member"` for the 1-member `band()` fixture. Following the plan's test text literally would have made the test fail against correctly-implemented code.
- **Fix:** Implemented the role row per the action's code exactly as specified (correct singular pluralization), and wrote the test assertions as `'Owner • 1 member'` / `'Member • 1 member'` (singular) to match both the code and the must_haves truth.
- **Files modified:** `test/features/bands/band_detail_screen_test.dart`
- **Verification:** `flutter test test/features/bands/band_detail_screen_test.dart` passes (27/27), including this test.
- **Committed in:** `24a2c22` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, test-assertion correction only — no production code deviation)
**Impact on plan:** No scope creep; the fix keeps the implementation aligned with the plan's own stated correctness truth (pluralization) rather than a copy-paste typo in the plan's suggested test.

## Issues Encountered

None beyond the deviation documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- BAND-10 fully delivered: both Bands list and Band detail screen show member count + role, reusing the same tri-state helper.
- `flutter analyze` reports no new issues; `flutter test test/features/bands/` passes 70/70 (existing + new tests).
- No blockers for subsequent Phase 06 plans (Track/Setlist metadata icons, password change form) -- this plan touched only `lib/features/bands/` and its tests.

---
*Phase: 06-foundation-info-settings-polish*
*Completed: 2026-08-21*
