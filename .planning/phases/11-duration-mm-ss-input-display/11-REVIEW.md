---
phase: 11-duration-mm-ss-input-display
reviewed: 2026-08-25T11:01:10Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/features/setlists/setlist_detail_screen.dart
  - lib/features/setlists/setlist_formatting.dart
  - lib/features/setlists/setlist_list_screen.dart
  - lib/features/tracks/create_track_screen.dart
  - lib/features/tracks/edit_track_screen.dart
  - lib/features/tracks/track_formatting.dart
  - test/features/setlists/setlist_detail_screen_test.dart
  - test/features/setlists/setlist_list_screen_test.dart
  - test/features/setlists/setlists_screen_test.dart
  - test/features/tracks/create_track_screen_test.dart
  - test/features/tracks/edit_track_screen_test.dart
  - test/utils/duration_parser_test.dart
  - test/widgets/duration_input_formatter_test.dart
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 11: Code Review Report

**Reviewed:** 2026-08-25T11:01:10Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

This phase converts duration input/display from raw seconds to `mm:ss` across the Tracks and Setlists features: a new `DurationTextInputFormatter` shapes keystrokes live, `parseDurationSeconds`/`_durationValidator` re-validate at submit time, and `setlist_formatting.dart`'s bespoke `Xm Ys` format was retired in favor of reusing `track_formatting.dart`'s `asMinutesSeconds`. `flutter analyze` is clean on all six reviewed source files, and the keystroke-shaping/parsing edge cases (4-digit cap, seconds ≥ 60, negative values, empty-field-is-optional) are well covered by `duration_parser_test.dart` and `duration_input_formatter_test.dart`.

No blocking defects were found. Two warnings and two info items are worth addressing: (1) the shared `asMinutesSeconds` formatter has no defensive handling for negative `durationSeconds`, which produces nonsensical output rather than failing loudly if a bad value ever reaches it from cached/server data; (2) this phase's three touched setlist files introduce a `package:cadence/...` absolute import for a cross-feature dependency, breaking the relative-import pattern used everywhere else in `lib/features/`; and there's a stale test description plus triplicated validation logic worth a maintainability note.

## Warnings

### WR-01: `asMinutesSeconds` produces garbled output for negative durations

**File:** `lib/features/tracks/track_formatting.dart:4-7`
**Issue:** The extension does no bounds/sign checking:
```dart
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
}
```
Dart's `~/` truncates toward zero while `%` returns a non-negative remainder when the divisor is positive, so negative inputs produce misleading results rather than a sensible fallback, e.g.:
- `-5` → `"0:55"` (looks like 55 seconds, not −5)
- `-65` → `"-1:55"` (mixed-sign, nonsensical mm:ss)

This extension is called directly on server/cache-sourced `durationSeconds` values in four call sites in this diff (`setlist_detail_screen.dart:288,334,382`, `setlist_list_screen.dart:140`, `edit_track_screen.dart:38` via the initializer, and `setlist_formatting.dart`'s `tracksAndDuration`) with no upstream guarantee the value is non-negative — the values come straight from `as int`/`as int?` casts on decoded JSON, not from the client-side duration parser/validator that already guards against negative values on the input path. A malformed cache entry or a future server-side regression would silently render garbage instead of a clearly-wrong placeholder.
**Fix:**
```dart
extension DurationFormatting on int {
  String get asMinutesSeconds {
    final safe = this < 0 ? 0 : this;
    return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
  }
}
```
(or assert `this >= 0` in debug mode, whichever fits the project's error-handling conventions for defensively-untrusted display data).

### WR-02: New cross-feature imports break the codebase's relative-import convention

**File:** `lib/features/setlists/setlist_formatting.dart:1`, `lib/features/setlists/setlist_list_screen.dart:4`, `lib/features/setlists/setlist_detail_screen.dart:4`
**Issue:** All three files import the tracks feature's formatting helper via an absolute package import:
```dart
import 'package:cadence/features/tracks/track_formatting.dart';
```
Every other cross-directory import in `lib/features/` (including the other imports in these very same files, e.g. `'../../providers/setlists_provider.dart'`, `'../../widgets/offline_no_cache_view.dart'`) uses relative `../../` paths — there is no existing precedent for `package:cadence/...` imports anywhere else in `lib/features/`. This inconsistency was introduced entirely by this phase (confirmed via `git diff` — all three lines are new) and isn't a stylistic nit-pick: it's a codebase-wide pattern the phase silently deviates from, in the very same files that otherwise follow the relative-path style on adjacent lines.
**Fix:**
```dart
import '../tracks/track_formatting.dart';
```

## Info

### IN-01: Stale test description no longer matches its assertion

**File:** `test/features/setlists/setlist_detail_screen_test.dart:178`
**Issue:** This phase's diff updated the assertion from the old `Xm Ys` format to the new `mm:ss` format but left the test's descriptive string unchanged:
```dart
testWidgets(
    'zero tracks shows "No tracks in this setlist" and "0m 0s" duration',
    (tester) async {
      ...
      expect(find.text('0:00'), findsOneWidget);
    },
  );
```
The description still says `"0m 0s"` while the actual assertion checks for `'0:00'`. This is misleading in test-runner output and for anyone grepping test names to understand coverage. (The equivalent tests in `setlist_list_screen_test.dart` — e.g. `'10:00'`, `'1:00'`/`'42:35'` — do not have this problem; their descriptions were either updated or never referenced the format.)
**Fix:** Update the description to `'zero tracks shows "No tracks in this setlist" and "0:00" duration'`.

### IN-02: mm:ss validation logic is triplicated

**File:** `lib/features/tracks/track_formatting.dart:61-75` (`parseDurationSeconds`), `lib/features/tracks/create_track_screen.dart:55-74` (`_durationValidator`), `lib/features/tracks/edit_track_screen.dart:86-105` (`_durationValidator`)
**Issue:** The same parsing/validation rules (2-part colon split, whole-number minutes/seconds, non-negative, seconds ≤ 59) are implemented three separate times with near-identical logic. `edit_track_screen.dart`'s own doc comment acknowledges this is deliberate ("Duplicated per-file ... matching the existing `_wholeNumberValidator` per-file convention"), so this is a documented tradeoff rather than an oversight, but it's still three places that must be kept in sync if the duration rules ever change (e.g., an upper bound on minutes, or a different error message).
**Fix:** Consider extracting a single `String? validateDurationText(String? value)` helper alongside `parseDurationSeconds` in `track_formatting.dart` and calling it from both screens, so the validity rules and their user-facing messages have one source of truth. Not blocking given the existing per-file convention, but worth reconsidering if a third duration-input screen is ever added.

---

_Reviewed: 2026-08-25T11:01:10Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
