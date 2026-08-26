---
phase: 13-string-extraction-screen-localization
plan: 05
subsystem: ui
tags: [flutter, dart, l10n, arb, riverpod, flutter_localizations]

# Dependency graph
requires:
  - phase: 13-string-extraction-screen-localization (13-01)
    provides: ARB keys (homeAppBarTitle, homeWelcomeMessage, homeQuickActionsHeader, homeAddBandButton, homeAddSongButton, homeAddSetlistButton, homeErrorTitle, bandPickerErrorMessage) and test/test_strings.dart's tester.strings extension
provides:
  - Home tab (home_screen.dart) fully localized (AppBar title, refresh tooltip, welcome message, Quick Actions header, 3 action buttons, error state)
  - band_picker_sheet.dart's error message localized
  - locale_live_switch_test.dart's I18N-02 criterion-5 test now asserts real rendered Home AppBar text, not just the ambient Localizations locale code
  - root_scaffold.dart's 5 NavigationDestination labels localized (out-of-scope Rule 3 fix, unblocks this plan's Task 3 verification; mirrors sibling plan 13-07's exact spec to minimize merge conflict)
affects: [13-07, 13-13]

# Actuals (#2632)
actuals:
  tokens: 5926
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AppLocalizations.of(context)! re-derived per-method (build(), _buildContent(), _buildError()) rather than threaded as a parameter, since each already receives its own context"
    - "Test MaterialApp harnesses need explicit localizationsDelegates/supportedLocales wired in, or AppLocalizations.of(context) null-check-crashes -- established already in bands/create_band_screen tests, applied here to home_screen_test.dart and band_picker_sheet_test.dart"
    - "tester.strings finder ambiguity: when two ARB keys share an English value (homeAppBarTitle == navHome == 'Home'), scope the Finder to a specific ancestor (find.descendant(of: find.byType(AppBar), ...)) rather than a bare find.text()"

key-files:
  created: []
  modified:
    - lib/features/home/home_screen.dart
    - lib/features/home/band_picker_sheet.dart
    - lib/navigation/root_scaffold.dart
    - test/features/home/home_screen_test.dart
    - test/features/home/band_picker_sheet_test.dart
    - test/locale_live_switch_test.dart

key-decisions:
  - "Localized root_scaffold.dart's nav-bar labels ahead of sibling plan 13-07 (Rule 3, out-of-plan-scope fix) because Task 3's verify step requires tester.strings.navHome to match real rendered text, and 13-07 (same wave, same depends_on, not yet merged) owns that file. Implemented it verbatim per 13-07-PLAN.md's own Task 1 action text (same ARB keys, same code shape) specifically to minimize merge-conflict surface when 13-07 lands."
  - "Scoped the Home AppBar-title assertions in locale_live_switch_test.dart to find.descendant(of: find.byType(AppBar), ...) since homeAppBarTitle and navHome are both literally 'Home' in English -- a bare find.text() found 2 widgets and failed with 'is too many'."
  - "Fixed goToSettings()'s nav-bar tap (same test file, in scope) to read tester.strings.navProfile fresh at call time instead of a hardcoded 'Profile' literal -- the pre-existing I18N-03 restart test calls this helper a second time after Russian has already persisted, and the now-localized nav-bar label would otherwise render 'Профиль'."

patterns-established:
  - "Cross-wave-plan file overlap risk: when a wave-2 plan's verify step assumes a sibling wave-2 plan's (not-yet-merged, same depends_on) output, mirror that sibling plan's exact action text when applying the Rule 3 fix, to keep the post-merge diff conflict-free or trivially auto-resolved."

requirements-completed: [I18N-04]

coverage:
  - id: D1
    description: "Home tab (home_screen.dart) renders every visible string via AppLocalizations -- AppBar title, refresh tooltip, welcome message, Quick Actions header, 3 action buttons, error title/body/retry -- with home_screen_test.dart asserting against tester.strings.* instead of hardcoded English"
    requirement: "I18N-04"
    verification:
      - kind: unit
        ref: "test/features/home/home_screen_test.dart (all 11 testWidgets)"
        status: pass
    human_judgment: false
  - id: D2
    description: "band_picker_sheet.dart's error message localized via l10n.bandPickerErrorMessage; band_picker_sheet_test.dart asserts against tester.strings.bandPickerErrorMessage"
    requirement: "I18N-04"
    verification:
      - kind: unit
        ref: "test/features/home/band_picker_sheet_test.dart (all 7 testWidgets)"
        status: pass
    human_judgment: false
  - id: D3
    description: "locale_live_switch_test.dart's I18N-02 criterion-5 test proves the IndexedStack-kept-alive Home tab re-renders real text (not just the ambient locale) before and after a live Russian switch"
    requirement: "I18N-04"
    verification:
      - kind: unit
        ref: "test/locale_live_switch_test.dart#I18N-02 success criterion 5: an IndexedStack tab kept alive in the background reports the new locale once navigated to"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-08-26
status: complete
---

