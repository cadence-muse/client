---
phase: 18-metronome-tool
plan: 01
subsystem: metronome
tags: [flutter, riverpod, audioplayers, timing, testing]

requires: []
provides:
  - "MetronomeAudioService + TickSoundPlayer: audioplayers-backed tick playback with graceful degradation on asset-load failure"
  - "MetronomeState Riverpod family provider: Stopwatch/Timer beat scheduler, BPM clamp choke point, immediate tempo-change application, app-lifecycle-driven auto-pause"
  - "BeatIndicator 4-dot visual pulse widget"
  - "MetronomeScreen (loading/error/data states, plain BPM text stub for Plan 18-02's dial)"
  - "Homepage 'Tools' section entry point (METR-01) and Track Detail conditional entry point (METR-02/D-11)"
  - "Placeholder tick WAV assets at assets/audio/metronome_{accent,regular}.wav"
affects: [18-02]

actuals:
  tokens: 15271
  tasks: 3
  commits: 4

tech-stack:
  added: [audioplayers ^5.2.0, clock ^1.1.2, audioplayers_platform_interface (dev), file (dev)]
  patterns:
    - "TickSoundPlayer abstract interface + AudioPlayersTickSoundPlayer concrete impl, enabling FakeTickSoundPlayer test doubles with zero real platform-channel dependency"
    - "clock.stopwatch() (package:clock) instead of a bare Stopwatch() for all elapsed-time-driven scheduling loops -- identical in production, but swappable for flutter_test's fake pump-driven clock"
    - "AppLifecycleListener registered inside a Riverpod Notifier's build(), disposed via ref.onDispose alongside Timer/Stopwatch cleanup"

key-files:
  created:
    - lib/features/metronome/audio/tick_sound_player.dart
    - lib/features/metronome/audio/metronome_audio_service.dart
    - lib/providers/metronome_provider.dart
    - lib/features/metronome/beat_indicator.dart
    - lib/features/metronome/metronome_screen.dart
    - assets/audio/metronome_accent.wav
    - assets/audio/metronome_regular.wav
    - test/integration/metronome_e2e_test.dart
    - test/features/metronome/metronome_state_test.dart
    - test/features/metronome/metronome_audio_service_test.dart
  modified:
    - lib/features/home/home_screen.dart
    - lib/features/tracks/track_detail_screen.dart
    - lib/l10n/app_en.arb
    - lib/l10n/app_ru.arb
    - pubspec.yaml
    - test/features/tracks/track_detail_screen_test.dart

key-decisions:
  - "Used clock.stopwatch() from package:clock instead of a bare Stopwatch() in MetronomeState -- flutter_test's AutomatedTestWidgetsFlutterBinding fakes package:clock's ambient Clock (tied to tester.pump()'s virtual time) but does NOT fake a raw Stopwatch() constructor, which measures real wall-clock time regardless of pump() calls. Without this swap, Task 3's pump-driven beat-cycling tests (and the plan's own Task 1 e2e test) would never observe ticks after the first one, since real time barely advances between pump() calls. Production behavior is unchanged (clock.stopwatch() defaults to real time outside a fake-clock zone)."
  - "Added test-only AudioplayersPlatformInterface/AudioCache/fileSystem doubles in metronome_e2e_test.dart -- audioplayers' real platform channel, path_provider's real temp-dir lookup, and a real LocalFileSystem write all hang indefinitely (not throw) in this sandboxed flutter test environment with no native/plugin backend. All three seams (AudioplayersPlatformInterface.instance, AudioCache.instance, AudioCache.fileSystem) are the package's own supported test-double points (one is @visibleForTesting, the others are public mutable statics), so no production code was touched to make this work."
  - "track_detail_screen_test.dart's new metronome-navigation test uses tester.pump() (not pumpAndSettle()) after tapping the metronome icon -- MetronomeScreen's own audio-asset loading is out of scope for that test and would otherwise require pulling the same platform-double setup into a second test file."

patterns-established:
  - "Riverpod family provider (metronomeStateProvider(initialBpm)) keyed by a constructor argument, matching the two independent navigation entry points (Homepage default 120, Track Detail's own tempo) needing separate live state."
  - "Tests reading an autoDispose Riverpod provider via a bare container.read() (no active watch/listen) get scheduled for disposal on the next event-loop turn; flutter_test's teardown then fails with 'A Timer is still pending' if that disposal-check timer (or a Timer the provider itself owns) hasn't fired yet. Fix: hold an explicit container.listen(provider, (_, __) {}) subscription for the test's duration (mirroring what the real screen's ref.watch does), and explicitly stop any long-running Timer (e.g. togglePlay() to pause) before the test body returns."

requirements-completed: [METR-01, METR-02, METR-03]

