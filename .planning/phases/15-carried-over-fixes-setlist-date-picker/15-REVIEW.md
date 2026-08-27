---
phase: 15-carried-over-fixes-setlist-date-picker
reviewed: 2026-08-27T00:00:00Z
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
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-27T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This phase swaps the free-text setlist date field for a native `showDatePicker` in both `CreateSetlistScreen` and `EditSetlistScreen`, and removes the `isOnline` gate on the band invite-code copy button. The copy-button change is small, correctly tested, and matches the documented rationale (D-05) — no issues found there.

The date-picker wiring in `EditSetlistScreen` has a real crash risk: it seeds `initialDate` from the persisted `eventDate` without clamping it into the picker's `firstDate`/`lastDate` window, and `showDatePicker` asserts that `initialDate` falls within that window. Any setlist with an event date more than 5 years in the past or 2 years in the future will throw when a user opens the date picker to edit it. The existing test only covers an *unparseable* date (falls back to `now`), not a *parseable-but-out-of-range* one, so this gap wasn't caught. Two smaller issues (a UX regression in `CreateSetlistScreen`'s picker seeding, and a missing `mounted` guard after `await showDatePicker`) round out the findings.

## Critical Issues

### CR-01: EditSetlistScreen date picker crashes for a persisted eventDate outside the 5-year/2-year window

**File:** `lib/features/setlists/edit_setlist_screen.dart:117-136`
**Issue:** `_showDatePickerDialog` sets `firstDate = DateTime(now.year - 5, ...)` and `lastDate = DateTime(now.year + 2, ...)`, then computes `initialDate` by parsing the persisted `_dateController.text` (the setlist's `eventDate` from the server). If that date parses successfully but falls outside `[firstDate, lastDate]` — e.g. a setlist from a gig 6 years ago, or any historical/legacy data seeded outside the window — `initialDate` is passed to `showDatePicker` unclamped. Flutter's `showDatePicker`/`DatePickerDialog` assert that `initialDate` is on or after `firstDate` and on or before `lastDate` (`packages/flutter/lib/src/material/date_picker.dart:235-240`), so tapping the date field throws an `AssertionError` in debug/test builds. The existing test (`'a malformed persisted eventDate falls back to today as initialDate without throwing'`) only exercises an unparseable string; it never exercises a *valid* date outside the window, so this path is untested and unguarded.
**Fix:** Clamp `initialDate` into the valid range after parsing:
```dart
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
} else {
  initialDate = now;
}
```

## Warnings

### WR-01: CreateSetlistScreen's date picker always seeds from `now`, discarding an already-selected date

**File:** `lib/features/setlists/create_setlist_screen.dart:95-104`
**Issue:** `_showDatePickerDialog` hardcodes `initialDate: now` rather than reading `_dateController.text` the way `EditSetlistScreen`'s equivalent method does. If a user picks a date, then taps the date field again to change it, the calendar reopens on today's date instead of the previously chosen one, forcing them to re-navigate months of calendar UI to get back to where they were. This is inconsistent with the edit screen's behavior for the same interaction.
**Fix:** Mirror `EditSetlistScreen._showDatePickerDialog`'s pattern — parse `_dateController.text` (with a try/catch fallback to `now`) and use that as `initialDate`.

### WR-02: Missing `mounted` check before `setState` after `await showDatePicker`

**File:** `lib/features/setlists/create_setlist_screen.dart:105-109`, `lib/features/setlists/edit_setlist_screen.dart:137-141`
**Issue:** Both `_showDatePickerDialog` implementations call `setState` immediately after `await showDatePicker(...)` resolves, with no `if (!mounted) return;` guard. Every other async flow in these same files (`_submit`) checks `mounted` before touching state after an `await`, per this codebase's established error-handling convention. If the widget is disposed while the modal date picker is still open (e.g. an auth session invalidation elsewhere in the tree pops this screen), the picker's future still resolves and `setState` is called on a disposed `State`, throwing `setState() called after dispose()`.
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

### IN-01: Date-window computation duplicated between CreateSetlistScreen and EditSetlistScreen

**File:** `lib/features/setlists/create_setlist_screen.dart:96-98`, `lib/features/setlists/edit_setlist_screen.dart:118-120`
**Issue:** The `firstDate`/`lastDate` (`now.year - 5` / `now.year + 2`) calculation is copy-pasted verbatim in both screens. The two files already share `maxSetlistTracks` via `setlist_formatting.dart`, so there's a natural home for this constant/logic to avoid future drift between the two screens' picker bounds.
**Fix:** Extract a small helper, e.g. `(DateTime firstDate, DateTime lastDate) setlistDatePickerBounds(DateTime now)` in `setlist_formatting.dart`, and call it from both screens.

---

_Reviewed: 2026-08-27T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