# Phase 13 Plan 05: Home Tab + Band Picker Localization Summary

**Home tab and shared band-picker bottom sheet fully localized (EN/RU) via AppLocalizations, with locale_live_switch_test.dart now proving cross-tab locale propagation against real rendered Home AppBar text instead of just the ambient `Localizations.localeOf()` value.**

## Performance

- **Duration:** 12 min
- **Tasks:** 3 completed
- **Files modified:** 6 (2 out-of-plan-scope via Rule 3: `lib/navigation/root_scaffold.dart`, and the `goToSettings()` helper fix inside `test/locale_live_switch_test.dart` which was already in-scope)

## Accomplishments

- `home_screen.dart`: AppBar title, refresh tooltip, welcome message, Quick Actions header, all 3 action buttons (Add Band/Song/Setlist), and the error state (title/body/retry) now render via `AppLocalizations.of(context)!`
- `band_picker_sheet.dart`: the "Could not load bands" error message now renders via `l10n.bandPickerErrorMessage`
- Both screens' test files migrated to `tester.strings.*` and gained proper `localizationsDelegates`/`supportedLocales` test-harness wiring (previously missing, causing a null-check crash the moment the screen tried to read `AppLocalizations.of(context)`)
- `locale_live_switch_test.dart`'s I18N-02 criterion-5 test strengthened: asserts the real Home AppBar text (English, then Russian) rather than only the ambient `Localizations.localeOf()` language code, closing the gap RESEARCH.md's Validation Architecture section flagged
- `root_scaffold.dart`'s 5 `NavigationDestination` labels localized (Rule 3 fix, see Deviations) so the strengthened test's `tester.strings.navHome` tap-finder actually matches rendered text

## Task Commits

Each task was committed atomically:

1. **Task 1: home_screen.dart + test** - `b24b3d1` (feat)
2. **Task 2: band_picker_sheet.dart + test** - `f07e5fa` (feat)
3. **Task 3: Strengthen locale_live_switch_test.dart's I18N-02 criterion-5 check** - `49d46d2` (test, includes the root_scaffold.dart Rule 3 fix)

## Files Created/Modified

- `lib/features/home/home_screen.dart` - AppBar/welcome/quick-actions/buttons/error text now via `l10n.*`
- `lib/features/home/band_picker_sheet.dart` - error message via `l10n.bandPickerErrorMessage`
- `lib/navigation/root_scaffold.dart` - 5 `NavigationDestination` labels via `l10n.nav*` (Rule 3, out-of-scope, mirrors 13-07-PLAN.md Task 1 verbatim)
- `test/features/home/home_screen_test.dart` - migrated to `tester.strings.*`, added `localizationsDelegates`/`supportedLocales` to test harness
- `test/features/home/band_picker_sheet_test.dart` - migrated to `tester.strings.*`, added `localizationsDelegates`/`supportedLocales` to test harness
- `test/locale_live_switch_test.dart` - strengthened I18N-02 criterion-5 test; fixed `goToSettings()`'s nav-bar tap to use `tester.strings.navProfile`

## Decisions Made

- Localized `root_scaffold.dart` ahead of sibling plan 13-07 landing (Rule 3 auto-fix), implemented verbatim per 13-07-PLAN.md's own Task 1 action text to minimize post-merge conflict surface — see Deviations below for full rationale.
- Scoped the Home-AppBar-title `tester.strings` assertions to `find.descendant(of: find.byType(AppBar), ...)` since `homeAppBarTitle` and `navHome` are both literally "Home" in English, which made a bare `find.text()` ambiguous (2 matches).
- Fixed `goToSettings()`'s nav-bar tap (same in-scope test file) to read `tester.strings.navProfile` fresh at call time instead of a hardcoded `'Profile'` literal, since the pre-existing I18N-03 restart test calls this helper again after Russian has already persisted.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Missing `localizationsDelegates`/`supportedLocales` in home_screen_test.dart and band_picker_sheet_test.dart's test `MaterialApp` harnesses**
- **Found during:** Task 1 and Task 2 (running `flutter test` after localizing each screen)
- **Issue:** Both test files' `wrap()` helpers built a bare `MaterialApp(home: ...)` with no `AppLocalizations.delegate` wired in. Once the screens called `AppLocalizations.of(context)!`, every test crashed with a null-check-operator exception.
- **Fix:** Added `localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]` and `supportedLocales: [Locale('en'), Locale('ru')]` to both `MaterialApp` widgets, mirroring the already-established pattern in `test/features/bands/create_band_screen_test.dart`.
- **Files modified:** test/features/home/home_screen_test.dart, test/features/home/band_picker_sheet_test.dart
- **Verification:** `flutter test` — all 19 tests across both files pass.
- **Committed in:** b24b3d1, f07e5fa

