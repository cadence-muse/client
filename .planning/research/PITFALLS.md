# Pitfalls Research: i18n + Duration Input

**Domain:** Flutter i18n localization (EN/RU, live switching) + mm:ss duration input in mature app with 401 tests and offline cache

**Researched:** 2026-08-25

**Confidence:** HIGH (based on codebase structure: 279 hardcoded string assertions in tests, Riverpod provider architecture, Hive-backed cache layer, no existing i18n patterns)

---

## Critical Pitfalls

### Pitfall 1: Widget Tests Hardcoded on English Strings Will Silently Pass With Wrong Content

**What goes wrong:**
The codebase contains ~279 `find.text('English string')` assertions across 401 tests. When you swap to a localized string, tests pass if the key is defined in the translations file but the test never reloads the locale, or the widget renders an unexpected fallback instead of a proper value.

**Example:** A test does `expect(find.text('No tracks'), findsOneWidget)`, but the track list screen now renders `Text(trl.strings.empty_tracks_ru)`. The test still passes if the localization system fails silently.

**Why it happens:**
- Widget tests don't automatically load translated strings; the test harness must explicitly set the locale and rebuild
- Hardcoded assertions are written once and never re-verified when strings change
- No systematic way to flag "this string now needs a translation key" across 400+ tests
- Silent fallback behavior masks incomplete migration

**How to avoid:**
1. Before touching localization: Run `grep -r "expect.*find.text\(" test/ | wc -l` to catalog 279 hardcoded assertions
2. Create a test-strings utility extracting all patterns into `test/fixtures/test_strings.dart` with constants
3. Assert locale is set in widget tests; each test `setUp()` must explicitly set locale
4. Create a `verifyLocalizationCoverage()` golden test rendering every screen with both EN and RU
5. Use a localization key detector: before shipping, grep for `Text('` (not `Text(trl...`) and fail build if any remain

**Warning signs:**
- Tests pass even after renaming a hardcoded string in one place but not another
- A new screen renders but localization key appears in the UI (e.g., `'trl_strings_empty'`)
- Widget test fails during locale switch, but all other tests pass
- Manual QA finds untranslated strings that automated tests never caught

**Phase to address:** **Phase 1 (Spec/Infrastructure)**

---

### Pitfall 2: Locale Change Doesn't Propagate to Cached/Offline Screens Without Manual Provider Invalidation

**What goes wrong:**
User views Bands list (cached data) in English, switches locale to Russian, but the screen still shows English strings. The cached data itself is language-neutral (JSON), but strings rendered around it are stale.

**Example flow:**
1. User loads Bands tab → caches English strings + fetches data
2. User opens Profile, switches locale Russian
3. User returns to Bands tab — band data still there (cache hit), but text labels still English

**Why it happens:**
- Riverpod doesn't auto-invalidate providers when an unrelated provider (locale) changes
- Cached data reads don't depend on locale; locale must be a separate dependency
- Offline banner, empty-state messages, and error text often don't re-listen to locale changes

**How to avoid:**
1. Make locale a top-level provider dependency with a `LocaleController`
2. Include locale as a parameter in every string-producing provider (forces re-compute on change)
3. For cached screens, add locale as a dependency in `build()`
4. Every screen that renders hardcoded strings must watch locale
5. Wrap offline banner and error messages in consumers that watch locale

**Warning signs:**
- Switching locale in Profile, navigating back to another tab, seeing stale English text
- Cached screens don't rebuild when locale changes (only full app restart fixes it)
- Offline banner text doesn't update when locale switches
- Test: open tab, go to Profile, switch locale, return to tab — if UI strings don't refresh, this is the culprit

**Phase to address:** **Phase 1 (Infrastructure)**

---

### Pitfall 3: Hardcoded Widget Tests Break When Localization Strings Are Lazy-Loaded

**What goes wrong:**
Introduce a localization system (intl, easy_localization, custom JSON). Tests relying on `find.text('No tracks')` can't find the text because:
- The locale hasn't been explicitly set in test harness
- Translations file isn't loaded or is loaded asynchronously
- Test uses default English locale but translations system initializes with Russian first

**Why it happens:**
- Localization libraries often load translations asynchronously (disk I/O, async JSON parsing)
- Tests don't wait for async initialization; `pumpWidget()` returns before localization is ready
- Default fallback won't match the test's hardcoded expectation
- Different libraries handle missing/incomplete translations differently

