---
phase: 13-string-extraction-screen-localization
plan: 06
subsystem: ui
tags: [flutter, i18n, l10n, riverpod, widget-test]

# Dependency graph
requires:
  - phase: 13-01
    provides: "app_en.arb/app_ru.arb ARB keys for Profile/ChangePassword screens, test_strings.dart tester.strings extension"
provides:
  - "profile_screen.dart fully localized (title, refresh tooltip, ID/Settings/Change password/Log out labels, error state copy)"
  - "change_password_screen.dart fully localized (title, field labels, validators, snackbar, submit button, incorrect-current error)"
  - "Both screens' widget tests migrated to tester.strings.* assertions with AppLocalizations delegates wired into their MaterialApp test wrappers"
affects: [13-string-extraction-screen-localization]

# Actuals (#2632)
actuals:
  tokens: 6758
  tasks: 2
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Test MaterialApp wrappers for localized screens must declare localizationsDelegates ([AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]) and supportedLocales ([Locale('en'), Locale('ru')]) or AppLocalizations.of(context)! throws at test pump time -- mirrors the pattern already established in band_detail_screen_test.dart/settings_screen_test.dart."

key-files:
  created: []
  modified:
    - lib/features/profile/profile_screen.dart
    - lib/features/profile/change_password_screen.dart
    - test/features/profile/profile_screen_test.dart
    - test/features/profile/change_password_screen_test.dart

key-decisions:
  - "OfflineNoCacheView's 'No cached data'/'Connect to the internet to load this' assertions in profile_screen_test.dart were left as hardcoded literals -- that shared widget is out of this plan's files_modified scope (it wasn't touched here), so its own localization is a separate concern; asserting against tester.strings for copy owned by a different file would be misleading provenance even though the ARB values happen to match today."

patterns-established: []

requirements-completed: [I18N-04]

coverage:
  - id: D1
    description: "profile_screen.dart renders every visible string via AppLocalizations (title, refresh tooltip, ID/Settings/Change password/Log out labels, error state title/description/retry) with zero hardcoded English remaining in its own copy"
    requirement: "I18N-04"
    verification:
      - kind: unit
        ref: "test/features/profile/profile_screen_test.dart -- all 9 testWidgets"
        status: pass
      - kind: other
        ref: "flutter analyze lib/features/profile/profile_screen.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "change_password_screen.dart renders every visible string via AppLocalizations (title, 3 field labels, 3 validator messages incl. length/mismatch, snackbar, submit button, incorrect-current-password inline error) with zero hardcoded English remaining"
    requirement: "I18N-04"
    verification:
      - kind: unit
        ref: "test/features/profile/change_password_screen_test.dart -- all 8 testWidgets"
        status: pass
      - kind: other
        ref: "flutter analyze lib/features/profile/change_password_screen.dart"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both screens' test files assert against tester.strings.* (test_strings.dart) instead of hardcoded English literals for their own app copy"
    requirement: "I18N-04"
    verification:
      - kind: unit
        ref: "test/features/profile/profile_screen_test.dart, test/features/profile/change_password_screen_test.dart -- full suite"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-08-26
status: complete
---

# Phase 13 Plan 06: Profile + Change-Password Screen Localization Summary

**Profile tab and change-password screen now render every visible string via `AppLocalizations`, with both widget test files migrated to `tester.strings.*` assertions instead of hardcoded English literals.**

## Performance

- **Duration:** 25 min
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- `profile_screen.dart` localized: AppBar title, refresh tooltip, ID/Settings/Change password/Log out ListTile labels, and the error-state title/description/retry button all now read from `AppLocalizations.of(context)!`
- `change_password_screen.dart` localized: AppBar title, all 3 field labels, all validator messages (required/length/mismatch), the success snackbar, the submit button, and the 400 `invalid_input` inline error
- Both `profile_screen_test.dart` and `change_password_screen_test.dart` migrated their app-copy `find.text(...)`/`find.widgetWithText(...)` assertions to `tester.strings.keyName`, with `AppLocalizations.delegate` + supporting Global*Localizations delegates and `supportedLocales` wired into each test's `MaterialApp` wrapper(s)
- Profile is now the last of the 5 always-visible bottom-nav tabs (Home, Songs/Tracks, Bands, Setlists, Profile) to be fully localized for this phase's scope

