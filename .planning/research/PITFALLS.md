# Domain Pitfalls: Metronome, Rename Sweep, API Migration

**Domain:** Flutter/Dart app with Riverpod state, ARB localization, Hive cache, 453 tests  
**Researched:** 2026-08-27  
**Research Confidence:** LOW-MEDIUM (web search + domain patterns from existing codebase)

---

## Critical Pitfalls

These mistakes cause rewrites, missed deadlines, or core feature breakage.

### Pitfall 1: Timer.periodic Drift in Metronome BPM Scheduling

**What goes wrong:** Timer.periodic does not guarantee consistent callback intervals. The time between callbacks is implementation-dependent and can vary by ±10–20ms per beat. At 120 BPM (500ms interval), this 2–4% drift compounds rapidly—after 10 beats, users perceive the metronome as "off."

**Why it happens:** Timer.periodic schedules the next callback based on when the current callback started, ended, or was originally scheduled—no guarantee. Android/iOS system load, GC pauses, and widget rebuild cycles further defer execution. The Dart runtime provides no real-time guarantees.

**Consequences:** 
- Metronome tempo drifts audibly after 20–30 seconds
- User frustration: app doesn't stay in sync with their playing
- Setlist tempo prefilling from track data appears to work but sounds wrong when used
- Negative reviews: "metronome is unreliable"

**Prevention:**
1. **Use Ticker or frame-based scheduling for visual pulse only** — Ticker is synchronized to the Flutter engine's 60 FPS draw cycle and provides minimal visual jitter; reserve Timer.periodic for background state updates, not audio cues
2. **Segregate audio timing from UI timing** — Audio playback should be driven by a separate audio engine (e.g., just_audio, flutter_sound) with hardware clock synchronization, not app-level timers
3. **Plan to add platform-specific audio backend in next iteration** — Standard approach for production metronomes: native code (Kotlin/Swift) or a dedicated audio library handles the hardware timing; Flutter UI layer consumes audio events only
4. **Test with real device under load** — Emulator timing is deceptive; test on actual hardware (phone under Spotify/notifications/other load) before declaring success
5. **Set user expectation in feature scope** — If audio latency <16ms is not achievable this milestone, document "visual metronome only" and defer audio to next phase

**Detection:** 
- Measure callback interval variance: Log consecutive Timer.periodic callback timestamps, compute δt differences. If any |δt - expected| > 50ms, you've hit drift
- Blind listening test: User taps along with metronome for 30 seconds; ask if tempo felt stable. If "no," drift is user-visible
- BPM calculator: Show instantaneous BPM computed from click intervals. If it wavers by >2%, alert developers

**Phase Implication:** Metronome phase must plan 3–5 hours for audio backend exploration if high-precision audio is required; standard Timer.periodic approach will fail user testing.

---

### Pitfall 2: Stale Generated Artifacts After Rename Sweep

**What goes wrong:** After renaming `lib/features/songs/` to `lib/features/tracks/` and updating ARB keys + Riverpod notifier class names, build_runner regenerates `.g.dart` and generated localization files, but old artifacts persist on disk. Tests pass (they import the new generated class), but the old `.g.dart` file from the old notifier name still exists, now dead code. Worse: if IDE autocomplete finds the old class, developer mistakenly imports it; code compiles but runtime provider lookup fails because the name doesn't match.

**Why it happens:** 
- `dart run build_runner build` only generates new files; it does NOT delete old ones
- ARB gen-l10n similarly regenerates `lib/l10n/app_localizations.dart` but leaves old directory names alone if not explicitly cleaned
- Riverpod `.g.dart` file naming is strict (`XNotifier` → `lib/providers/x_notifier.g.dart`); if you rename the notifier but forget to rename the file, build_runner creates a new file alongside the old one
- A 453-test suite won't catch this if tests don't specifically verify provider identity or class name exports