coverage:
  - id: D1
    description: "Homepage 'Tools' section with Metronome button opening MetronomeScreen at 120 BPM, paused (METR-01)"
    requirement: METR-01
    verification:
      - kind: widget
        ref: "test/integration/metronome_e2e_test.dart#Homepage 'Metronome' button opens MetronomeScreen at 120 BPM..."
        status: pass
    human_judgment: false
  - id: D2
    description: "Track Detail metronome entry point, gated on tempo != null, prefilled with that track's tempo (METR-02, D-11)"
    requirement: METR-02
    verification:
      - kind: widget
        ref: "test/features/tracks/track_detail_screen_test.dart#a track with a non-null tempo shows a metronome IconButton..."
        status: pass
      - kind: widget
        ref: "test/features/tracks/track_detail_screen_test.dart#a track with tempo == null shows no metronome icon at all (D-11)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Tapping Play starts a 4/4 accented beat cycle synced audio+visual, beat 1 accented; tapping Pause stops it; tempo changes apply on the next tick; app backgrounding stops playback (METR-03, D-03/D-04/D-08/D-09/D-10, PROHIBIT-BG-AUDIO)"
    requirement: METR-03
    verification:
      - kind: widget
        ref: "test/integration/metronome_e2e_test.dart#...Play starts an audible+visual 4/4 beat cycle"
        status: pass
      - kind: unit
        ref: "test/features/metronome/metronome_state_test.dart (Tests 1-6)"
        status: pass
      - kind: unit
        ref: "test/features/metronome/metronome_audio_service_test.dart (Tests 7-8)"
        status: pass
    human_judgment: false
  - id: D4
    description: "On-device audio-visual sync feel and low-latency retrigger quality (placeholder WAV tones, real audioplayers timing on physical hardware)"
    verification: []
    human_judgment: true
    rationale: "18-VALIDATION.md's Manual-Only Verifications explicitly defers on-device audio-visual sync feel to Plan 18-02, once the full dial UI ships -- not a blocking gate for this plan. Automated tests exercise the scheduling/state logic via a fake clock and fake audio platform, not real device audio latency."
duration: ~50min
completed: 2026-08-28
status: complete
---

# Phase 18 Plan 1: Metronome Core Engine Summary

**Metronome playback engine (audioplayers low-latency tick sounds + Stopwatch/Timer beat scheduler + pulsing beat-indicator dots) wired into two navigation entry points, with BPM shown as a plain-text stub for Plan 18-02's dial.**

## Performance
- **Duration:** ~50min
- **Started:** 2026-08-28 (session start)
- **Completed:** 2026-08-28T06:36:22Z
- **Tasks:** 3
- **Files modified:** 22 (16 created, 6 modified; excludes auto-generated `.g.dart`/`app_localizations_*.dart`/`pubspec.lock` churn)

## Accomplishments
- Built the full audio-timing + visual-sync pipeline end-to-end: `TickSoundPlayer` → `MetronomeAudioService` → `MetronomeState` (Riverpod family, Stopwatch-driven `_maybeTick()`) → `BeatIndicator`/`MetronomeScreen`.
- Wired both METR-01 (Homepage "Tools" → 120 BPM default) and METR-02 (Track Detail → prefilled with track tempo, absent when tempo is null, D-11) navigation entry points.
- Generated placeholder tick WAV assets (440Hz/80ms accent, 330Hz/60ms regular, both with 5ms fade envelopes) via Python's `wave`/`struct` stdlib modules, per D-02/D-03.
- Covered D-04 (immediate tempo-change application), D-06 (BPM clamp), D-08 (opens paused), and PROHIBIT-BG-AUDIO (app-lifecycle-driven auto-pause) with 8 passing behavior tests across two TDD-authored test files.
- Diagnosed and fixed a real timing bug (`Stopwatch()` not being fake-clock-aware under `flutter_test`) that would have made every beat-cycling test in this plan and the next silently flaky/broken.

## Task Commits
1. **Task 1: Core metronome engine + Homepage entry -- end-to-end playback** - `46b247e` (feat, tracer)
2. **Task 2: Track detail metronome entry point (METR-02, D-11)** - `9053b30` (feat)
3. **Task 3 RED: failing test for AppLifecycleListener backgrounding-pause** - `992db42` (test)
4. **Task 3 GREEN: stop metronome playback on app background** - `dd20eec` (feat)

