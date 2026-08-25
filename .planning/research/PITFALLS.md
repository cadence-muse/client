# Pitfalls Research: i18n Localization & Duration Input

**Domain:** Flutter mobile app with 401 tests, Riverpod state management, Hive-backed offline cache, zero existing i18n
**Researched:** 2026-08-25
**Confidence:** HIGH (based on mature codebase patterns: ~24,800 LOC, established Riverpod architecture, Hive cache layer, 401 existing tests, no prior i18n implementation)

---

## Critical Pitfalls

### Pitfall 1: Widget Tests Hardcoded to English Strings Break When i18n Is Added

**What goes wrong:**
With 401 tests in the codebase, many use `find.text('Login')`, `find.text('Add Track')`, `find.text('No tracks available')` and other hardcoded English strings. When localization is added and strings are extracted to translation files, these tests fail immediately — they can't find the localized Russian text. Test suite turns red before any feature work is validated.

**Why it happens:**
The codebase was written with no i18n from the start, so all tests were written against hardcoded English. When i18n is introduced *after* the test suite is established, every string-matching assertion must either be updated or the test infrastructure must change. Developers often underestimate scope: "it's just string extraction, tests should still pass" — until they hit 100+ failing tests that all read `find.text('...')`.

**How to avoid:**
- **Before** extracting any strings, migrate high-impact widget tests from string-matching to semantic finders:
  - Replace `find.text('Login')` → `find.byType(LoginButton)` or `find.byIcon(Icons.login)` if a distinctive widget type/icon exists
  - Use `find.byKey(ValueKey('band_name_field'))` for input fields with keys
  - Use `find.byType(ElevatedButton)` for buttons matched by type, not label
- Create a helper function `findLocalizedText(context, 'translation_key')` that resolves the i18n key at test time, eliminating hardcoded English expectations
- **Start this migration before extracting strings** — it's a testing infrastructure change that unblocks the rest of i18n work
- Run `grep -r "find.text\(" test/` to catalog hardcoded assertions before starting; you'll have 50+ hits to address

**Warning signs:**
- Running tests before string extraction shows 30%+ failure rate (indicates high string-match density)
- Test failures are all "flutter/test text not found" errors, not logic errors
- Developer reports "have to rewrite half the tests" during i18n implementation
- New screens added after i18n shows no test coverage because tests were written for hardcoded strings

**Phase to address:**
Must be addressed **upfront in Phase 1 (i18n Infrastructure)** alongside string extraction. Do not extract strings without migrating tests first. This is testing architecture work, not a later verification step.

---

### Pitfall 2: Locale Change Not Propagating to Out-of-View Screens (IndexedStack Tabs)

**What goes wrong:**
User is viewing Bands tab (index 2). They switch to Profile tab (index 3), change locale from English to Russian, and return to Bands. The Bands tab is still mounted in the IndexedStack (not rebuilt while out of view), so localized strings don't update. User sees mixed-language UI: Profile is Russian, Bands is still English.

**Why it happens:**
Flutter's `IndexedStack` keeps all children mounted but only renders the active index. A Riverpod provider watching locale will update its state, but out-of-view children don't rebuild automatically. The Bands screen must explicitly `ref.watch(localeProvider)` in its `build()` method to trigger a rebuild. If it only watches data providers, it never rebuilds when locale changes.

**How to avoid:**
- Define a single top-level `localeProvider` (e.g., `StateNotifierProvider<LocaleNotifier, Locale>`) that all screens watch
- **Every screen that renders any localized string must explicitly call `ref.watch(localeProvider)`** in its `build()` method to trigger rebuild on locale change
- Apply locale at the root MaterialApp level so the entire app locale changes reactively:
  ```dart
  final appLocale = ref.watch(localeProvider);
  return MaterialApp(locale: appLocale, ...);
  ```
- Test locale switching with the full app running (not isolated widgets). Use the real MaterialApp structure
- Create an automated test: open tab A, go to Profile, switch locale, return to tab A → verify UI strings update