**How to avoid:**
1. Pre-load translations synchronously in test `setUpAll()`
2. Use a synchronous fallback locale provider in tests via overrides
3. Create a test helper to await localization
4. Run critical tests with both EN and RU via parameterized loops
5. Use `find.byType(EmptyStateWidget)` instead of `find.text(...)` for widget-tree assertions

**Warning signs:**
- Tests pass locally but fail in CI (different initialization order)
- A new test sometimes fails on first run but passes on re-run (initialization race)
- Adding a new screen with hardcoded text fails with "Expected to find widget, but found none"
- Switching between EN/RU in a test causes one to fail consistently

**Phase to address:** **Phase 1 (Infrastructure)**

---

### Pitfall 4: Duration Input Parsing Accepts Invalid Formats ("5:60", Negative, Leading Zeros)

**What goes wrong:**
User enters `"5:60"` (invalid: 60 seconds) and the parser doesn't reject it. App converts silently to 420 seconds (7:00), masking the invalid input. When user views the duration, it displays as `7:00`, not 5:60 they entered.

**Other edge cases:**
- `"-5:30"` (negative) → silently parsed as -270 seconds
- `":"` (empty parts) → `int.parse('')` throws, catch-all suppresses error
- `"120:00"` (120 minutes) → technically valid but should be clamped

**Why it happens:**
- `int.parse()` is lenient; `"-5"` is valid
- No explicit `min/max` bounds check on each component
- No validation that `seconds < 60`
- No regex or state-machine parser

**How to avoid:**
1. Define strict parser with validation:
   - Validate format (exactly 2 parts split by `:`)
   - Check both components are non-negative
   - Check seconds < 60
   - Cap minutes at sensible max (999 or setlist-aware limit)
2. Add comprehensive test cases for all edge cases
3. Add input validation to TextEditingController with real-time feedback
4. Use a masked input field (optional but user-friendly)
5. Cap duration at sensible maximum (track < 1 hour, setlist < 5 hours)

**Warning signs:**
- User enters `"10:70"` and app silently converts to `"11:10"`
- Duration input accepts `"-0:30"` but later UI shows as `"0:30"` (silent sign flip)
- Test: `expect(parseDurationInput('5:60'), equals(...))` passes without a throw
- QA finds manually entered duration changes value after saving and reloading

**Phase to address:** **Phase 2 (Duration Input Implementation)**

---

### Pitfall 5: Russian Text Overflow in Fixed-Width Layouts

**What goes wrong:**
A badge showing "Исполнитель" (12 chars in RU vs 9 in EN "Performer") overflows a fixed-width `SizedBox(width: 120)` sized for English. Text clips or wraps unexpectedly. Russian words tend to be longer than English equivalents.

**Examples:**
- EN: "Band" (4) → RU: "Группа" (6)
- EN: "Delete" (6) → RU: "Удалить" (7)

**Why it happens:**
- Widgets designed and tested only with English
- Fixed widths eyeballed for EN lengths
- No responsive width logic (maxLines, overflow: ellipsis) built in
- Localization added as late-stage pass without re-measuring for RU

**How to avoid:**
1. Replace fixed widths with flexible layouts from start: use `Flexible` instead of `SizedBox`
2. Test with longest expected strings at design time
3. Add "localization layout test" rendering all screens with RU locale
4. For badges/chips: use `maxLines: 1, overflow: TextOverflow.ellipsis` consistently
5. For table cells: set max width and let text wrap

**Warning signs:**
- Manual QA finds text clipping or unexpected ellipsis when RU selected
- Switching locale mid-UI causes visible layout jank (text suddenly clips)
- A button label like "Удалить" appears as "Удали…" but "Delete" fits fine
- Nested flex constraints fail with "A RenderFlex overflowed" warnings when RU active

**Phase to address:** **Phase 1 (Infrastructure/UI Spec)**

---

### Pitfall 6: Pluralization Rules Differ Radically Between English and Russian

**What goes wrong:**
English: singular/plural (1 track vs 2+ tracks). Russian: 3 forms (один трек, два трека, пять треков). Naive hardcoding:
```dart
String trackCount(int n) => n == 1 ? '1 track' : '$n tracks';
```

doesn't work for RU. Without rethinking pluralization during i18n, you'll either use EN rules for RU (wrong grammar) or leave it untranslated.

**Example:**
- EN: "1 track, 2 tracks, 5 tracks" → correct
- RU with EN rules: "1 трек, 2 трека, 5 треков" → wrong for "2" (should be "2 трека")

The codebase currently has hardcoded `pluralizeTracks()` that must be replaced before i18n.