## Files Created/Modified
- `lib/features/metronome/audio/tick_sound_player.dart` - `TickSoundPlayer` abstract interface + `AudioPlayersTickSoundPlayer` (audioplayers, `PlayerMode.lowLatency`)
- `lib/features/metronome/audio/metronome_audio_service.dart` - Wraps both tick players behind one asset-load lifecycle; catches and never rethrows load/playback failures
- `lib/providers/metronome_provider.dart` - `MetronomeData` + `MetronomeState` (`@riverpod class`, family keyed by `initialBpm`); `_maybeTick()` beat scheduler; `AppLifecycleListener` auto-pause
- `lib/features/metronome/beat_indicator.dart` - 4-dot beat pulse, beat 0 permanently larger + `colorScheme.primary`
- `lib/features/metronome/metronome_screen.dart` - Loading/error/data states; plain BPM `Text` pair stub for Plan 18-02's dial
- `assets/audio/metronome_accent.wav`, `assets/audio/metronome_regular.wav` - Placeholder tick tones
- `lib/features/home/home_screen.dart` - New "Tools" section, "Metronome" button → `MetronomeScreen(initialBpm: 120)`
- `lib/features/tracks/track_detail_screen.dart` - Conditional AppBar `IconButton` (left of Edit), gated on `tempo != null`
- `lib/l10n/app_en.arb`, `lib/l10n/app_ru.arb` - 7 new ARB keys (Tools/Metronome/loading/error/tooltip strings)
- `pubspec.yaml` - Added `audioplayers`, `clock` (runtime deps); `audioplayers_platform_interface`, `file` (dev deps, test doubles only)
- `test/integration/metronome_e2e_test.dart` - E2E: Homepage → MetronomeScreen → Play → 4-beat cycle observed
- `test/features/metronome/metronome_state_test.dart` - 6 behavior tests (tick sequencing, BPM clamps, D-08, D-04, backgrounding)
- `test/features/metronome/metronome_audio_service_test.dart` - 2 behavior tests (playTick routing, graceful degradation)
- `test/features/tracks/track_detail_screen_test.dart` - 2 new tests (metronome icon present+correct / absent per D-11)

## Decisions Made
- **`clock.stopwatch()` over a bare `Stopwatch()`:** discovered mid-implementation that `flutter_test`'s fake-clock support (`AutomatedTestWidgetsFlutterBinding`) only fakes `package:clock`'s ambient `Clock`, not Dart's raw `Stopwatch` constructor. Since the plan's `_maybeTick()` design (per 18-RESEARCH.md Pitfall 1) is Stopwatch-elapsed-time-based rather than cumulative-tick-counting, a bare `Stopwatch()` made every `tester.pump(duration)`-driven test un-drivable (ticks never advance past the first one). Swapped in `clock.stopwatch()`, which is byte-for-byte the same object in production (backed by the real system clock) but honors `flutter_test`'s fake clock when running under `AutomatedTestWidgetsFlutterBinding`. Zero architectural change; same Stopwatch-based approach the plan specified, just properly test-injectable.
- **Three test-double seams for `test/integration/metronome_e2e_test.dart`:** `audioplayers`' real platform channel, `path_provider`'s temp-dir lookup (used internally by `audioplayers`' `AudioCache`), and a real filesystem write all hang indefinitely (not throw) with no native backend in this test environment. Rather than skip the real audio pipeline in the one test meant to prove it end-to-end, used the package's own supported test-double points: `AudioplayersPlatformInterface.instance`, `AudioCache.instance`, and `AudioCache.fileSystem` (all designed to be swappable for exactly this purpose) -- zero production code changes.
- **`tester.pump()` instead of `pumpAndSettle()`** in the new Track Detail metronome-navigation test, since `MetronomeScreen`'s own audio loading is out of scope for that assertion and would otherwise require duplicating the e2e test's platform-double setup.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Bare `Stopwatch()` doesn't advance under `flutter_test`'s fake clock**
- **Found during:** Task 1's own e2e test (`<verify>` acceptance criterion), then again writing Task 3's behavior tests
- **Issue:** The plan specifies `Stopwatch()..start()` for `_maybeTick()`'s elapsed-time tracking (matching 18-RESEARCH.md Pitfall 1's "use Stopwatch, not cumulative Timer-tick counting" guidance). `flutter_test`'s `AutomatedTestWidgetsFlutterBinding` fakes `Timer` scheduling (confirmed: the periodic check-Timer fires correctly) but does **not** fake a bare `Stopwatch()`'s notion of elapsed time -- it measures real wall-clock time, which barely advances across `tester.pump(duration)` calls (which only advance a *virtual* clock). Result: only the very first tick (fired near-immediately after `togglePlay()`) would ever occur; all subsequent ticks silently never fired, no matter how many `pump()` calls followed.
- **Fix:** Replaced `Stopwatch()` with `clock.stopwatch()` from `package:clock` (added as a direct dependency). `package:clock`'s ambient `Clock` **is** faked by `AutomatedTestWidgetsFlutterBinding` (it backs `TestWidgetsFlutterBinding.clock`, itself sourced from the same `fake_async` zone `tester.pump()` drives), and `Clock.stopwatch()` returns a `Stopwatch`-interface-compatible object driven by that `Clock`. In production (no fake-clock zone), `clock.stopwatch()` is behaviorally identical to `Stopwatch()`.
- **Files modified:** `lib/providers/metronome_provider.dart`, `pubspec.yaml`
- **Verification:** All beat-cycling tests (Task 1's e2e test, Task 3's Tests 1 and 5) pass deterministically.
- **Commit:** `46b247e` (fix landed within Task 1's tracer commit, before the tracer's own `<verify>` was confirmed green)