**Warning signs:**
- Manual testing: switch language in Profile, notice one tab updated but another tab still shows English
- Cached screens don't rebuild when locale changes (only a full app restart fixes it)
- Riverpod DevTools shows locale provider state changed but consumer screen's `build()` wasn't called
- Post-implement: "language switch works in Profile but not in Bands"

**Phase to address:**
Phase 1 (i18n Infrastructure). The locale provider architecture must be correct before any screen is wired. Design the pattern upfront and verify with integration tests.

---

### Pitfall 3: Widget Test Harness Missing MaterialLocalizations Causes "No Localization Found" Crashes

**What goes wrong:**
A widget test that works fine with hardcoded English strings crashes when i18n is added. Error: `MissingPluginException` or "No MaterialLocalizations found". The test renders a widget that calls `Localizations.of<AppLocalizations>(context)` or uses generated `.arb()` getters, but the test harness doesn't include a full MaterialApp with localization setup.

**Why it happens:**
Localized widgets call `Localizations.of<AppLocalizations>(context)` or use generated `.arb` helper methods that depend on Flutter's MaterialLocalizations. Widget tests often skip MaterialApp to minimize boilerplate. Tests that worked fine with hardcoded strings (no i18n calls) suddenly fail because the widget tree is incomplete.

**How to avoid:**
- Create a test helper `TestLocalizations.buildTestApp(Widget child)` that wraps any widget in a full MaterialApp with locale provider and translations pre-loaded
- Every widget test using localized strings must use this helper instead of bare `pumpWidget()`
- Pre-load translations synchronously in test `setUpAll()` before any test runs, not asynchronously during test execution
- Consider creating a test-only `AppLocalizationsTest` mock that hardcodes test English strings (faster than loading real translation files)
- Verify test setup: before any test renders the widget, assert that `Localizations.of<AppLocalizations>(context)` returns non-null

**Warning signs:**
- Widget tests pass locally but fail in CI after i18n is added
- Tests render the widget but crash on first localization lookup with "MissingPluginException"
- A new test sometimes passes on first run but fails on re-run (initialization race condition)
- Developer reports: "test passed yesterday, now MaterialLocalizations is not found"

**Phase to address:**
Phase 1 (i18n Infrastructure), concurrent with test migration. Test infrastructure must be updated alongside string extraction.

---

### Pitfall 4: Offline Cache Displays Stale Language After Locale Switch

**What goes wrong:**
App is online, user views Tracks list in English, cache is populated. User switches locale to Russian in Profile settings. User opens another screen (e.g., Bands). Both Tracks and Bands screens fetch from cache (network is available but cache hit is faster). Bands shows Russian labels but Tracks still shows English. The cached data itself is language-neutral JSON, but the provider didn't re-compute UI strings when locale changed.

**Why it happens:**
Hive cache stores raw API data (Track objects with `durationSeconds: int`, band names as strings). The cache is language-neutral. But the provider that reads from cache and renders it might compute locale-specific strings (e.g., "No tracks", "Last updated", error messages) and cache that computed value. On locale change, the provider doesn't rebuild if it doesn't watch the locale provider.

**How to avoid:**
- **Never cache formatted/localized strings** — always cache raw API data (JSON/objects with native types)
- Create a `formatDuration(int seconds, Locale locale)` helper that converts at render time, never stores formatted strings
- Every provider that computes UI strings (error messages, status text, formatted duration) must `ref.watch(localeProvider)` to trigger rebuild on locale change
- Keep the pattern: raw data in cache (Hive) → providers compute UI from cache + locale → screens render from providers
- Test: cache data in English, switch locale to Russian, verify UI updates without a new network fetch

**Warning signs:**
- Cache contains formatted strings like `"duration": "3:45"` instead of raw `"durationSeconds": 225`
- User switches locale, offline banner text doesn't update (offline banner provider didn't watch locale)
- App crashes or displays wrong duration after cache reload
- Developer comment: "why is this localized string stored in the cache?"

**Phase to address:**
Phase 1 (i18n Infrastructure) and Phase 2 (duration input). Clarify the data model upfront: `durationSeconds` is always raw int from API, formatting happens at render time.

---

### Pitfall 5: Duration Input Parsing Accepts Invalid Formats ("5:60", "-1:30", Empty Input)

