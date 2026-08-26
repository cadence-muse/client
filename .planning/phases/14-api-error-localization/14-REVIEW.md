---
phase: 14-api-error-localization
reviewed: 2026-08-26T18:30:31Z
depth: standard
files_reviewed: 19
files_reviewed_list:
  - lib/api/api_exception.dart
  - lib/features/auth/login_screen.dart
  - lib/features/bands/confirm_delete_band_dialog.dart
  - lib/features/bands/confirm_leave_band_dialog.dart
  - lib/features/bands/confirm_remove_member_dialog.dart
  - lib/features/bands/confirm_rotate_invite_code_dialog.dart
  - lib/features/bands/confirm_transfer_ownership_dialog.dart
  - lib/features/bands/create_band_screen.dart
  - lib/features/bands/edit_band_screen.dart
  - lib/features/bands/join_band_dialog.dart
  - lib/features/profile/change_password_screen.dart
  - lib/features/setlists/add_setlist_tracks_dialog.dart
  - lib/features/setlists/confirm_delete_setlist_dialog.dart
  - lib/features/setlists/create_setlist_screen.dart
  - lib/features/setlists/edit_setlist_screen.dart
  - lib/features/setlists/setlist_detail_screen.dart
  - lib/features/tracks/confirm_delete_track_dialog.dart
  - lib/features/tracks/create_track_screen.dart
  - lib/features/tracks/edit_track_screen.dart
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 14: Code Review Report

**Reviewed:** 2026-08-26T18:30:31Z
**Depth:** standard
**Files Reviewed:** 19 lib files (+ ARB/generated l10n files and test files inspected as supporting evidence)
**Status:** issues_found

## Summary

Phase 14 wires 18 pre-existing `on ApiException catch (e)` sites across Bands, Tracks, Setlists, Auth, and Profile onto the new `ApiExceptionLocalization.localizedMessage()` extension. I read every one of the 18 catch sites plus the extension itself, the ARB/generated localization files, and the widget tests added/modified across all four plans, then ran `flutter analyze` (clean) and `flutter test` (all 453 tests pass) to independently confirm the plans' claims rather than trusting the SUMMARY.md self-reports.

**Findings:**
- The core extension (`lib/api/api_exception.dart`) is correct: null/unmapped codes fall back to raw `message` (D-05), the `overrides` map is checked before the switch (D-04), and all 5 `ErrorCode` literals match `publicapi.yml` exactly.
- All 18 catch sites correctly call `e.localizedMessage(l10n)` (or the `overrides`-parameterized variant in login/change-password); no orphaned raw-`e.message` site remains anywhere in `lib/features/`.
- The 3 setlist sites needing a new local `l10n` fetch (`create_setlist_screen.dart`, `add_setlist_tracks_dialog.dart`, `setlist_detail_screen.dart`) all declare the new local in a scope that does not collide with the try-block's own `l10n` — no shadowing/duplicate-declaration bug.
- The login/change-password `overrides` refactor is correct and behavior-preserving for the 2 existing overrides, and the untouched 401 statusCode path was verified intact (both by code reading and by the passing `login_screen_test.dart`).
- The one "manually fixed" stale test called out in scope (`test/features/bands/join_band_dialog_test.dart`) is fixed correctly — it now asserts `commonErrorNotFound` and asserts the raw text is absent. I found no other stale raw-text assertions for now-mapped codes anywhere in `test/`; every other pre-existing error-path test in touched/untouched sibling files uses `'bad_request'`, `'network_error'`, or `'server_error'` (all outside the 5-value enum), so they remain valid fallback-path regression tests, not silently-broken stale assertions.

Two real (if narrow) issues were found, detailed below — neither breaks the build or fails any test today, but both are genuine, provable defects in the shipped code.

## Warnings

### WR-01: `AppLocalizations.of(context)` used without a `mounted` guard after an `await`, inside two `on ApiException` catch blocks

**File:** `lib/features/setlists/create_setlist_screen.dart:82-84`
**File:** `lib/features/setlists/add_setlist_tracks_dialog.dart:121-123`

**Issue:** In both files, the `_submit()` method's `on ApiException catch (e)` block fetches `l10n` from `context` and then calls `setState` **without first checking `widget.mounted`**, even though the exception is only reachable after an `await` (the network call). If the widget is unmounted during that await (user navigates away / backgrounds the dialog / pops the screen while the request is in flight), `AppLocalizations.of(context)!` on a deactivated `BuildContext` returns `null` from `Localizations.of` (the assertion that would otherwise catch this is compiled out in release builds), so the `!` throws `Null check operator used on a null value`; even if that lookup happened to succeed, the subsequent `setState()` call on a disposed `State` throws `setState() called after dispose()`. Either way this produces an uncaught exception on a specific, realistic user path (tap submit, immediately back out) instead of a clean no-op.