**2. [Rule 3 - Blocking] `audioplayers`' real platform channel hangs (not throws) with no native backend in `flutter test`**
- **Found during:** Task 1's e2e test, running `flutter test test/integration/metronome_e2e_test.dart`
- **Issue:** An unmocked `MethodChannel.invokeMethod` call in this sandboxed test environment never resolves (confirmed via a raw isolated `MethodChannel` probe: 30s timeout, no exception). `audioplayers`' `AudioPlayer._create()` and `AudioCache.loadPath()` (via `path_provider`'s `getTemporaryDirectory()` and a real `LocalFileSystem` write) all hit this same hang, which would have blocked `pumpAndSettle()` indefinitely and made the plan's mandated e2e test unrunnable exactly as specified.
- **Fix:** Added three test-only doubles in `metronome_e2e_test.dart`, all swapping the package's own designed-for-testing seams: a fake `AudioplayersPlatformInterface` (no-op method calls, per-player `StreamController` emitting the `prepared` event synchronously from `setSourceUrl`/`setSourceBytes` so `AudioPlayer`'s internal `_completePrepared` wait resolves deterministically rather than racing a timer), a fake `AudioCache` (`getTempDir()` override, `@visibleForTesting` on the real class specifically for this), and `AudioCache.fileSystem = MemoryFileSystem()` (also `@visibleForTesting`). No production code touched.
- **Files modified:** `test/integration/metronome_e2e_test.dart`, `pubspec.yaml` (added `audioplayers_platform_interface`, `file` dev dependencies)
- **Verification:** `flutter test test/integration/metronome_e2e_test.dart` passes; full plan-level verification command passes (32/32 tests); `flutter analyze` zero issues.
- **Commit:** `46b247e`

**3. [Rule 1 - Bug] Riverpod `autoDispose` provider disposal-check timers left pending at test teardown**
- **Found during:** Writing Task 3's `metronome_state_test.dart`
- **Issue:** `metronomeStateProvider` is `autoDispose` (matching production's `ref.watch` lifetime, tied to the screen being mounted). A bare `container.read()` in a test (no active `watch`/`listen`) schedules a disposal-eligibility check on the next event-loop turn; if that check (or the beat `Timer` itself, left running from an un-paused `togglePlay()`) hadn't fired by the time `flutter_test` verified invariants at teardown, the test failed with "A Timer is still pending even after the widget tree was disposed" -- unrelated to the actual behavior under test.
- **Fix:** Added a `keepAlive()` helper (an explicit `container.listen(provider, (_, __) {})` held for the test's duration, mirroring what `MetronomeScreen`'s own `ref.watch` does) to every test, and explicitly paused playback (`togglePlay()` a second time) at the end of any test that started it, before the test body returns.
- **Files modified:** `test/features/metronome/metronome_state_test.dart`
- **Verification:** All 6 tests in the file pass without teardown assertion failures.
- **Commit:** `992db42`

None of these three deviations required an architectural change, a new dependency beyond dev-only test-support packages (`audioplayers_platform_interface`, `file`) plus one small runtime dependency (`clock`, already transitively present), or any deviation from the plan's specified production code shape -- `TickSoundPlayer`, `MetronomeAudioService`, and `MetronomeState`'s public API and behavior match the plan exactly.

## Issues Encountered
None beyond the three deviations documented above (all auto-fixed under Rules 1/3, no user input required).

## User Setup Required
None -- no external service configuration required. Per D-02, the user may later drop replacement WAV files at `assets/audio/metronome_accent.wav` / `assets/audio/metronome_regular.wav` with no code changes needed.

## Next Phase Readiness
Plan 18-02 (drag-to-BPM dial + quick-adjust buttons) can build directly on this plan's output:
- `MetronomeScreen._buildContent`'s plain BPM `Text` pair is an explicit, documented stub -- Plan 18-02 swaps in `MetronomeDial` with no architectural change to `MetronomeScreen`, `MetronomeState`, or the audio layer.
- `MetronomeState.setBpm(int)` is already the single choke point (unconditional `.clamp(40, 300)`) that a dial's live-drag callback and quick-adjust `±1`/`±5` buttons will call directly -- no new provider surface needed.
- The `clock.stopwatch()` fix and the `keepAlive()`/explicit-stop test pattern are directly reusable for any new tests Plan 18-02 adds against `metronomeStateProvider`.

---
*Phase: 18-metronome-tool*
*Completed: 2026-08-28*