**What goes wrong:**
User enters `"5:60"` (5 minutes, 60 seconds — invalid). Input validator doesn't reject it. App silently rounds/clamps to `"6:00"` (360 seconds) or the backend silently accepts 360 seconds. User intended "5 minutes" but the track was created with 360 seconds. Or user enters `":"` (empty parts), app crashes with "Invalid argument" from `int.parse('')`, exception is silently caught.

**Why it happens:**
Duration parsing with `int.parse()` and basic split logic is lenient. `int.parse('-5')` succeeds. No explicit component validation (seconds must be 0-59). No regex or state machine to enforce format. Exception handling that catches all errors masks the real problem. Developers often rely on "it probably won't happen" instead of explicit validation.

**How to avoid:**
- **Implement strict validation before computing total seconds**:
  1. Validate format: exactly 2 parts split by `:`
  2. Validate both parts parse as integers (not empty, not `"abc"`)
  3. Validate minutes >= 0 and seconds >= 0 (reject negative)
  4. Validate seconds < 60 (critical: reject "5:60")
  5. Optionally cap minutes at sensible max (e.g., 999 for tracks, 300 for setlists)
- Add comprehensive test cases for edge cases: `""`, `":"`, `"0:0"`, `"5:60"`, `"abc:def"`, `"-1:00"`, `"999:30"`, paste operations
- Provide clear error messages to user: "Seconds must be 0-59 (you entered 60)" instead of silent rounding
- Consider a `TextInputFormatter` for real-time validation as user types, providing immediate feedback

**Warning signs:**
- Manual testing: entering "5:60" either gets accepted or silently converts to "6:00" (user confusion)
- Test data has tracks with weird durations that don't match what the user entered
- User report: "I entered the duration wrong but the app saved it anyway"
- Backend logs show durations like 360 (multiple of 60) that don't align with user input

**Phase to address:**
Phase 2 (duration input). Input validation must be bulletproof before the feature ships. Implement and test thoroughly before wiring to the UI.

---

### Pitfall 6: Russian Text Overflows Fixed-Width Layouts Without Ellipsis or Wrapping

**What goes wrong:**
A badge label reads "Add Track" (9 characters) in English. In Russian: "Добавить трек" (13 characters with space). The badge container is sized for English text with `SizedBox(width: 150)`. Russian text overflows, truncates to "Добавить т", or shifts the layout. Form field label "Invite Code" (11 chars EN) → "Код приглашения" (15 chars RU with space), overflows a fixed-width label area.

**Why it happens:**
Flutter layouts were built and tested with English text only. Russian words are typically 20-30% longer (some much longer). Fixed-width containers (`SizedBox`, `ConstrainedBox` with static width) have limited space. Developers tested the UI with English, it looked fine, so they shipped it. When i18n is added and tested with Russian, text overflows.

**How to avoid:**
- **Never use `SizedBox` for text-containing widgets** — use `Expanded`, `Flexible`, or `Constraints` to allow dynamic width
- Use `maxLines: 1` and `overflow: TextOverflow.ellipsis` for labels where truncation is acceptable:
  ```dart
  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
  ```
- Test layouts in **both English and Russian** during development, not just English
- Add a design-time check: measure longest expected string in each language; ensure container width accommodates both
- For navigation bars, buttons, badges: test with Russian locale and actual Russian strings, not just Lorem Ipsum

**Warning signs:**
- Manual testing in Russian: text overflows buttons, form labels truncate, bottom nav text is cut off
- Widget has `overflow: TextOverflow.fade` or `overflow: TextOverflow.clip` (actively hiding text)
- Layout shifts or jank appears when switching language
- QA finds misaligned text, truncated labels in Russian mode

**Phase to address:**
Phase 3-4 (screen implementation and QA). Each screen with localized text should be visually tested in both EN and RU. This is a design-time check, not a code-time one.

---

### Pitfall 7: Known API Error Code Mapping Incomplete — Unmapped Codes Show Raw English Server Text