## Task Commits

Each task was committed atomically:

1. **Task 1: profile_screen.dart + test** - `11e88cf` (feat)
2. **Task 2: change_password_screen.dart + test** - `c8429c1` (feat)

_Note: this is a worktree-isolated execution; the plan-metadata commit (SUMMARY.md) is committed separately per the worktree protocol._

## Files Created/Modified
- `lib/features/profile/profile_screen.dart` - Localized AppBar title/tooltip, ListTile labels, and error state copy
- `lib/features/profile/change_password_screen.dart` - Localized AppBar title, field labels, validators, snackbar, submit button, and inline error copy
- `test/features/profile/profile_screen_test.dart` - Migrated app-copy assertions to `tester.strings.*`; added `AppLocalizations.delegate` + `supportedLocales` to the `wrap()` MaterialApp
- `test/features/profile/change_password_screen_test.dart` - Migrated app-copy assertions to `tester.strings.*`; added `AppLocalizations.delegate` + `supportedLocales` to both `wrap()` and `wrapWithListRoot()` MaterialApp wrappers

## Decisions Made
- Left `OfflineNoCacheView`'s two strings ("No cached data" / "Connect to the internet to load this") as hardcoded literals in `profile_screen_test.dart` — that shared widget file is not in this plan's `files_modified` and wasn't touched; its own localization (if any) belongs to whichever plan owns that file.

## Deviations from Plan

None — plan executed exactly as written. The plan's `<action>` blocks did not mention that the test `MaterialApp` wrappers needed `localizationsDelegates`/`supportedLocales` added (an omission from the plan text, not a deviation from it in spirit), which surfaced immediately as a hard test failure (`AppLocalizations.of(context)!` returning null) the moment `l10n.` calls were added to the widgets. This is Rule 3 (auto-fix blocking issue): without it, every widget test crashes on first pump. Fixed by mirroring the exact pattern already established in `band_detail_screen_test.dart`/`settings_screen_test.dart` (same delegate list, same `[Locale('en'), Locale('ru')]` supported-locales list).

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added missing AppLocalizations delegates to test MaterialApp wrappers**
- **Found during:** Task 1 (profile_screen.dart + test) — first `flutter test` run failed with `Null check operator used on a null value` at `AppLocalizations.of(context)!`, since neither test file's `MaterialApp` had `localizationsDelegates`/`supportedLocales` configured
- **Issue:** `AppLocalizations.of(context)` returns `null` unless a `MaterialApp` declares `AppLocalizations.delegate` (plus the three `Global*Localizations` delegates) and a matching `supportedLocales` list — both test wrappers were plain `MaterialApp(home: ...)` with no localization config
- **Fix:** Added `localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]` and `supportedLocales: [Locale('en'), Locale('ru')]` to `profile_screen_test.dart`'s `wrap()` and `change_password_screen_test.dart`'s `wrap()`/`wrapWithListRoot()`, matching the existing pattern in `band_detail_screen_test.dart`
- **Files modified:** test/features/profile/profile_screen_test.dart, test/features/profile/change_password_screen_test.dart
- **Verification:** `flutter test test/features/profile/profile_screen_test.dart test/features/profile/change_password_screen_test.dart` — all 17 tests pass
- **Committed in:** 11e88cf (Task 1), c8429c1 (Task 2)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for the plan's own stated tests to run at all once localization was applied; no scope creep beyond the two in-scope test files.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Profile tab and change-password screen are fully localized end-to-end; both `flutter test` and `flutter analyze` pass clean on all 4 touched files
- No stubs, TODOs, or deferred items introduced by this plan
- Ready for the wave's remaining plans (Songs/Tracks, Setlists) to proceed independently

---
*Phase: 13-string-extraction-screen-localization*
*Completed: 2026-08-26*
