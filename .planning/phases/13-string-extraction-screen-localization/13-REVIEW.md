---
phase: 13-string-extraction-screen-localization
reviewed: 2026-08-26T17:23:03Z
depth: standard
files_reviewed: 68
files_reviewed_list:
  - lib/features/auth/login_screen.dart
  - lib/features/bands/band_detail_screen.dart
  - lib/features/bands/bands_screen.dart
  - lib/features/bands/confirm_delete_band_dialog.dart
  - lib/features/bands/confirm_leave_band_dialog.dart
  - lib/features/bands/confirm_remove_member_dialog.dart
  - lib/features/bands/confirm_rotate_invite_code_dialog.dart
  - lib/features/bands/confirm_transfer_ownership_dialog.dart
  - lib/features/bands/create_band_screen.dart
  - lib/features/bands/edit_band_screen.dart
  - lib/features/bands/join_band_dialog.dart
  - lib/features/home/band_picker_sheet.dart
  - lib/features/home/home_screen.dart
  - lib/features/profile/change_password_screen.dart
  - lib/features/profile/profile_screen.dart
  - lib/features/setlists/add_setlist_tracks_dialog.dart
  - lib/features/setlists/confirm_delete_setlist_dialog.dart
  - lib/features/setlists/create_setlist_screen.dart
  - lib/features/setlists/edit_setlist_screen.dart
  - lib/features/setlists/setlist_detail_screen.dart
  - lib/features/setlists/setlist_formatting.dart
  - lib/features/setlists/setlist_list_screen.dart
  - lib/features/setlists/setlists_screen.dart
  - lib/features/songs/tracks_screen.dart
  - lib/features/tracks/confirm_delete_track_dialog.dart
  - lib/features/tracks/create_track_screen.dart
  - lib/features/tracks/edit_track_screen.dart
  - lib/features/tracks/track_detail_screen.dart
  - lib/features/tracks/track_formatting.dart
  - lib/features/tracks/track_list_screen.dart
  - lib/generated/app_localizations.dart
  - lib/generated/app_localizations_en.dart
  - lib/generated/app_localizations_ru.dart
  - lib/l10n/app_en.arb
  - lib/l10n/app_ru.arb
  - lib/navigation/root_scaffold.dart
  - lib/widgets/offline_banner.dart
  - lib/widgets/offline_no_cache_view.dart
  - test/features/bands/band_detail_screen_test.dart
  - test/features/bands/bands_screen_test.dart
  - test/features/bands/confirm_rotate_invite_code_dialog_test.dart
  - test/features/bands/confirm_transfer_ownership_dialog_test.dart
  - test/features/bands/create_band_screen_test.dart
  - test/features/bands/edit_band_screen_test.dart
  - test/features/bands/join_band_dialog_test.dart
  - test/features/home/band_picker_sheet_test.dart
  - test/features/home/home_screen_test.dart
  - test/features/profile/change_password_screen_test.dart
  - test/features/profile/profile_screen_test.dart
  - test/features/setlists/add_setlist_tracks_dialog_test.dart
  - test/features/setlists/confirm_delete_setlist_dialog_test.dart
  - test/features/setlists/create_setlist_screen_test.dart
  - test/features/setlists/edit_setlist_screen_test.dart
  - test/features/setlists/setlist_detail_screen_test.dart
  - test/features/setlists/setlist_list_screen_test.dart
  - test/features/setlists/setlists_screen_test.dart
  - test/features/tracks/confirm_delete_track_dialog_test.dart
  - test/features/tracks/create_track_screen_test.dart
  - test/features/tracks/edit_track_screen_test.dart
  - test/features/tracks/track_detail_screen_test.dart
  - test/features/tracks/track_list_screen_test.dart
  - test/features/tracks/tracks_screen_test.dart
  - test/locale_live_switch_test.dart
  - test/offline_cross_tab_test.dart
  - test/test_strings.dart
  - test/widgets/duration_input_formatter_test.dart
  - test/widgets/offline_banner_test.dart
  - test/widget_test.dart
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 13: Code Review Report

**Reviewed:** 2026-08-26T17:23:03Z
**Depth:** standard
**Files Reviewed:** 68
**Status:** issues_found