**Consequences:**
- Code compiles but silently uses wrong provider at runtime → state doesn't update, UI stuck
- Merge conflicts become painful: different branches hold old vs new artifact names
- Production build size bloats with dead generated code
- CI can have different state than dev machine: stale artifacts on dev might cause cache to mask the issue

**Prevention:**
1. **Pre-rename cleanup script** — Before starting the rename phase:
   ```bash
   # Find all .g.dart files
   find lib -name "*.g.dart" -type f | head
   # Find all ARB files
   find lib -name "*.arb" -type f | head
   # Document current structure in a checklist
   ```
2. **Rename in controlled order:**
   - Rename Dart file first (e.g., `songs_notifier.dart` → `tracks_notifier.dart`)
   - Rename Riverpod class inside (`SongsNotifier` → `TracksNotifier`)
   - Update `part 'tracks_notifier.g.dart'` line
   - Rename ARB files (e.g., `intl_en.arb` entries: `songs_` → `tracks_`)
   - Rename output class in `l10n.yaml` if custom
   - **Only then** run `dart run build_runner build`
3. **Post-build artifact audit:**
   ```bash
   # After build_runner completes:
   find lib -name "*songs*" -o -name "*song*" | grep -E "\.(dart|arb)$"
   # Should return empty if rename was complete
   ```
4. **Force clean between builds** — In CI and locally:
   ```bash
   flutter clean
   rm -rf pubspec.lock .dart_tool/
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```
5. **Verify provider names at test time** — Add a single integration test that verifies old provider names no longer exist:
   ```dart
   test('no stale songs providers', () {
     // Confirm 'songsNotifier' has been renamed to 'tracksNotifier'
     expect(() => songsNotifier, throwsA(anything)); // should error
   });
   ```

**Detection:**
- `flutter analyze` won't catch dead code if it's not imported
- `grep -r "songs_" lib/` immediately after rename should return zero matches in .dart files (only OK in comments or docs)
- IDE "Find All References" on old class name should yield zero results outside of deleted files
- Run all 453 tests; if any provider-related test passes but setUp used the wrong provider, it's masked

**Phase Implication:** Song→Track rename phase must include a pre-build artifact inventory and post-build verification step; allocate 1 hour for cleanup and testing this specific concern.

---

### Pitfall 3: Test Assertions Break on POST → GET API Migration