This is a new gap introduced by 14-04: before this phase, the same catch block only assigned `e.message` (no `context`/`l10n` access at all), so there was no context-lookup risk here — only the pre-existing `setState`-after-dispose risk shared with every other unguarded catch block in the codebase. Adding the `AppLocalizations.of(context)!` call inside the catch block, without also adding the same `mounted` guard the sibling `catch (_)` block one branch below already uses (`create_setlist_screen.dart:86`, `add_setlist_tracks_dialog.dart:125`), makes this specific block strictly less safe than its neighbor for no functional reason — the guard is cheap and the sibling block already establishes the local convention.

Contrast with `setlist_detail_screen.dart`'s `_removeTrack()` (also touched by 14-04), which does this correctly — it places the new `l10n` fetch *after* its existing `if (!mounted) return;` guard (line 74-75).

**Fix:** Add the same `mounted` guard the sibling `catch (_)` block already uses, before the `l10n` fetch:
```dart
// create_setlist_screen.dart
} on ApiException catch (e) {
  if (!mounted) return;
  final l10n = AppLocalizations.of(context)!;
  setState(() => _errorMessage = e.localizedMessage(l10n));
}
```
```dart
// add_setlist_tracks_dialog.dart
} on ApiException catch (e) {
  if (!mounted) return;
  final l10n = AppLocalizations.of(context)!;
  setState(() => _errorMessage = e.localizedMessage(l10n));
}
```

### WR-02: Roughly half of the 18 wired catch sites have no automated regression test proving the localized-message swap actually renders correctly at runtime

**Files:** `lib/features/bands/confirm_delete_band_dialog.dart`, `lib/features/bands/confirm_remove_member_dialog.dart`, `lib/features/bands/confirm_leave_band_dialog.dart`, `lib/features/bands/confirm_transfer_ownership_dialog.dart`, `lib/features/tracks/edit_track_screen.dart`, `lib/features/tracks/confirm_delete_track_dialog.dart`, `lib/features/setlists/edit_setlist_screen.dart`, `lib/features/setlists/confirm_delete_setlist_dialog.dart`, `lib/features/setlists/setlist_detail_screen.dart`

**Issue:** 14-02's plan explicitly scoped test coverage to "2 representative sites" (edit-band, rotate-invite-code) out of the 7 it touched; 14-04's own SUMMARY.md self-reports `human_judgment: true` for `edit_setlist_screen.dart`/`confirm_delete_setlist_dialog.dart` and `setlist_detail_screen.dart`, stating "No existing widget test exercises [this] ApiException catch path... verified by analyzer + code inspection only." I independently confirmed (by reading each file) that all 9 of these untested sites are in fact wired correctly — but that correctness currently rests entirely on manual code review (mine and the plan authors'), not on an automated test that would catch a future regression (e.g., someone later "fixing" one of these files and reintroducing `e.message`, or a copy-paste error swapping in the wrong ARB getter). `flutter analyze` cannot catch either kind of regression since both are still type-correct Dart.

**Fix:** Not a blocking gap for this phase (the plans explicitly and consciously deferred it), but worth a follow-up: add one `testWidgets` case per remaining untested site (mirroring the pattern already used 9 times elsewhere in this phase — mock a known error code, assert the localized string renders and the raw string doesn't) so all 18 sites have the same regression-proof standard, not just half.

## Info

### IN-01: `ApiExceptionLocalization`'s doc comment cites hardcoded line numbers in `publicapi.yml` that will silently go stale

**File:** `lib/api/api_exception.dart:37`
**Issue:** The doc comment reads `` `publicapi.yml` lines 670-677 `` — a fine breadcrumb today, but `publicapi.yml` is a living spec file; any future edit that shifts those line numbers (e.g., adding a field earlier in the file) makes this comment silently wrong with no compiler or lint warning, and the enum name (`ErrorCode`) has no other backlink for someone auditing this switch later.
**Fix:** Reference the schema name only (`` `publicapi.yml`'s `ErrorCode` enum ``), or drop the line numbers — low priority, doc-comment-only.

---

_Reviewed: 2026-08-26T18:30:31Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