## Summary

This phase's stated scope is string extraction to `AppLocalizations`/ARB for the bands, home, profile, setlists, tracks, and navigation screens. The mechanical extraction itself is clean: `flutter analyze` reports no issues, the full test suite (442 tests) passes, every `en`/`ru` ARB key pair has matching placeholder sets, no key is referenced from Dart code without an ARB definition, and a targeted grep found no leftover hardcoded `Text(...)`/`labelText`/`hintText`/`tooltip` string literals in any of the 31 touched screen/dialog files.

However, `lib/features/tracks/track_formatting.dart` was not a pure string-extraction diff — `DurationTextInputFormatter` was substantively rewritten (a new digit-diffing algorithm, `_rawTypedDigits`, replacing the old flat re-parse). This rewrite introduces a reproducible functional regression: backspacing a duration field down to its last digit gets permanently stuck displaying `0:00` instead of clearing to empty, and no existing test (including the new `duration_input_formatter_test.dart` added by this phase) exercises that path. I built a standalone repro against the shipped formatter and confirmed the bug (see CR-01). Because `parseDurationSeconds('0:00')` returns `0` (a valid, meaningful duration), not `null` (D-06's "optional field" contract), this silently converts "the user wants to clear this field" into "the user wants an explicit zero-second duration" unless they notice and use select-all-delete instead of backspacing.

Also flagged: 12 of the 33 touched `lib/` files fail `dart format --set-exit-if-changed`, violating this project's stated "Dart's built-in formatter (dartfmt) is the standard" convention, and the duration-formatter rewrite itself represents scope creep relative to the phase's "string extraction" charter that increased review risk without corresponding test coverage.

## Critical Issues

### CR-01: DurationTextInputFormatter permanently gets stuck at "0:00", can't be cleared to empty via backspace

**File:** `lib/features/tracks/track_formatting.dart:68-79` (interacting with `_rawTypedDigits` at `lib/features/tracks/track_formatting.dart:101-126`)

**Issue:** The rewritten digit-diffing logic in `formatEditUpdate` correctly computes `rawDigits = ''` once a user backspaces away every digit they typed, but the formatting branch at line 73 unconditionally renders an empty `rawDigits` as `'0:00'` instead of clearing the field:

```dart
if (rawDigits.length <= 2) {
  formatted = '0:${rawDigits.padLeft(2, '0')}';   // '' padLeft(2,'0') == '00' -> "0:00"
}
```

The early-return "clear to empty" fast path at the top of the method only triggers off `newValue.text`'s digit count (`digitsOnly.isEmpty`), which is never true here because the *displayed* text still contains the formatter's own synthetic `"0:0"`/`"0:00"` characters even though zero digits were actually typed by the user. Once the field reaches `"0:00"`, every subsequent backspace re-derives `rawDigits = ''` and re-renders `"0:00"` again — the field can never be fully cleared by repeated backspacing; only a select-all-and-delete (which empties `newValue.text` entirely and does hit the fast path) works.

I reproduced this against the actual shipped code:
```
after typing 5:        0:05
after 1 backspace:     0:00
after 2 backspaces:    0:00   (still stuck)
after 3 backspaces:    0:00   (still stuck)
```
`parseDurationSeconds('0:00')` returns `0` (a valid, submittable duration), not `null`. Per this file's own doc comment ("An empty field remains valid — Duration stays optional (D-06)"), a user who types a duration and then changes their mind and backspaces it away will have the form silently retain and submit an explicit `0:00`/0-second duration instead of leaving the field empty/optional, unless they notice and clear it a different way. This is used by both `create_track_screen.dart` and `edit_track_screen.dart`'s Duration field.

This is not covered by any test — `test/widgets/duration_input_formatter_test.dart` (added by this phase) tests backspacing from `"23:05"` down to `"2:30"`/`"0:23"` but never continues backspacing down to zero digits.

**Fix:** After computing `rawDigits`, short-circuit to the same empty-clear behavior as the top-of-method fast path when `rawDigits` is empty:

```dart
if (rawDigits.length > 4) {
  return oldValue;
}

if (rawDigits.isEmpty) {
  return newValue.copyWith(
    text: '',
    selection: const TextSelection.collapsed(offset: 0),
  );
}

final String formatted;
if (rawDigits.length <= 2) {
  formatted = '0:${rawDigits.padLeft(2, '0')}';
} else {
  ...
```
Add a regression test asserting that repeated backspacing from any non-empty duration eventually reaches `''`, not a floor of `'0:00'`.

## Warnings

### WR-01: 12 of 33 touched files fail the project's `dart format` standard

**File:** e.g. `lib/features/bands/band_detail_screen.dart:63`, `lib/features/tracks/create_track_screen.dart` (multiple lines), and 10 other files
**Issue:** CLAUDE.md states "Dart's built-in formatter (dartfmt) is the standard — apply via `flutter analyze` and `flutter format`." Running `dart format --output=none --set-exit-if-changed` against the 33 `lib/` files this phase touched reports 12 as unformatted, e.g.:
```
lib/features/bands/band_detail_screen.dart:63
-  message: isOnline ? l10n.commonEdit : l10n.commonRequiresConnection,
+  message: isOnline
+      ? l10n.commonEdit
+      : l10n.commonRequiresConnection,
```
Affected files: `band_detail_screen.dart`, `confirm_delete_band_dialog.dart`, `confirm_leave_band_dialog.dart`, `confirm_remove_member_dialog.dart`, `confirm_rotate_invite_code_dialog.dart`, `add_setlist_tracks_dialog.dart`, `create_setlist_screen.dart`, `setlist_detail_screen.dart`, `setlists_screen.dart`, `tracks_screen.dart`, `create_track_screen.dart`, `edit_track_screen.dart`. This is purely a line-length/wrapping drift introduced by the many inline `isOnline ? l10n.x : l10n.commonRequiresConnection` ternaries added during extraction; `flutter analyze` doesn't catch it since formatting isn't lint-enforced, but it violates the stated convention and will generate noisy diffs on the next formatter pass.

**Fix:** Run `dart format lib/` (or `flutter format lib/`) before merging, and consider adding a formatting check to CI so this doesn't recur.

### WR-02: Behavioral rewrite of `DurationTextInputFormatter` bundled into a string-extraction phase

**File:** `lib/features/tracks/track_formatting.dart:9-126`
**Issue:** The phase's charter (per its own name and `README`-level intent visible in the diff, e.g. `pluralizeTracks`/`tracksAndDuration` → ICU `trackCount`/`memberCount`) is mechanical string extraction to ARB/`AppLocalizations`. `DurationTextInputFormatter`, however, received a full algorithmic rewrite (new `_rawTypedDigits` digit-diffing helper, new append/remove/replace branch logic) that has nothing to do with localization — it changes runtime input-handling behavior for the Duration field. Bundling a non-trivial, non-localization behavior change into a phase scoped as pure string extraction increases review risk (as demonstrated by CR-01 slipping through) and makes it harder to bisect/revert the localization work independently of the formatter change.
**Fix:** In future phases, keep localization-only diffs isolated from behavioral changes; if the formatter fix was necessary, land it as its own reviewed change with its own test coverage for the backspace-to-empty path (see CR-01).

## Info

### IN-01: `_rawTypedDigits` fallback branch is dead for all in-app call sites

**File:** `lib/features/tracks/track_formatting.dart:104-110`
**Issue:** The `if (parts.length != 2)` fallback in `_rawTypedDigits` is documented as "a defensive fallback covering the pre-existing isolated unit tests, which pass raw digit strings ... rather than formatted mm:ss text." Since `formatEditUpdate` always produces `mm:ss`-shaped text (or empty, which is handled earlier and never reaches `_rawTypedDigits` via `oldValue.text` in the same call), this branch is unreachable in production and exists solely to keep some now-superseded test inputs working. Not a functional bug, but worth flagging as test-driven dead code that could mask future regressions if the "always mm:ss" invariant is ever broken elsewhere.
**Fix:** Either delete the now-legacy raw-digit-string test cases and this fallback together, or add an explicit comment/assertion clarifying which call sites still rely on it.

---

_Reviewed: 2026-08-26T17:23:03Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
