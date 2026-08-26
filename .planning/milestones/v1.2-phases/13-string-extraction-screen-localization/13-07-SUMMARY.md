---
phase: 13-string-extraction-screen-localization
plan: 07
subsystem: ui
tags: [flutter, l10n, arb, riverpod, widget-test]

requires:
  - phase: 13-01
    provides: "navHome/navBands/navTracks/navSetlists/navProfile and offlineBannerMessage ARB keys; test/test_strings.dart's tester.strings extension"
provides:
  - "root_scaffold.dart's 5 bottom-nav labels sourced from AppLocalizations instead of hardcoded English"
  - "offline_banner.dart's message sourced from AppLocalizations"
  - "offline_banner_test.dart and offline_cross_tab_test.dart asserting against tester.strings.* instead of hardcoded literals"
  - "locale_live_switch_test.dart's nav-tap helpers now locale-aware (regression fix)"
affects: [13-08, 13-09]

actuals:
  tokens: 2900
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Non-const NavigationDestination list once labels depend on AppLocalizations.of(context) (icons stay const, list/entries do not)"
    - "Widget tests needing tester.strings must wire localizationsDelegates/supportedLocales into their MaterialApp, and must guarantee at least one Text widget renders in every pumped state (added an anchor Text for the SizedBox.shrink() online case)"

key-files:
  created: []
  modified:
    - lib/navigation/root_scaffold.dart
    - lib/widgets/offline_banner.dart
    - test/widgets/offline_banner_test.dart
    - test/offline_cross_tab_test.dart
    - test/locale_live_switch_test.dart

key-decisions:
  - "Fixed test/locale_live_switch_test.dart (out-of-plan-scope file) because Task 1's nav-label localization broke its hardcoded find.text('Home')/find.text('Profile') taps once the locale switched to Russian — Rule 1 (bug directly caused by this plan's change), verified via full-suite run before closing out"

requirements-completed: [I18N-04]

coverage:
  - id: D1
    description: "root_scaffold.dart's 5 NavigationDestination labels (Home/Bands/Tracks/Setlists/Profile) render via AppLocalizations"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "flutter analyze lib/navigation/root_scaffold.dart"
        status: pass
      - kind: integration
        ref: "test/offline_cross_tab_test.dart#OFFL-05 / ROADMAP Phase 5 success criterion #3"
        status: pass
    human_judgment: false
  - id: D2
    description: "offline_banner.dart's message sourced from l10n.offlineBannerMessage; offline_banner_test.dart migrated to tester.strings"
    requirement: I18N-04
    verification:
      - kind: unit
        ref: "test/widgets/offline_banner_test.dart#offline shows the offline banner text"
        status: pass
      - kind: unit
        ref: "test/widgets/offline_banner_test.dart#online hides the offline banner text"
        status: pass
    human_judgment: false
  - id: D3
    description: "test/offline_cross_tab_test.dart migrated off top-level const bannerText/tabLabels to tester.strings lookups"
    requirement: I18N-04
    verification:
      - kind: integration
        ref: "test/offline_cross_tab_test.dart#OFFL-05 / ROADMAP Phase 5 success criterion #3"
        status: pass
    human_judgment: false
  - id: D4
    description: "Regression fix: locale_live_switch_test.dart's Profile/Home nav taps read the current locale's label instead of hardcoded English"
    verification:
      - kind: integration
        ref: "test/locale_live_switch_test.dart (all 3 tests)"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-08-26
status: complete
---

# Phase 13 Plan 07: Root Scaffold + Offline Banner Localization Summary

**Localized the bottom-nav bar's 5 labels and the offline banner's message via AppLocalizations, migrated both cross-cutting tests off hardcoded English literals, and fixed a regression this introduced in an unrelated locale-switch test that tapped the same nav labels.**

## Performance

- **Duration:** 10 min
- **Tasks:** 3 (plan) + 1 deviation fix
- **Files modified:** 5