**Why it happens:**
- Pluralization rules are language-specific and complex; easy to forget when adding localization
- Localization libraries don't automatically handle pluralization; must configure rules
- No plural abstraction in existing code (just if/else), so pattern doesn't migrate well
- Testing pluralization requires test strings in both EN and RU

**How to avoid:**
1. Introduce plural-aware translation system early with language-specific rule functions
2. Define all pluralized strings in structured file with 3 RU forms, 2 EN forms
3. Replace all hardcoded plural functions (e.g., `pluralizeTracks()`)
4. Test all plural forms for each language (1, 2, 5, 11, 21, 22, 100, 101, 102)
5. Don't defer pluralization to "later"

**Warning signs:**
- A pluralization helper like `pluralizeTracks()` exists and isn't parameterized by locale
- Tests only use EN counts (1, 2, 100), not RU special cases (11, 21, 22)
- QA finds "1 треков" (1 files, grammatically wrong) in RU UI
- Switching EN to RU, plural form doesn't change (stays "2 tracks" instead of "2 трека")

**Phase to address:** **Phase 1 (Infrastructure)**

---

### Pitfall 7: Locale Switch in Profile Doesn't Rebuild Screens Behind BottomNavigationBar

**What goes wrong:**
User is on Bands tab (index 2). They switch to Profile (index 3), change locale RU, and return to Bands. The Bands tab is still mounted (IndexedStack keeps all alive), but the provider watching locale didn't trigger rebuild because tab was out of sight.