**What goes wrong:**
API returns error `{"code": "band_not_found", "message": "Band with ID 123 not found"}`. The spec says: "map known API codes to localized messages; unmapped codes fall back to raw server text". The mapping has an entry for `band_not_found` → localized "Группа не найдена" (Russian). But a new error code is added (e.g., `track_duration_invalid`), the client doesn't have a translation, and user sees raw server text: "Track duration must be between 0 and 3600" (English only, not localized). UX is inconsistent: some errors localized, some raw English.

**Why it happens:**
The mapping between API error codes and localized messages is manual and maintained separately from backend code generation. When a new error code is added to the backend, the frontend mapping isn't automatically updated. Without a systematic process, error translations lag behind error code additions. The fallback to raw server text masks the incomplete mapping until users complain.

**How to avoid:**
- Maintain a **canonical list of all known API error codes** in `lib/api/publicapi.yml` or a dedicated `error_codes.yaml`
- Create an `ErrorCodeMapper` class that maps codes to localized messages:
  ```dart
  String mapErrorCode(String code, AppLocalizations i18n) {
    switch (code) {
      case 'band_not_found': return i18n.errorBandNotFound;
      case 'track_deleted': return i18n.errorTrackDeleted;
      case 'track_duration_invalid': return i18n.errorDurationInvalid;
      default: return i18n.errorUnknown; // Generic fallback (localized)
    }
  }
  ```
- **Require every error code to have an entry in both EN and RU i18n files** — verify this at build time or with a test
- In production, always show a localized fallback message (e.g., "An error occurred") instead of raw server text
- Log unmapped error codes as warnings in development to catch new codes during testing

**Warning signs:**
- Mix of localized and raw-English error messages in the UI depending on which endpoint errors
- Developer adds a new API error code but forgets to add an i18n translation
- QA report: "Error message is in English even though app is in Russian mode"
- Backend team changes an error message; frontend doesn't know about it

**Phase to address:**
Phase 1 (i18n Infrastructure) alongside string extraction. Design the error mapping architecture upfront as part of the i18n onboarding.

---

### Pitfall 8: Riverpod Providers Don't Auto-Invalidate on Locale Change (Missing `ref.watch`)

**What goes wrong:**
App has a provider that formats track durations:
```dart
final formattedTracksProvider = Provider((ref) {
  final tracks = ref.watch(tracksProvider);
  return tracks.map((t) => formatDuration(t.durationSeconds)).toList();
  // NO ref.watch(localeProvider) — missing dependency!
});
```
User switches locale. The `localeProvider` updates. But `formattedTracksProvider` doesn't rebuild because it doesn't watch `localeProvider`. Duration display stays in the old format. If the format ever becomes locale-aware (e.g., some language uses "," as separator instead of ":"), the UI won't update.

**Why it happens:**
Riverpod is lazy and only rebuilds providers when their declared dependencies change. If a provider produces locale-dependent output but doesn't `ref.watch(localeProvider)`, Riverpod has no reason to rebuild it. This is correct behavior — it's the provider's responsibility to declare all dependencies. But developers often forget to add the locale watch.

**How to avoid:**
- **Any provider that produces locale-dependent output must `ref.watch(localeProvider)`**:
  ```dart
  final formattedTracksProvider = Provider((ref) {
    final locale = ref.watch(localeProvider); // Declare dependency
    final tracks = ref.watch(tracksProvider);
    return tracks.map((t) => formatDuration(t.durationSeconds, locale)).toList();
  });
  ```
- Similarly, any error-mapping provider must watch `localeProvider`:
  ```dart
  final errorMessageProvider = Provider((ref) {
    final locale = ref.watch(localeProvider);
    final errorCode = ref.watch(lastErrorProvider);
    return mapErrorToLocalizedMessage(errorCode, locale);
  });
  ```
- Use Riverpod DevTools to verify that dependent providers rebuild when locale changes
- Add code review checks: "Does this provider output locale-dependent data? If yes, does it `ref.watch(localeProvider)`?"
- Test in Riverpod DevTools: toggle locale provider, verify all consumers rebuild

