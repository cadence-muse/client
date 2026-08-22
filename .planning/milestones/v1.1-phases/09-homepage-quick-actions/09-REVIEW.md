---
phase: 09-homepage-quick-actions
reviewed: 2026-08-21T22:28:15Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - lib/features/home/band_picker_sheet.dart
  - lib/features/home/home_screen.dart
  - test/features/home/band_picker_sheet_test.dart
  - test/features/home/home_screen_test.dart
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 09: Code Review Report

**Reviewed:** 2026-08-21T22:28:15Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the Homepage Quick Actions band-picker sheet, the Home tab screen, and
their widget tests. `flutter analyze` is clean and both test files pass in
full (19/19). The offline-first data flow (`bandsListDataProvider`,
`homepageDataProvider`), the D-07/D-08 dismiss-without-error behavior, and the
error-message redaction (V7) are all implemented and tested correctly.

No security or correctness-blocking defects were found. One robustness gap
stands out: the band-picker's list of `ListTile`s is not wrapped in a
scrollable container, so it will visibly overflow once a user has more bands
than fit in the sheet's default (9/16-screen-height) constraint — untested
and unhandled. Two minor code-quality items (an unused parameter and
confusing variable shadowing) round out the findings.

## Warnings

### WR-01: Band-picker list has no scroll container — overflows once bands exceed the sheet's height

**File:** `lib/features/home/band_picker_sheet.dart:34-49`
**Issue:** The sheet's band list is built as a plain `Column` inside a
non-scrollable `Consumer`/`SafeArea`, and `showModalBottomSheet` is called
without `isScrollControlled: true`:

```dart
data: (bands) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final band in bands)
      ListTile(
        leading: const Icon(Icons.group),
        title: Text(band['name'] as String, ...),
        onTap: () => Navigator.of(sheetContext).pop(band['id'] as String),
      ),
  ],
),
```

Flutter's default (non-scroll-controlled) modal bottom sheet route
constrains its child to `constraints.maxHeight * 9/16`. With standard
`ListTile` height (~56dp) that's roughly 7-8 tiles before the `Column`
overflows its constraints, producing a `RenderFlex overflowed` error (visible
red/yellow stripes in debug, silently clipped content in release) and making
any band beyond that point untappable. Nothing in
`band_picker_sheet_test.dart` exercises more than 2 bands, so this gap is
untested. This is a realistic scenario for any user in more than a handful of
bands, not a hypothetical edge case.

**Fix:** Wrap the list in a bounded, scrollable widget, e.g.:

```dart
data: (bands) => Flexible(
  child: ListView(
    shrinkWrap: true,
    children: [
      for (final band in bands)
        ListTile(
          leading: const Icon(Icons.group),
          title: Text(band['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => Navigator.of(sheetContext).pop(band['id'] as String),
        ),
    ],
  ),
),
```

(or pass `isScrollControlled: true` to `showModalBottomSheet` and use a
`DraggableScrollableSheet`/`ListView.builder`). Add a test seeding >10 bands
and asserting no overflow / that the last band is reachable via scroll.

## Info

### IN-01: `showBandPickerSheet`'s `ref` parameter is never used

**File:** `lib/features/home/band_picker_sheet.dart:22-26`
**Issue:** `showBandPickerSheet(BuildContext context, WidgetRef ref, {required bool forTrack})`
takes a `WidgetRef` that is never referenced in the function body. All
provider access happens through the nested `Consumer(builder: (context, ref, _) { ... })`,
whose `ref` parameter shadows (and shadows out) the outer one. Both call
sites (`home_screen.dart:139,146` and the test harness) are forced to thread
a `WidgetRef` through for no effect, which is misleading — a future reader
may assume the outer `ref` is what drives the sheet's data and try to
`ref.invalidate(...)` it expecting an effect on the open sheet.
**Fix:** Drop the unused `ref` parameter from the signature (and its two call
sites), since the `Consumer` already supplies its own scoped `ref`:

```dart
Future<void> showBandPickerSheet(
  BuildContext context, {
  required bool forTrack,
}) async { ... }
```

### IN-02: Shadowed `context`/`ref` names reduce readability

**File:** `lib/features/home/band_picker_sheet.dart:31`
**Issue:** `Consumer(builder: (context, ref, _) { ... })` reuses the names
`context` and `ref` from the enclosing `showBandPickerSheet(BuildContext context, WidgetRef ref, ...)`
signature and from `showModalBottomSheet`'s own `builder: (sheetContext) => ...`.
While technically correct here (the innermost `context`/`ref` are the ones
that should be used within the `Consumer`), the shadowing makes it easy for a
future edit to reach for the wrong-scoped `context`/`ref` without the
analyzer flagging it, especially once IN-01 is fixed and the outer `ref` no
longer exists to compare against.
**Fix:** Rename the `Consumer` builder's parameters, e.g.
`builder: (tileContext, sheetRef, _) { ... }`, to make the distinct scopes
explicit.

---

_Reviewed: 2026-08-21T22:28:15Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
