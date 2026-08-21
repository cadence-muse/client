---
phase: 06-foundation-info-settings-polish
reviewed: 2026-08-21T06:38:02Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/api/public_api.dart
  - lib/api/publicapi.yml
  - lib/features/bands/band_detail_screen.dart
  - lib/features/bands/bands_screen.dart
  - lib/features/profile/change_password_screen.dart
  - lib/features/profile/profile_screen.dart
  - lib/features/setlists/setlist_detail_screen.dart
  - lib/features/setlists/setlist_list_screen.dart
  - lib/features/tracks/track_detail_screen.dart
  - lib/features/tracks/track_list_screen.dart
  - test/features/bands/band_detail_screen_test.dart
  - test/features/bands/bands_screen_test.dart
  - test/features/profile/change_password_screen_test.dart
  - test/features/setlists/setlist_detail_screen_test.dart
  - test/features/setlists/setlist_list_screen_test.dart
  - test/features/tracks/track_detail_screen_test.dart
  - test/features/tracks/track_list_screen_test.dart
  - test/offline_cross_tab_test.dart
  - test/widget_test.dart
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: clean
---

# Phase 06: Code Review Report

**Reviewed:** 2026-08-21T06:38:02Z
**Depth:** standard
**Files Reviewed:** 19
**Status:** clean

## Summary

Reviewed all four of Phase 06's plans (password change end-to-end, Band member count/role display, Track metadata icons, Setlist metadata icons) plus the post-merge integration fix. Cross-checked every implementation against its PLAN.md/SUMMARY.md intent, the actual `publicapi.yml` contract, and each screen's threat model.

Verified in this session:
- `flutter analyze` — no issues.
- `flutter test test/features/bands/ test/features/profile/ test/features/tracks/ test/features/setlists/ test/offline_cross_tab_test.dart test/widget_test.dart` — 201 tests, all passing.
- `publicapi.yml`'s four schema additions (`ChangeUserPasswordRequestBody.currentPassword`, `BandListItem.ownerId`, `TrackListItem.key`, `SetlistListItem.eventLocation`) exactly match what each plan specified — all correctly optional except `currentPassword` (deliberately required, matching D-01).
- `ChangeUserPasswordScreen`'s 400+`invalid_input` branch is correctly implemented against the actual `BadRequest`-only response contract for `ChangeUserPassword` (verified directly in `publicapi.yml` — no `'401'` response exists for this operation), and never leaks the raw server message for a wrong current password (T-06-01-02 mitigation holds).
- `BandDetailScreen.isOwner`/`ownershipStatus` were correctly made public with every in-file call site updated; `BandsScreen` reuses them (via `BandDetailScreen.ownershipStatus(...)`) rather than reimplementing the id comparison, and the tri-state (`null` while unresolved) is respected on both screens — no owner/member flash before the profile loads.
- Track/Setlist list and detail screens correctly gate optional icon rows (`key`, `eventLocation`) on presence, leave `tracksAndDuration`/`setlist_formatting.dart` and the cross-band `setlists_screen.dart` untouched (confirmed via `git diff`), and the location/notes tap-to-expand `GestureDetector`s correctly avoid triggering the row's own navigation `onTap` (covered by a passing test in each case).
- The post-merge fix (`3e2308f`) correctly and minimally patched `test/offline_cross_tab_test.dart`/`test/widget_test.dart`'s stale band fixtures to include the now-required `membersCount` field; both files already routed `/api/me` before this phase (pre-existing, since `ProfileScreen` already depended on it), so `BandsScreen`'s new `profileDataProvider` watch did not require any additional routing there.

No Critical or Warning findings. One Info-level documentation-drift item below.

## Info

### IN-01: Stale cross-file doc-comment reference to a renamed private identifier

**File:** `lib/api/public_api.dart:120`
**Issue:** `deleteBand`'s doc comment reads "The client-side owner gate (see `band_detail_screen.dart`'s `_isOwner`) only hides the UI path...". Plan 06-02 (Task 1) renamed `BandDetailScreen._isOwner` to the public `isOwner` specifically so it could be called cross-file from `bands_screen.dart`, and updated every *in-file* reference in `band_detail_screen.dart` per its own `<action>` — but that instruction was scoped to the file being edited, so this cross-file doc comment in `public_api.dart` (which predates Phase 06) was never touched and now points at an identifier that no longer exists under that name.
**Fix:**
```dart
/// Deletes a band. Server-enforced owner-only (see `Remove band` in
/// `publicapi.yml`); `'204'` no content. The client-side owner gate (see
/// `band_detail_screen.dart`'s `isOwner`) only hides the UI path — the
/// server remains the authoritative enforcer.
Future<void> deleteBand(String bandId) async {
```

---

_Reviewed: 2026-08-21T06:38:02Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