**What goes wrong:** Existing tests assert on HTTP request shape: `expect(request.method, equals('POST'))` and `expect(jsonDecode(request.body)['searchQuery'], equals('...')). After migrating `ListUserTracks` and `ListUserSetlists` from POST with JSON body to GET with query parameters, those assertions fail immediately. Worse: if you update the request expectation but forget to update the response mock, the test passes locally (mock doesn't care) but fails in real integration because the server interprets GET + empty body differently than POST + JSON body.

**Why it happens:**
- The Cadence app has 453 tests; several hundred likely mock HTTP requests and assert on method + headers + body
- A POST→GET migration touches 2 endpoints and their call sites, but the cascading test updates span: mock setup (method assertion), request shape validation (body parsing), response expectation setup
- If ApiClient was updated to send GET, but the mock setup still expects POST, tests pass because the mock isn't strict; in real app, server rejects GET without proper query encoding

**Consequences:**
- Tests pass but app crashes in real scenario (server returns 400 or 415 on GET when expecting POST)
- Inconsistent behavior between mock tests and integration tests
- Merge conflicts in test files: some branches still assert POST, others GET
- Security: if query params are logged by server, sensitive data now in URL instead of body

**Prevention:**
1. **Inventory test files that mock the affected endpoints:**
   ```bash
   grep -r "ListUserTracks\|ListUserSetlists" test/
   # Also search for direct http.Client mocks that might assert on these
   grep -r "post\|POST" test/api/ | head -20
   ```
2. **Update request mock setup first:**
   ```dart
   // Old:
   when(mockHttpClient.post(...)).thenAnswer((_) async => Response(...));
   
   // New:
   when(mockHttpClient.get(...)).thenAnswer((_) async => Response(...));
   ```
3. **Validate query param encoding in test:**
   ```dart
   // Capture the request and verify query params are encoded correctly
   verify(mockHttpClient.get(
     argThat((Uri uri) => uri.path == '/api/track/list' && uri.queryParameters['searchQuery'] == 'test'),
   )).called(1);
   ```
4. **Test both endpoints in a single change list** — Avoid splitting POST→GET migration across multiple PRs; if one endpoint's tests pass but the other fails, it's caught in code review
5. **Add integration test for the migration** — Before/after: one test calls the old code path (if available in fixture), one calls new code path. Both should return identical response shape
6. **Query param encoding edge cases** — Test with special characters:
   ```dart
   // Test search with spaces, ampersands, question marks
   const testQueries = [
     'simple query',
     'query & ampersand',
     'query?question',
     'unicode: фраза',
   ];
   ```

**Detection:**
- `flutter test` passes but app crashes on real API call → request was mocked, not validated
- `grep -r "\.post(" test/` then `grep -r "\.get(" test/` to find mismatches
- Code review: if a PR changes ApiClient from `.post()` to `.get()` but test files unchanged, flag it
- CI: run real integration tests against staging server, not mocks only

**Phase Implication:** API migration phase must include a dedicated sub-task: "Update all HTTP mocks to match new POST→GET shape"; allocate 2–3 hours to find and fix all test assertions.

---

## Moderate Pitfalls

### Pitfall 4: Query Parameter Encoding Breaks with Spaces and Special Characters

**What goes wrong:** When building the GET request URI manually by string concatenation (e.g., `'/api/track/list?searchQuery=' + userInput`), special characters like spaces, `&`, `?`, and Unicode aren't percent-encoded. The server receives a malformed URL or interprets it differently: `"query test"` becomes `"query test"` (space breaks parsing), `"rock & roll"` splits into two params. Tests pass with safe ASCII queries but fail in real usage.

**Why it happens:**
- Dart's http package requires proper Uri objects, not plain strings
- Easy mistake: concatenate strings for "simplicity," bypass the Uri builder
- Cadence uses `Uri.https()` elsewhere (e.g., publicapi.yml), so pattern exists but isn't everywhere
- Testing with ASCII-only queries masks the issue

**Consequences:**
- User searches for "reggae & ska" → server gets malformed query → returns no results
- User sees empty list → appears like a bug, not a server issue
- Accidental security issue: if authentication tokens or user IDs end up in query params (from copy-paste mistakes), they're now in URLs, visible in logs

**Prevention:**
1. **Always use Uri builder functions, never string concatenation:**
   ```dart
   // Good:
   final uri = Uri.https('api.example.com', '/api/track/list', {
     'searchQuery': userInput,
     'bandId': bandId.toString(),
   });
   
   // Bad:
   final uri = Uri.parse('https://api.example.com/api/track/list?searchQuery=$userInput');
   ```
2. **Test with real-world queries:**
   ```dart
   const testCases = [
     'simple',
     'with space',
     'special & character',
     'question?mark',
     'фраза', // Russian
     'emoji🎸',
   ];
   ```
3. **Code review checklist:** If a PR adds a GET request, verify the Uri is built with the queryParameters map, not string concat
4. **ApiClient pattern:** Ensure ApiClient.get() method accepts queryParameters map and passes to Uri builder:
   ```dart
   Future<Response> get(String path, {Map<String, String>? queryParameters}) =>
     _client.get(_buildUri(path, queryParameters));
   ```

**Detection:**
- `grep -r "get.*\?" lib/api/` to find potential string-concat URIs
- Unit tests with Unicode/special-char queries should be present
- Analyze requests: enable network logging in dev mode, inspect actual request URLs

---

### Pitfall 5: Battery Drain and Wakelock Misuse in Metronome

**What goes wrong:** Metronome needs the screen to stay on (wakelock) while playing, but forgetting to release the wakelock after stopping causes 5–10% extra battery drain. Alternatively, if you DON'T acquire wakelock on Android, audio stops when screen locks. iOS differs: media playback automatically holds wakelock, but you still need to manage audio session state.

**Why it happens:**
- Wakelock is platform-specific (Android has explicit locks, iOS doesn't); Flutter abstracts this away but it's easy to forget
- Metronome stop event might fire while app is backgrounded or on a different screen → cleanup code doesn't run
- The wakelock_plus package docs aren't prominent about "always release," just "use when needed"

**Consequences:**
- User plays metronome for 30 minutes at a gig, phone drains 20% extra battery due to wakelock staying on
- User navigates away from metronome screen without stopping it → wakelock held indefinitely
- App backgrounding doesn't trigger cleanup → wakelock persists until app is fully closed
- Negative app store reviews: "battery drain when using metronome"

**Prevention:**
1. **Lifecycle-aware wakelock management:**
   ```dart
   // Acquire wakelock only when metronome is actively playing
   void startMetronome() {
     Wakelock.enable();
     // start Timer.periodic or audio playback
   }
   
   void stopMetronome() {
     Wakelock.disable();
     // stop timer
   }
   ```
2. **Guard against forgotten stops:**
   - Metronome auto-stop after 30 minutes of inactivity (user forgot to stop)
   - Stop wakelock + audio on app backgrounding (use WidgetsBindingObserver)
   - Confirm wakelock release in test:
     ```dart
     await metronome.stop();
     expect(Wakelock.enabled, false);
     ```
3. **Platform-specific audio session management** (iOS-specific):
   - Use AVAudioSession to route audio through speaker even when silent switch is on (metronome is intentional sound)
   - Release audio session on stop

**Detection:**
- Battery profiler (iOS Instruments, Android Battery Historian) under metronome load; wakelock should release 1 second after stop
- Check logcat for wakelock state: `adb shell dumpsys power | grep wake`
- Lifecycle test: start metronome, navigate away, return; confirm audio doesn't resume

---

## Minor Pitfalls

### Pitfall 6: Forgetting ARB File Naming Convention After Rename

**What goes wrong:** ARB locale files are named by convention: `app_localizations_en.arb`, `app_localizations_ru.arb`, etc. If you rename the output class in `l10n.yaml` from `AppLocalizations` to `TrackLocalizations`, the gen-l10n tool regenerates the Dart class but not the ARB file names. References in code to the old generated filename break.

**Why it happens:**
- ARB file names are fixed by convention; output-localization-file setting in l10n.yaml only affects the Dart file name, not .arb files
- Renaming the output class doesn't auto-rename the .arb files; they're separate concerns

**Consequences:**
- Test suite expects `AppLocalizations` but gen-l10n now outputs a different class name
- IDE import autocomplete is confused
- gen-l10n regeneration might fail if it can't find the expected .arb files

**Prevention:**
1. **Don't rename the output class unless necessary** — Keep `AppLocalizations` stable
2. **If renaming is needed, update l10n.yaml explicitly:**
   ```yaml
   output-class: TrackLocalizations
   output-localization-file: track_localizations
   ```
3. **Verify gen-l10n succeeds post-rename:**
   ```bash
   dart run flutter_gen:flutter_gen
   # or
   flutter gen-l10n
   ```

---

### Pitfall 7: Riverpod Provider Name Derivation Confusion

**What goes wrong:** Riverpod's code generator derives provider names from notifier class names using a regex (default: remove "Notifier" suffix). A class named `TracksNotifier` becomes `tracksProvider`, not `tracks_provider` or something else. If you rename the class but don't update call sites, the provider name changes silently and existing code breaks at runtime, even though it compiles.

**Why it happens:**
- Riverpod's naming convention is not obvious from the code; you have to look at the generated `.g.dart` file or docs
- IDE refactoring doesn't know about Riverpod codegen rules, so "rename class" doesn't cascade to provider references
- A 453-test suite might not exercise every provider reference

**Consequences:**
- `ref.watch(tracksNotifier)` becomes invalid after renaming `TracksNotifier` to `BandTracksNotifier` (provider now `bandTracksNotifier`)
- Code compiles because Riverpod.g.dart is regenerated, but the provider reference is now wrong
- Runtime error: "Provider bandTracksNotifier not found"

**Prevention:**
1. **After renaming a Riverpod notifier class, manually search for all references to the old provider name:**
   ```bash
   grep -r "tracksNotifier" lib/
   grep -r "TracksNotifier" lib/ test/
   ```
2. **Update call sites:**
   ```dart
   // Old:
   ref.watch(tracksNotifier);
   
   // New (if class renamed to BandTracksNotifier):
   ref.watch(bandTracksNotifier);
   ```
3. **Run full test suite to catch missed references**
4. **Code review: highlight provider name changes** in the PR description so reviewers check for refs

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Metronome Audio** | Timer.periodic jitter causes perceived tempo drift after 20–30 seconds | Use Ticker for UI + separate audio backend; allocate spike time for audio library evaluation |
| **Metronome Wakelock** | Wakelock left on after stop drains battery visibly | Lifecycle-aware acquire/release; WidgetsBindingObserver to clean up on background |
| **Song→Track Rename** | Old .g.dart and .arb files persist after build_runner, causing stale imports and runtime provider mismatches | Pre-build artifact inventory, post-build cleanup audit, force `--delete-conflicting-outputs` |
| **Rename + Test Update** | 453 tests mock HTTP requests; POST→GET migration breaks request assertions in mock setup | Comprehensive test file audit before starting rename; update mocks in same PR as endpoint migration |
| **API Migration: Query Params** | Special characters in searchQuery (spaces, &, ?, Unicode) cause malformed URLs and silent failures | Always use Uri.https() with queryParameters map; test with real-world user inputs |
| **API Migration: Mocks** | Tests pass with mocks but fail in real API calls because mock doesn't enforce request shape | Add integration tests against real API or strict mock validators (e.g., verify exact query param presence) |

## Recommended Research by Phase

- **Metronome Phase:** Spike on Flutter audio libraries (just_audio, flutter_sound, flutter_pcm_sound) to evaluate latency + battery overhead before committing to Timer.periodic
- **Rename Phase:** Document all generated-code locations (ARB, .g.dart Riverpod files, localization class names) as a pre-flight checklist
- **API Migration Phase:** Run all 453 tests with verbose request logging enabled; grep output for unexpected POST/GET method mismatches

---

## Confidence Assessment

| Finding | Confidence | Notes |
|---------|------------|-------|
| Timer.periodic drift | MEDIUM | Well-documented in Flutter docs; observation about ±10–20ms variance is domain standard, not edge case |
| Metronome audio latency requirement | MEDIUM | 16ms threshold from audio engineering; specific to low-latency audio perception, not Flutter-specific |
| ARB gen-l10n file regeneration | MEDIUM | Based on Cadence's existing ARB pipeline (PROJECT.md notes ARB/gen-l10n established in v1.2 Phase 12–14) and Dart gen-l10n documentation |
| Riverpod codegen naming | MEDIUM | Riverpod docs confirm regex-based provider name derivation; example from pub.dev/packages/riverpod |
| Query param encoding pitfalls | MEDIUM | Dart Uri class docs confirm auto-encoding with queryParameters map; special-char issues from standard URL encoding practices |
| POST→GET test breakage | HIGH | Based on Cadence's existing test patterns (453 tests, mock HTTP setup) and the specific migration described in PROJECT.md (ListUserTracks/ListUserSetlists POST→GET) |
| Wakelock battery drain | LOW | Wakelock general best practices are documented; specific to Android; Flutter-specific impact not validated |

---

## Out of Scope (for future research)

- **Real-time audio playback from audio files** — API has no audio field; deferred pending backend support
- **Offline metronome sync across band members** — Requires real-time collaboration; out of v1 scope
- **Accessibility for metronome under ≥200% font scaling** — Known outstanding item (PROJECT.md); separate accessibility phase
