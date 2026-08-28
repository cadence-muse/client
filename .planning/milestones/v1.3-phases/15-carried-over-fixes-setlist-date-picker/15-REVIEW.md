---
phase: 15-carried-over-fixes-setlist-date-picker
reviewed: 2026-08-27T12:57:44Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/features/bands/band_detail_screen.dart
  - lib/features/setlists/create_setlist_screen.dart
  - lib/features/setlists/edit_setlist_screen.dart
  - test/features/bands/band_detail_screen_test.dart
  - test/features/setlists/create_setlist_screen_test.dart
  - test/features/setlists/edit_setlist_screen_test.dart
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-27T12:57:44Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the phase 15 diff (native date picker wiring for `CreateSetlistScreen`/`EditSetlistScreen`, the invite-code copy button's `isOnline`-gate removal in `BandDetailScreen`, and the `2c43ce1` clamp fix for the `AssertionError` crash on out-of-range persisted `eventDate`s). `flutter analyze` is clean on all three source files and the traced logic for the clamp fix itself is correct: `DateTime.parse` results are now bounded into `[firstDate, lastDate]` before being handed to `showDatePicker`, matching the new regression test. No crash, injection, or auth/ownership defects were found in this pass — the ownership tri-state logic in `BandDetailScreen` and the null/empty-string handling in both setlist forms hold up under the edge cases exercised.

Two behavioral inconsistencies remain between the two "mirrored" date-picker implementations (see Warnings), plus two minor maintainability notes (see Info).

## Warnings

### WR-01: CreateSetlistScreen's date picker forgets the previously chosen date on reopen

**File:** `lib/features/setlists/create_setlist_screen.dart:95-104`
**Issue:** `_showDatePickerDialog` always passes `initialDate: now`, never the currently-selected `_dateController.text`. If a user picks e.g. `2027-03-01`, then taps the date field again to adjust it, the picker reopens highlighting *today* instead of the date they just chose — the field's suffix "clear" icon confirms a date is set, but the picker itself has amnesia about it. `EditSetlistScreen._showDatePickerDialog` (added in the same phase, commit `42a0d3d`, and explicitly described as mirroring this pattern) does the opposite: it parses `_dateController.text` and clamps it into range as the `initialDate`. This is a genuine UX regression risk introduced by treating the two "mirrored" implementations asymmetrically, and there is no test in `create_setlist_screen_test.dart` covering "reopen after first selection" to catch it.
**Fix:**
```dart
Future<void> _showDatePickerDialog(BuildContext context) async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year - 5, now.month, now.day);
  final lastDate = DateTime(now.year + 2, now.month, now.day);
  DateTime initialDate = now;
  if (_dateController.text.isNotEmpty) {
    try {
      initialDate = DateTime.parse(_dateController.text);
      if (initialDate.isBefore(firstDate)) {
        initialDate = firstDate;
      } else if (initialDate.isAfter(lastDate)) {
        initialDate = lastDate;
      }
    } catch (_) {
      initialDate = now;
    }
  }
  final selected = await showDatePicker(
    context: context,
    firstDate: firstDate,
    lastDate: lastDate,
    initialDate: initialDate,
  );
  ...
}
```

### WR-02: `setState` after `showDatePicker` is not guarded by a `mounted` check

**File:** `lib/features/setlists/create_setlist_screen.dart:105-109`, `lib/features/setlists/edit_setlist_screen.dart:142-146`
**Issue:** Both `_showDatePickerDialog` implementations call `setState(...)` immediately after `await showDatePicker(...)` resolves, with no `if (!mounted) return;` guard. Every other async entry point in these same files (`_submit()`) follows the opposite convention — checking `mounted` before touching `setState` post-await, precisely because the widget can be torn down while the `Future` is pending (e.g. a 403 response elsewhere triggers `ApiClient`'s auto-logout, `AuthGate` swaps out the whole authenticated subtree, and the modal date-picker route together with the screen beneath it are disposed while `showDatePicker`'s future is still unresolved). When `selected != null` resolves after that teardown, the `setState` call will throw `setState() called after dispose()`.
**Fix:**
```dart
if (selected != null) {
  if (!mounted) return;
  setState(() {
    _dateController.text = selected.toIso8601String().split('T')[0];
  });
}
```

## Info

### IN-01: Date-range boundary computation is duplicated verbatim across both screens

**File:** `lib/features/setlists/create_setlist_screen.dart:96-98`, `lib/features/setlists/edit_setlist_screen.dart:118-120`
**Issue:** `final firstDate = DateTime(now.year - 5, now.month, now.day); final lastDate = DateTime(now.year + 2, now.month, now.day);` is copy-pasted identically in both `_showDatePickerDialog` methods. This phase's own root-cause note ("Closes Gap 1 ... same root cause as CR-01") is evidence that keeping two independent copies in sync is fragile — the clamp fix in `2c43ce1` had to be applied to `edit_setlist_screen.dart` only, and `create_setlist_screen.dart` only avoids the same bug class because it never derives `initialDate` from persisted data (see WR-01).
**Fix:** Extract a shared helper (e.g. alongside `maxSetlistTracks` in `setlist_formatting.dart`) such as `({DateTime first, DateTime last}) setlistDatePickerRange(DateTime now)`, and have both screens call it.

### IN-02: Leap-day boundary shifts the valid date range by one day

**File:** `lib/features/setlists/create_setlist_screen.dart:97-98`, `lib/features/setlists/edit_setlist_screen.dart:119-120`
**Issue:** `DateTime(now.year - 5, now.month, now.day)` on a leap-day `now` (Feb 29) rolls over to March 1 when `now.year - 5` (or `now.year + 2`) is not itself a leap year, since `DateTime` normalizes an invalid Feb 29 into March 1. This narrows/shifts the intended `[-5y, +2y]` window by one day, only on leap days. Low impact given the rarity and the one-day magnitude, but worth a `DateUtils`-based or explicit clamp if exactness ever matters here.
**Fix:** Use `DateTime.utc`/manual clamping or accept the day and document it; no action required unless the ±5/+2 year bound is meant to be exact.

---

_Reviewed: 2026-08-27T12:57:44Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