**Warning signs:**
- Manual testing: switch language, duration format doesn't change on screen
- Riverpod DevTools shows locale provider state changed but consumer didn't rebuild
- Error messages stay in old language after locale switch
- Provider returns cached value without re-computing when locale changes

**Phase to address:**
Phase 1 (i18n Infrastructure). Every locale-dependent provider should declare this dependency upfront. A code review pass during Phase 1 should verify all providers.

---

### Pitfall 9: Duration Display vs. Duration Input Format Mismatch

**What goes wrong:**
Track list displays duration as "3:45" (mm:ss format). But duration input field accepts "3:45" and converts to 225 seconds. The API returns `durationSeconds: 225`. On edit, the input field displays `"3:45"` correctly. But somewhere in the code, a different provider displays durations as "3m 45s" (minutes+seconds with text). User sees inconsistent formats: "3:45" on one screen, "3m 45s" on another. Confusion: are they the same duration or different?

**Why it happens:**
Duration display/format code is scattered across multiple files without a unified approach. One developer uses `asMinutesSeconds` extension, another uses `MinutesAndSeconds` suffix, a third formats manually. When duration *input* is added, the developer assumes one format (mm:ss) but discovers other parts of the codebase use a different format.

**How to avoid:**
- **Establish one canonical duration display format for the entire app before adding input** — decide: mm:ss or "m s" or "HH:MM:SS"
- Audit all existing duration formatting: grep for `asMinutesSeconds`, `MinutesAndSeconds`, `formatDuration`, etc. — consolidate into one
- Create a single `DurationFormatting` extension:
  ```dart
  extension DurationFormatting on int {
    String toDisplayString() => '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
  }
  ```
- Replace all other duration display code with this extension; deprecate old formatters
- Test: verify all screens display duration with the same format

**Warning signs:**
- Two or more duration formatting functions exist with similar names
- Test or screen talks about "mm:ss input" and "m s output" as different concepts
- User enters "5:30", sees "5:30" in edit form, but "5m 30s" in the list (format mismatch)
- Grep finds multiple duration formatting patterns: `minutes:seconds`, `${m}m ${s}s`, manual string concatenation

**Phase to address:**
Phase 1 (spec/infrastructure), before duration input is implemented. Format must be unified to avoid confusion.

---

### Pitfall 10: Locale Preference Not Persisted or Lost on App Restart

**What goes wrong:**
User switches locale from English to Russian in Profile settings. App updates the locale provider. UI updates (good). User closes the app. Next time they open it, app starts in English (default). Locale preference was not saved to persistent storage. User has to switch to Russian again.

Or worse: app saves locale to `SharedPreferences`, but the read-on-startup happens after UI builds, so app briefly shows English before switching to Russian (flash of wrong language). Or startup read fails silently (SharedPreferences unavailable), app uses default, user's preference is lost.

**Why it happens:**
Persistence requires two operations: write when user changes locale, read when app starts. Multiple points of failure:
1. Write: locale change updates the provider but doesn't persist
2. Read on startup: app doesn't read preference before building UI
3. Default: if preference is missing or read fails, what's the default?
4. Testing: mocks of SharedPreferences don't include the locale entry

**How to avoid:**
- Store locale in a `FutureProvider` that reads from `SharedPreferences` on startup:
  ```dart
  final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_locale');
    return Locale(saved ?? 'en'); // Default EN if missing
  });
  ```
- In `main()` or `CadenceApp`, **await the locale future before building MaterialApp** so UI is built with correct locale (no flash)
- When user changes locale, update **both** provider state and persist:
  ```dart
  future(() => notifier.state = Locale('ru'))
  await SharedPreferences.getInstance().then((p) => p.setString('app_locale', 'ru'));
  ```
- In tests, mock `SharedPreferences` to include the locale entry from the start; don't rely on default
- Add an integration test: set locale to Russian, close app and restart (via simulator or test framework), verify it loads in Russian

**Warning signs:**
- App starts in English even though user set it to Russian yesterday
- Test passes with mocked locale provider but fails when real SharedPreferences is used
- Locale reverts to English after app restart
- "Why did the user's language setting get lost?"