**2. [Rule 3 - Blocking] root_scaffold.dart's nav-bar labels not yet localized, blocking Task 3's verify step**
- **Found during:** Task 3 (writing `tester.strings.navHome` per the plan's literal instruction)
- **Issue:** Task 3's action text instructs using `tester.strings.navHome` for the nav-bar tap, "since the nav-bar label itself is now localized" — but that localization is owned by sibling plan 13-07 (same wave, `depends_on: ["13-01"]`, executing in a separate parallel worktree not yet merged into this one). In this isolated worktree, `root_scaffold.dart` still hardcoded English nav labels, so `tester.strings.navHome` (which reads off the currently-active `AppLocalizations` locale, Russian at that point in the test) would never match the actually-rendered hardcoded English text — the tap would fail to find its target and the whole test would fail.
- **Fix:** Localized `root_scaffold.dart`'s 5 `NavigationDestination` labels via `l10n.navHome`/`navBands`/`navTracks`/`navSetlists`/`navProfile` — using ARB keys that already existed (landed by 13-01, consumed by 13-07's own artifact list) and implementing the change **verbatim per 13-07-PLAN.md's own Task 1 action text** (same import, same `final l10n = AppLocalizations.of(context)!;`, same `destinations: [...]` structure with `const` dropped only from the outer list/`NavigationDestination` entries, `Icon(...)` children staying `const`) — specifically to produce a byte-for-byte-identical diff hunk to what 13-07 will independently produce, so a 3-way git merge resolves the overlap without a conflict rather than requiring manual reconciliation.
- **Files modified:** lib/navigation/root_scaffold.dart
- **Verification:** `flutter analyze lib/navigation/root_scaffold.dart` — no issues. Full `flutter test` suite (442 tests) — all pass, including `test/offline_cross_tab_test.dart` and `test/widget_test.dart` which also exercise the nav bar and were unaffected (English-locale-default assertions still match).
- **Committed in:** 49d46d2

**3. [Rule 1 - Bug] goToSettings()'s nav-bar tap broke for the post-restart Russian-persisted case once root_scaffold.dart's labels were localized**
- **Found during:** Task 3, after applying fix #2 above — running `flutter test test/locale_live_switch_test.dart` revealed the pre-existing I18N-03 test now failed on its second `goToSettings(tester)` call (after simulating an app restart with Russian already persisted).
- **Issue:** `goToSettings()` hardcoded `find.text('Profile')` for the nav-bar tap. Once `root_scaffold.dart`'s Profile label became `l10n.navProfile`, the second call (post-restart, Russian already active from a persisted `SharedPreferences` value) rendered "Профиль", not "Profile", so the tap's Finder matched nothing.
- **Fix:** Changed the Finder to `find.text(tester.strings.navProfile)`, evaluated fresh each time the helper is called, so it reads whichever locale is currently active (English on the first call, persisted Russian on subsequent calls).
- **Files modified:** test/locale_live_switch_test.dart (already in this task's file scope)
- **Verification:** `flutter test test/locale_live_switch_test.dart` — all 3 tests pass (I18N-01/02, I18N-02 criterion-5, I18N-03).
- **Committed in:** 49d46d2

---

**Total deviations:** 3 auto-fixed (2 blocking test-infra/cross-plan gaps, 1 bug caused by fix #2)
**Impact on plan:** All three fixes were necessary for the plan's own stated verify steps to pass. Fix #2 touches a file outside this plan's declared `files_modified` (`lib/navigation/root_scaffold.dart`), which is also `files_modified` by sibling wave-2 plan 13-07 — flagging this explicitly since the orchestrator's post-wave merge may see this file changed on two branches. The change was deliberately implemented to match 13-07-PLAN.md's own Task 1 spec verbatim, so the merge should either resolve automatically (identical diff) or require only a trivial manual reconciliation if 13-07's real implementation differs cosmetically.

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Home tab and band-picker sheet are fully localized; no hardcoded English remains in either.
- `locale_live_switch_test.dart` now provides a stronger regression guard against future IndexedStack-tab locale-propagation bugs.
- **Flag for the orchestrator/next executor:** `lib/navigation/root_scaffold.dart` was modified by this plan (13-05) via a Rule 3 deviation, ahead of sibling plan 13-07 which also declares this file in its `files_modified`. When merging wave 2, check whether 13-07's branch also touches `root_scaffold.dart` — if its Task 1 was implemented per its own plan spec (as this plan assumed), the merge should be conflict-free; if not, manual reconciliation of the 5 `NavigationDestination` labels may be needed.

## Self-Check: PASSED

- FOUND: lib/features/home/home_screen.dart
- FOUND: lib/features/home/band_picker_sheet.dart
- FOUND: lib/navigation/root_scaffold.dart
- FOUND: test/features/home/home_screen_test.dart
- FOUND: test/features/home/band_picker_sheet_test.dart
- FOUND: test/locale_live_switch_test.dart
- FOUND commit: b24b3d1 (Task 1)
- FOUND commit: f07e5fa (Task 2)
- FOUND commit: 49d46d2 (Task 3)

---
*Phase: 13-string-extraction-screen-localization*
*Completed: 2026-08-26*