## Accomplishments
- `root_scaffold.dart`'s `NavigationDestination` labels (Home/Bands/Tracks/Setlists/Profile) now render via `AppLocalizations.of(context)!.navHome`/etc., dropping `const` from the destinations list/entries (icons stay `const`)
- `offline_banner.dart`'s cached-data message now renders via `l10n.offlineBannerMessage`
- `test/widgets/offline_banner_test.dart` migrated to `tester.strings.offlineBannerMessage`, with `localizationsDelegates`/`supportedLocales` wired into its `MaterialApp` (previously missing) and an anchor `Text` added so `tester.strings` can resolve `AppLocalizations` even when the banner itself renders nothing (online case)
- `test/offline_cross_tab_test.dart`'s top-level `const bannerText`/`const tabLabels` replaced with `tester.strings.*` lookups computed at point of use
- Fixed a regression in `test/locale_live_switch_test.dart` (not in this plan's file scope, but directly broken by Task 1): `goToSettings()`'s `find.text('Profile')` and the IndexedStack-liveness test's `find.text('Home')` stopped matching once the nav labels became localized and the test switched to Russian — both now read `tester.strings.navProfile`/`tester.strings.navHome`

## Task Commits

Each task was committed atomically:

1. **Task 1: root_scaffold.dart — 5 nav labels** - `05812d5` (feat)
2. **Task 2: offline_banner.dart + test** - `7f0a267` (feat)
3. **Task 3: test/offline_cross_tab_test.dart — migrate nav-label and banner-text constants** - `8c487e8` (test)
4. **Deviation fix: locale_live_switch_test.dart regression** - `877bc61` (fix)

**Plan metadata:** committed alongside this SUMMARY.

## Files Created/Modified
- `lib/navigation/root_scaffold.dart` - 5 `NavigationDestination` labels sourced from `AppLocalizations`
- `lib/widgets/offline_banner.dart` - offline message sourced from `AppLocalizations`
- `test/widgets/offline_banner_test.dart` - migrated to `tester.strings`; added localization delegates + anchor Text to its minimal `MaterialApp` wrapper
- `test/offline_cross_tab_test.dart` - migrated nav-label/banner-text constants to `tester.strings` lookups
- `test/locale_live_switch_test.dart` - nav-tap helpers made locale-aware (regression fix, not in original plan scope)

## Decisions Made
- Fixed the out-of-scope `locale_live_switch_test.dart` regression rather than leaving it broken: it is a direct, mechanical consequence of Task 1's change (nav labels stopped being English-constant), not a pre-existing unrelated issue, so it falls squarely under deviation Rule 1 (auto-fix bugs directly caused by the current task's changes) rather than the scope-boundary exclusion for unrelated pre-existing failures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] offline_banner_test.dart's minimal MaterialApp lacked localizationsDelegates**
- **Found during:** Task 2 (running `flutter test test/widgets/offline_banner_test.dart` after the `tester.strings` migration)
- **Issue:** The test's `wrap()` helper built a bare `MaterialApp(home: Scaffold(body: OfflineBanner()))` with no `localizationsDelegates`/`supportedLocales`. `AppLocalizations.of(context)` returned `null`, so `offline_banner.dart`'s new `AppLocalizations.of(context)!` threw at build time, and `tester.strings` also failed with "could not find any Text widget in the pumped tree" (the widget never rendered its `Text`).
- **Fix:** Wired `localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]` and `supportedLocales: [Locale('en'), Locale('ru')]` into the test's `MaterialApp`, matching the existing pattern in `test/features/bands/band_detail_screen_test.dart`.
- **Files modified:** test/widgets/offline_banner_test.dart
- **Verification:** `flutter test test/widgets/offline_banner_test.dart` — both tests pass
- **Committed in:** 7f0a267 (Task 2 commit)

**2. [Rule 3 - Blocking] tester.strings unusable in the "online hides banner" test — no Text widget in tree**
- **Found during:** Task 2, same test run as above
- **Issue:** When `isOnline` is true, `OfflineBanner` returns `const SizedBox.shrink()` — no `Text` widget anywhere in the pumped tree. `tester.strings` requires at least one `Text` widget to read `AppLocalizations` off of, so `find.text(tester.strings.offlineBannerMessage)` threw a `StateError` before the assertion could even run.
- **Fix:** Added an always-rendered anchor `Text('anchor')` alongside `OfflineBanner()` in a `Column` in the test's `wrap()` helper. It never matches `offlineBannerMessage`, so the `findsOneWidget`/`findsNothing` assertions are unaffected, but it guarantees a `Text` widget exists for `tester.strings` to resolve `AppLocalizations` from in both online and offline states.
- **Files modified:** test/widgets/offline_banner_test.dart
- **Verification:** `flutter test test/widgets/offline_banner_test.dart` — both tests pass
- **Committed in:** 7f0a267 (Task 2 commit)

**3. [Rule 1 - Bug] locale_live_switch_test.dart broke after nav-label localization**
- **Found during:** post-Task-3 full-suite regression check (`flutter test`)
- **Issue:** `goToSettings()`'s `find.text('Profile')` (used both before and after switching to Russian) and the IndexedStack-liveness test's `find.text('Home')` (used after switching to Russian) hardcoded the English nav labels. Once Task 1 made those labels locale-dependent, both finders returned 0 widgets once the test's locale flipped to Russian, failing 2 of the file's 3 tests with "could not find any matching widgets".
- **Fix:** Imported `test/test_strings.dart` and replaced both hardcoded literals with `tester.strings.navProfile` / `tester.strings.navHome`, read fresh at each call site so they resolve correctly regardless of the test's current locale.
- **Files modified:** test/locale_live_switch_test.dart
- **Verification:** `flutter test test/locale_live_switch_test.dart` — all 3 tests pass; full-suite `flutter test` — 442/442 pass; `flutter analyze` — clean (whole project)
- **Committed in:** 877bc61 (separate deviation-fix commit, since the file is outside this plan's declared `files_modified`)

---

**Total deviations:** 3 auto-fixed (2 Rule 3 blocking, 1 Rule 1 bug)
**Impact on plan:** All three were necessary to make the plan's own acceptance criteria and the full test suite pass. No scope creep beyond what Task 1's change directly broke.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Bottom-nav bar and offline banner — the two most-visible shared chrome surfaces — are fully localized; both cross-cutting tests (`offline_banner_test.dart`, `offline_cross_tab_test.dart`) and the previously-passing `locale_live_switch_test.dart` all pass against localized text.
- Full test suite (442 tests) and `flutter analyze` (whole project) confirmed clean before close-out.
- Ready for the next plan in Phase 13's wave.

---
*Phase: 13-string-extraction-screen-localization*
*Completed: 2026-08-26*

## Self-Check: PASSED

- All 5 modified files confirmed present on disk.
- All 5 commits (05812d5, 7f0a267, 8c487e8, 877bc61, b752d08) confirmed in `git log`.
- All task-level `<acceptance_criteria>` re-verified passing.
- Plan-level `<verification>` commands re-run: `flutter test test/widgets/offline_banner_test.dart test/offline_cross_tab_test.dart` and `flutter analyze lib/navigation/root_scaffold.dart lib/widgets/offline_banner.dart` — both pass/clean.
- Full-suite regression check: `flutter test` (442/442 passing) and `flutter analyze` (whole project, clean).