**Phase to address:**
Phase 1 (i18n Infrastructure). Persistence must be correct before the locale switch feature ships. Integration tests should verify cold-start behavior.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store formatted duration string in Hive cache | Saves conversion at display time | Cache becomes coupled to UI format; locale changes break cache; migrations needed if format changes; requires cache invalidation | Never — always cache raw data |
| Hardcode error messages in API response handler | Faster implementation, no mapper class needed | Error message logic scattered; localization impossible; adding new codes requires code change + deploy | Never — centralize error handling |
| Skip widget test migration, test only with hardcoded English | Fast migration to i18n, tests still pass temporarily | 50% of test suite becomes fragile; tests hardcoded to English language; future language additions break tests again | Never — migrate tests upfront |
| Fall back silently to English if i18n key not found | Doesn't crash, UI renders something | Silent failures hard to debug; missing translations go unnoticed until user reports; inconsistent error UX | Acceptable in beta/early prototype only; must add logging/warnings |
| Use fixed-width containers, "fix Russian overflow later" | Layout looks perfect in English, fast to code | Russian text overflows; mobile UX breaks; hard to fix later; QA finds it after merge | Never — use flexible widths from the start |
| Don't test with both EN and RU during development | Faster dev iteration | Most i18n bugs discovered too late; complex layouts break with RU; shipped with half-localized UI | Never — test both locales from Phase 1 |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| **Riverpod + i18n** | Providers don't watch localeProvider; locale changes don't propagate to consumers | Every locale-dependent provider must `ref.watch(localeProvider)`. Test with locale overrides in widget tests. Use Riverpod DevTools to verify rebuilds. |
| **Hive cache + duration display** | Format duration once in cache, retrieve pre-formatted | Always cache raw `durationSeconds: int`. Format at render time. Locale changes don't require cache invalidation. |
| **API error codes + i18n** | Error codes documented in backend but not in frontend i18n files; unmapped codes fall back to raw English | Maintain synchronized canonical list of error codes. Map every code. Log/warn on unmapped codes in dev. Test error UX in both EN and RU. |
| **Widget tests + i18n** | Tests find strings by English text; fail when i18n is added | Migrate tests to semantic finders (by type, key, icon) before extracting strings. Create test helper wrapping widgets in full MaterialApp with locale override. |
| **Duration validation + display** | Input validator allows invalid mm:ss (e.g., "5:60"), display silently rounds | Input validator must reject invalid seconds (>59). Display formatter never clamps — that's data corruption. Validation and formatting are separate. |
| **Locale persistence + startup** | App reads locale preference after UI is built; default used instead | Read locale in main() before MaterialApp. Await the Future. Default to EN if missing. Mock SharedPreferences in tests with locale entry. |
| **IndexedStack + locale switch** | Out-of-view screens don't rebuild on locale change | All screens must `ref.watch(localeProvider)`. Test tab-switching with locale change; verify all tabs update. |
| **Duration input + paste operations** | User pastes "60" (raw seconds), app interprets as "60:00" (60 minutes) | Detect raw seconds (no ":"), auto-format to "1:00". Or provide clear error: "Use MM:SS format". Test paste operations. |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| **Locale-dependent provider rebuilds entire app** | UI frame drops when locale changes; jank visible to user | Mark unaffected providers with `.select()`. Only MaterialApp and screens using localized text rebuild. | 1000+ widgets with localized text; every locale change cascades; low-end mobile at 60fps |
| **Duration format conversion in tight loop** | List of 500 tracks: each frame calls formatDuration() for same track; mobile lag | Memoize formatted strings in provider cache or store computed value. Avoid repeated formatting in list item builders. | Setlist with 100+ tracks; low-end device; duration displayed on every item |
| **Hive cache reads on every build** | Every screen rebuild re-reads Hive (I/O bound); storage is slow | Cache data in Riverpod provider; Hive read once at startup, provider manages in-memory state. | Offline mode with frequent screen switches; slow storage device |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|-----------|
| **API error messages exposed verbatim to user** | Server leaks internal details (DB IDs, stack traces, internal logic) in error text visible to user | Always map API error codes to generic localized messages. Never expose raw server error text. Log raw errors server-side or telemetry, not UI. Test with sensitive error responses. |
| **Localized error messages reveal too much** | Error messages like "email already registered" in all languages allow attackers to brute-force email lists | Use generic "Invalid username or password" or "This email is not available". Same message in all languages. Test error messages are identical. |
| **Duration validation allows negative durations** | Negative durations stored in database; unexpected behavior in calculations (e.g., remaining time = total - played) | Validate duration >= 0. Reject negative input. Test edge cases: "-1:00", "0:00" (valid). |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| **Language switch requires app restart** | User changes to Russian, screen still English. User thinks feature is broken. User force-closes and restarts. | Implement live locale switching. All screens rebuild instantly. Verify in UX testing. |
| **Duration field doesn't guide input format** | User enters "300" (raw) or "5" (ambiguous). App rejects silently or accepts wrong value. User doesn't know format. | Placeholder: "MM:SS". Error message: "Use format MM:SS (e.g., 5:30)". Inline hint or help text. |
| **Error messages mix languages** | User in Russian mode sees mix of English and Russian (half mapped, half raw). Inconsistent UX. | All error text from single source (error mapper). All localized. Never expose raw server text. Test both EN and RU paths. |
| **Truncated Russian text in buttons** | Button shows "Доб…" instead of "Добавить трек". User can't read the action. | Flexible widths. Test with longest text in all languages. Tooltip or adjacent label if space tight. |
| **Duration display ambiguous for long tracks** | 120-minute track displays "120:00". Ambiguous: is that 120 minutes or 12:00? | For durations >= 60 min, use "2h 0m" or "2:00:00" (HH:MM:SS). Test with realistic setlist durations. |
| **No undo after language switch** | User switches to Russian, all UI changes. Can't quickly switch back without restarting. | Always show language selector visible (quick-access button or Profile). Make toggle obvious. |