Bands screen code might not watch locale:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final bands = ref.watch(bandsListDataProvider);
  // NO ref.watch(localeControllerProvider)
  return BandsListView(bands);
}
```

When user returns, cached data returns same state (no network), but since screen never watched locale, it never rebuilds with RU strings.

**Why it happens:**
- IndexedStack mounts but doesn't actively render out-of-view children
- Riverpod doesn't auto-invalidate when unrelated provider (locale) changes
- Screen rebuilds on data changes but not on locale changes (no watch)
- "Out of view" != "not mounted" in IndexedStack

**How to avoid:**
1. Establish "always watch locale" as standing pattern in every screen
2. Create helper widget to enforce pattern (abstract `LocalizedScreen`)
3. Add lint rule or test to verify all screens watch locale
4. Test tab-switching with locale change to verify strings update

**Warning signs:**
- User switches locale in Profile; other tabs still show old language until app restart
- Cached screen's locale strings stale after locale switch (only updates on next fetch)
- IndexedStack: Profile → change locale → other tab shows outdated strings
- Out-of-view screens don't refresh when unrelated state (locale) changes

**Phase to address:** **Phase 2 (i18n Implementation)**

---

### Pitfall 8: Duration Display Format Inconsistency (mm:ss vs "m s")

**What goes wrong:**
Codebase currently has two formats:
- **Tracks:** mm:ss (e.g., `"3:45"`) via `track_formatting.dart`
- **Setlists:** "m s" format (e.g., `"42m 35s"`) via `setlist_formatting.dart`

When adding duration *input* (mm:ss), you must decide if you unify displays or keep separate formats. If not explicit, you'll confuse users: they see `"3:45"` on a track, then `"42m 35s"` on a setlist, and can't directly add durations.

**Why it happens:**
- Two developers wrote separate files without coordinating
- No single "canonical" duration display format established upfront
- Input/output formats not designed together

**How to avoid:**
1. Establish one canonical format (mm:ss) for entire app before adding input
2. Audit existing `asMinutesSeconds` and `asMinutesAndSeconds` extensions
3. Replace all duration display code with unified extension
4. Centralize input parsing in single module
5. Update setlist display to use canonical format

**Warning signs:**
- Two different duration extensions exist (ending in `Minutes`, `MinutesSeconds`, `MinutesAndSeconds`)
- Test/screen talks about "mm:ss input" and "m s output" as different concepts
- User enters `"11:15"` but sees `"11m 15s"` displayed (format mismatch)
- Converting displayed duration back to seconds requires checking which format it used

**Phase to address:** **Phase 1 (Spec)**

---

### Pitfall 9: Cache Persistence Doesn't Reset When Locale Changes

**What goes wrong:**
User loads Bands in EN, data cached. User switches to RU. Band names/titles are language-neutral, but any *localized* metadata (e.g., "No data fetched yet" or "Last updated August 25") cached in EN stays cached in EN.

If cache stores rendered strings (not raw data), catastrophic. Issue is when provider caches computed value including locale-specific string, user switches locale, provider returns old cached value with EN strings.

**Why it happens:**
- Cache keys are simple strings (`'bands'`), not locale-aware
- Providers don't re-validate cache when locale changes
- Cached data might include UI-rendered strings mixed with raw API data
- No separation between "raw cached data" and "derived locale-aware data"

**How to avoid:**
1. Always cache raw API data, never rendered strings
2. Render locale-aware strings in providers, not cache
3. Include locale in cache invalidation: make providers watch locale
4. Test cache behavior across locale changes

**Warning signs:**
- User switches locale, offline banner text doesn't update
- Cache is hit, so no refetch; user sees old-locale data
- Provider's `build()` computes locale-specific label and never re-computes on change
- Test: cache value in EN, switch locale, read cache → if localized strings in cached value, stale

**Phase to address:** **Phase 1 (Infrastructure)**

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode strings in each screen (no centralized file) | Fast to start | Impossible to audit coverage; duplicated strings | Never |
| Use `toLowerCase().contains()` instead of locale-aware search | Simpler | Fails in Turkish (i → İ); breaks for non-EN users | Only EN-US exclusive |
| Store locale in SharedPreferences, not Riverpod | Smaller footprint | Changes don't propagate reactively; must refetch everywhere | Never — Riverpod already dependency |
| Defer locale persistence (memory-only) | Faster initial implementation | Users re-select language every app open | Only MVP with explicit plan to add before release |
| Parse duration with `int.parse()`, no validation | No extra code | Silent acceptance of "5:60"; user confusion | Never |
| Cache rendered UI strings alongside data | One less compute layer | Stale localized strings on locale change | Never |
| Translate one-off as encountered in UI | No upfront work | Incomplete coverage; 50% untranslated screens late-stage | Only 10-screen prototype |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Locale provider + cached data providers | Cache returns stale EN data after locale switch | Watch locale in all UI-facing providers; keep cache language-neutral |
| Duration input + track detail | Screen renders `asMinutesSeconds`, input uses mm:ss → user sees mismatched formats | Establish single canonical format (mm:ss) |
| Test strings + widget tests | Tests hardcoded `find.text('Band')`, fail after i18n | Pre-populate test-strings constants; set locale explicitly per test |
| Offline cache + locale switch | Cached screen shows old locale until next fetch | Watch locale in every screen's `build()` |
| Duration parsing + validation | User enters "5:60", silently converts to "7:00" | Validate each component before computing total |
| Setlist + track duration displays | Setlist "42m 35s", track "3:45", user can't add | Unify to single format across all screens |
| Pluralization + localization | EN rule (n==1) doesn't work for RU (3 forms) | Build plural system upfront with language-specific rules |
| Theme switch + locale switch | Switching in different places, providers unaware | Make both part of same "app state" provider |

---

## Performance Traps

| Trap | Symptoms | Prevention | Breaks At |
|------|----------|------------|-----------|
| Every screen watches locale independently | Hundreds rebuilds on locale change; UI freezes | Use single locale-watching provider | 50+ screens watching locale independently |
| Parse duration on every keystroke without debouncing | UI lag on fast typing | Debounce 500ms before validation | User types quickly; validation has side effects |
| Load all 2000+ RU strings at startup | Memory bloat | Lazy-load by feature; load active locale only | 50+ screens, 5000+ translatable strings |
| Circular dependency: locale ↔ feature providers | Feature A watches locale → rebuilds Feature B → Feature B re-fetches | One-way: features watch locale, locale doesn't depend on features | Locale depends on other state |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Duration format not shown/hinted | User enters "12:30:45", confused about expectation | Add input hint: "MM:SS (e.g., 5:30)"; use time picker |
| No error message for invalid duration | User submits "5:60", thinks button broken | Show inline error immediately; describe what's wrong |
| Locale switch buried in Profile | User doesn't know how to change language | Quick-access language button in app bar or startup settings |
| Locale persists forever, no reset UI | User sets RU, can't easily switch back to EN | Always show all available languages; make default obvious |
| Duration display "MM:SS" for 60+ minutes | "120:45" is ambiguous (120 min or 2:20?) | For long durations, use "HH:MM:SS" or "XhYmZs" |
| Setlist vs track duration different formats | User can't calculate: 3×"3:45" should be "11:15", but setlist shows "11m 15s" | Unify formats; if different, clarify in UI |

---

## "Looks Done But Isn't" Checklist

- [ ] **i18n strings extracted:** All ~279 test assertions also use translation keys (not hardcoded). Verification: `grep -r "find.text\(" test/ | grep -v "trl\." | wc -l` = 0.

- [ ] **Locale provider wired:** Every screen (~20) watches `localeControllerProvider`. Verification: `grep -r "ref.watch(localeControllerProvider)" lib/features/ | wc -l` ≥ 20.

- [ ] **Duration input validated:** Parser rejects "5:60" and "-5:30". Verification: `expect(() => parseDurationInput('5:60'), throwsFormatException)` passes.

- [ ] **Translations complete:** All keys present in both EN and RU. Verification: Test iterates all locale keys, asserts both have entries.

- [ ] **Offline screens localized:** Offline banner and empty-state messages are localized; cache stores raw JSON only. Verification: Cache contains no rendered strings.

- [ ] **Duration formats unified:** All displays use mm:ss; no "m s" format remains. Verification: `grep -r "asMinutesAndSeconds\|MinutesAndSeconds" lib/ test/` = 0.

- [ ] **Tests parameterized:** Critical paths (login, create track, switch locale) tested with both EN/RU. Verification: 10+ test loops with `for (final locale in [...])`

---

## Recovery Strategies

| Pitfall | Cost | Recovery Steps |
|---------|------|----------------|
| 50+ tests hardcoded on English strings fail | HIGH (2-3 days) | 1. Extract unique hardcoded strings into constants file. 2. Replace each `find.text(...)` with constant reference. 3. Override locale provider in tests. 4. Re-run. |
| Cached EN strings display in RU UI | MEDIUM (4-6 hours) | 1. Add `ref.watch(localeControllerProvider)` to every cached-data screen. 2. Invalidate all data providers on locale change. 3. Re-test tab-switching + locale change. |
| "5:60" data corrupted in storage | HIGH (1-2 days) | 1. Add server-side validation to reject seconds >= 60. 2. Migrate existing bad data (clamp to 59). 3. Fix client parsing. 4. Test end-to-end. |
| Wrong RU pluralization rule ("2 трек" instead of "2 трека") | MEDIUM (2-3 hours) | 1. Correct RU plural rule function. 2. Add test cases (1, 2, 5, 11, 21, 22, ...). 3. Audit all pluralized RU fields. 4. Re-test. |
| Two duration formats still mixed (mm:ss and "m s") | MEDIUM (1 day) | 1. Create unified `DurationFormatting.formatted` extension. 2. Gradually replace old extensions site-by-site. 3. Deprecate with compiler warnings. 4. Delete old code. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Phase | Verification |
|---------|-------|--------------|
| Hardcoded test strings fail | Phase 1 (Spec) | Catalog 279 assertions; create test-strings utility; run 5 tests EN/RU. |
| Locale doesn't propagate to cached screens | Phase 1 (Infrastructure) | Build `localeControllerProvider`; all 20 screens watch it; test tab-switch + locale. |
| Lazy-loaded translations break tests | Phase 1 (Infrastructure) | Pre-load translations synchronously in test `setUpAll()` or override provider. |
| Duration parsing accepts invalid input | Phase 2 (Duration Input) | Implement strict parser + test suite before wiring to UI. |
| RU text overflows fixed-width layouts | Phase 1 (UI Spec) | Audit all fixed widths; convert to flexible; test RU with longest strings. |
| Pluralization rules differ | Phase 1 (Infrastructure) | Define plural-aware system; implement RU 3-form rules; test edge cases. |
| Locale change doesn't update other tabs | Phase 2 (i18n Implementation) | Test tab-switching + locale; all `IndexedStack` screens watch locale. |
| Cached data includes locale strings | Phase 1 (Infrastructure) | Enforce "cache raw data, render in providers" pattern. |
| Duration format inconsistent | Phase 1 (Spec) | Audit existing formats; unify to mm:ss; plan Phase 2 rollout. |
| Cache ignores locale change | Phase 1 (Infrastructure) | Language-neutral cache keys; locale-aware providers watch locale; test across switches. |

---

## Sources

- Flutter i18n: https://flutter.dev/docs/development/accessibility-and-localization/internationalization
- Riverpod patterns: https://riverpod.dev
- Russian pluralization: https://en.wiktionary.org/wiki/Appendix:Slavic_noun_inflections#Russian
- i18n pitfalls: https://phrase.com/blog/articles/common-translation-mistakes/
- Flutter testing: https://flutter.dev/docs/testing/code-debugging#debugging-with-dart-devtools
- Codebase: 279 hardcoded test assertions; Riverpod + Hive cache; split duration formats (track_formatting.dart + setlist_formatting.dart); hardcoded pluralization

---

*Pitfalls research for: i18n (EN/RU) + mm:ss duration input (Flutter)*

*Researched: 2026-08-25*