---

## "Looks Done But Isn't" Checklist

- [ ] **i18n infrastructure:** Locale provider built and tested; persists to SharedPreferences; app loads correct locale on startup.
- [ ] **String extraction:** All hardcoded English strings moved to i18n files. Grep for `Text('...')` (not `Text(i18n...)`) returns zero matches.
- [ ] **Translation completeness:** Both EN and RU translation files are 100% complete. No empty keys. All error codes mapped.
- [ ] **Widget test migration:** Tests updated to semantic finders (`find.byType`, `find.byKey`). 90%+ tests pass with i18n. No tests find.text hardcoded strings.
- [ ] **Locale switching verified:** Manual test: switch language from Profile, verify all screens update instantly (Home, Songs, Bands, Setlists, Profile). No mixed-language UI.
- [ ] **Error message coverage:** All known API error codes documented and have EN + RU translations. Unmapped codes log warning in dev.
- [ ] **Duration input validation:** Edge cases tested: "", ":", "5:60", "abc:def", "-1:00", "999:59", paste "60", paste "1:00". All invalid inputs rejected with user-friendly error.
- [ ] **Duration display format:** Cached data stores raw `durationSeconds: int`. Display converts to "MM:SS" at render time. Locale switch doesn't affect format (format is universal).
- [ ] **Text overflow prevention:** Layout tested in Russian. All labels use flexible widths or `overflow: TextOverflow.ellipsis`. No text clips. No layout jank on language switch.
- [ ] **Offline + locale interaction:** User offline in EN, comes back online, switches to RU. Offline cache still renders correctly with new locale. No format mismatch.
- [ ] **Riverpod provider watch chains:** Any provider producing locale-dependent output watches `localeProvider`. Verified with Riverpod DevTools: locale change triggers rebuilds.
- [ ] **SharedPreferences persistence:** Locale preference saved and loaded. Survives app restart. Defaults to EN if missing. Mocked in tests.
- [ ] **Cold start test:** Integrate test: set locale to RU, close and reopen app, verify it loads in RU (not EN default). Repeat with EN.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| **50+ widget tests fail due to hardcoded English** | HIGH (1-2 days) | 1. Extract unique hardcoded strings into test constants file. 2. Replace each `find.text(...)` with semantic finder. 3. Override locale provider in tests. 4. Re-run. |
| **Screens not updating when locale changes** | MEDIUM (2-4 hours) | 1. Add `ref.watch(localeProvider)` to all affected screens. 2. Verify with Riverpod DevTools. 3. Test locale switching end-to-end. |
| **Russian text overflows in production** | HIGH (1+ days) | 1. Identify all affected screens. 2. Change layouts to flexible widths. 3. Add `maxLines` + `overflow: TextOverflow.ellipsis`. 4. Re-test in RU. Possible layout redesign. |
| **Unmapped API error codes show raw English** | MEDIUM (4-6 hours) | 1. Audit all error codes from backend. 2. Add missing ones to i18n files (EN + RU). 3. Update error mapper. 4. Add logging for unmapped codes. 5. Test error UX in both locales. |
| **Duration validation accepts "5:60"** | MEDIUM (2-3 hours) | 1. Implement strict validation (seconds 0-59). 2. Add clear error messages. 3. Update tests to cover edge cases. 4. Add integration test for invalid input. |
| **Locale preference lost on app restart** | MEDIUM (3-4 hours) | 1. Verify SharedPreferences read/write. 2. Add integration test for cold start. 3. Debug persistence flow. 4. Check for mock issues in tests. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Widget tests fail due to hardcoded English | Phase 1 (i18n Infrastructure) | Run full test suite with both EN and RU. 95%+ tests pass. No `find.text()` hardcoded strings. |
| Locale change doesn't propagate to screens | Phase 1 (i18n Infrastructure) + Phase 3-4 (screen implementation) | Manual test: switch language, all open screens update instantly. Riverpod DevTools shows all consumers rebuild. |
| Widget tests crash due to missing MaterialLocalizations | Phase 1 (i18n Infrastructure) | Widget tests use test helper. All tests wrap with `TestLocalizations.buildTestApp()`. Tests pass in isolation and suite. |
| Offline cache displays wrong locale | Phase 1 (i18n Infrastructure) + Phase 2 (duration input) | Cached data stores raw `durationSeconds: int`. Display format applied at render time. Offline works in both EN and RU. |
| Duration input accepts invalid formats | Phase 2 (duration input) | Input validation tests cover: "", ":", "5:60", "abc:def", "-1:00", "999:59", paste. All invalid rejected with user-friendly error. |
| API error codes unmapped or inconsistent | Phase 1 (i18n Infrastructure) | All known error codes mapped to EN + RU. Error message UX audited. No raw server text visible. |
| Russian text overflows in production | Phase 3-4 (screen implementation + QA) | Every screen with localized text visually tested in Russian. All labels use flexible widths. No overflow, no truncation. |
| Locale persistence broken | Phase 1 (i18n Infrastructure) | Integration test: set to RU, close/reopen, verify loads in RU. SharedPreferences mocked with locale entry in unit tests. |
| Riverpod providers don't watch locale | Phase 1 (i18n Infrastructure) + Phase 3-4 (screen implementation) | Code review: every locale-dependent provider has `ref.watch(localeProvider)`. Riverpod DevTools verifies rebuilds. Provider tests include overrides. |
| Duration parsing silently rounds or accepts invalid | Phase 2 (duration input) | Comprehensive input tests: valid (0:00-999:59), invalid (seconds >59), edge cases. All handled gracefully with errors. |

---

## Sources

- Flutter internationalization patterns: official Flutter i18n docs, MaterialLocalizations behavior
- Riverpod state management: dependency tracking, lazy evaluation, provider rebuilds
- Russian language: pluralization rules (3 forms), text length, Cyrillic rendering
- Hive NoSQL: nested collection handling, type conversion, persistence patterns
- Text input validation: TextInputFormatter, RegExp, edge cases (paste, delete, empty)
- Common pitfalls from mature Flutter apps (400+ test suites) adding i18n post-MVP
- flutter_secure_storage and SharedPreferences persistence patterns

---

*Pitfalls research for: i18n localization (EN/RU with live switching, no restart) + mm:ss duration input*
*Researched: 2026-08-25*
*Status: Research complete, ready for phase planning*
