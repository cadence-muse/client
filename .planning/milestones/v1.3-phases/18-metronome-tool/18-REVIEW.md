---
phase: 18-metronome-tool
reviewed: 2026-08-28T06:58:55Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - lib/features/metronome/audio/tick_sound_player.dart
  - lib/features/metronome/audio/metronome_audio_service.dart
  - lib/providers/metronome_provider.dart
  - lib/features/metronome/beat_indicator.dart
  - lib/features/metronome/metronome_dial.dart
  - lib/features/metronome/metronome_screen.dart
  - lib/features/home/home_screen.dart
  - lib/features/tracks/track_detail_screen.dart
  - lib/l10n/app_en.arb
  - lib/l10n/app_ru.arb
  - lib/generated/app_localizations.dart
  - lib/generated/app_localizations_en.dart
  - lib/generated/app_localizations_ru.dart
  - pubspec.yaml
  - assets/audio/metronome_accent.wav
  - assets/audio/metronome_regular.wav
  - test/integration/metronome_e2e_test.dart
  - test/features/metronome/metronome_state_test.dart
  - test/features/metronome/metronome_audio_service_test.dart
  - test/features/metronome/metronome_dial_test.dart
  - test/features/metronome/metronome_screen_test.dart
  - test/features/tracks/track_detail_screen_test.dart
findings:
  critical: 3
  warning: 3
  info: 1
  total: 7
status: issues_found
---

# Phase 18: Code Review Report

**Reviewed:** 2026-08-28T06:58:55Z
**Depth:** standard
**Files Reviewed:** 21
**Status:** issues_found

## Summary

Reviewed the metronome audio service, Riverpod provider, dial/beat-indicator widgets, and their Home/Track Detail entry points. The BPM clamping, tick-scheduling logic that lets a live tempo change take effect on the very next check (D-04), and the app-lifecycle-driven auto-pause are all correctly implemented and covered by deterministic fake-clock tests. However, the audio-failure path has two compounding defects that break the feature's own documented "graceful degradation" contract: (1) a partial initialization failure leaves one `TickSoundPlayer`'s `late final` field unset, so disposing the service later throws an uncaught `LateInitializationError`; and (2) the failure is swallowed one layer too early, so the screen's dedicated error UI (`_buildError`, wired to `metronomeErrorMessage`/`commonRetry`) can never actually be shown — a real asset-load failure instead produces a fully-interactive but permanently silent metronome with zero user feedback. The Play FAB is also not gated on audio-load state, so tapping it during the loading window silently drops the first tick(s)' sound. Two lower-severity issues were also found: the dial's `CustomPainter.shouldRepaint` ignores theme-driven style/color changes, and the beat scheduler's relative-to-last-fire scheduling will drift under real-clock jitter (invisible to the fake-clock tests).

## Critical Issues

### CR-01: `dispose()` throws `LateInitializationError` when one tick asset fails to initialize

**File:** `lib/features/metronome/audio/metronome_audio_service.dart:35-46` (and `lib/features/metronome/audio/tick_sound_player.dart:30,44-47`)

**Issue:** `MetronomeAudioService.initialize()` wraps both players in a single try/catch:

```dart
try {
  await _accentPlayer.initialize();
  await _regularPlayer.initialize();
  _assetsLoaded = true;
} catch (e) {
  _assetsLoaded = false;
  debugPrint(...);
}
```

If `_accentPlayer.initialize()` throws (e.g. the accent `.wav` asset fails to decode, or `setPlayerMode(PlayerMode.lowLatency)` isn't supported on the device), `_regularPlayer.initialize()` is **never called** — the `catch` short-circuits the `await` chain. `AudioPlayersTickSoundPlayer._player` is a `late final AudioPlayer` assigned only inside `initialize()` (`tick_sound_player.dart:34`), so `_regularPlayer._player` is left uninitialized.

Later, whenever the screen is popped and `metronomeAudioServiceProvider`'s `ref.onDispose(service.dispose)` fires, `MetronomeAudioService.dispose()` unconditionally calls `_regularPlayer.dispose()` → `await _player.dispose()` → throws `LateInitializationError: Field '_player' has not been initialized.` This is an unhandled, un-awaited Future error (see CR-02 for the compounding user-facing effect) that directly contradicts this file's own documented intent ("T-18-02: never rethrow ... graceful degradation"). No test exercises `dispose()` after an `initialize()` failure — `metronome_audio_service_test.dart`'s Test 8 never calls `service.dispose()`.

**Fix:** Initialize both players independently so a single failure can't skip the other, and make `dispose()` defensive regardless:

```dart
Future<void> initialize() async {
  final results = await Future.wait([
    _initPlayer(_accentPlayer),
    _initPlayer(_regularPlayer),
  ]);
  _assetsLoaded = results.every((ok) => ok);
}

Future<bool> _initPlayer(TickSoundPlayer player) async {
  try {
    await player.initialize();
    return true;
  } catch (e) {
    debugPrint('MetronomeAudioService: failed to load tick asset: $e');
    return false;
  }
}

void dispose() {
  unawaited(_accentPlayer.dispose().catchError((_) {}));
  unawaited(_regularPlayer.dispose().catchError((_) {}));
}
```

---

### CR-02: Asset-load failure never reaches the screen's error UI — produces a silently broken metronome instead

**File:** `lib/features/metronome/audio/metronome_audio_service.dart:66-77`, `lib/features/metronome/metronome_screen.dart:31-35,133-154`

**Issue:** The `metronomeAudioService` provider is:

```dart
@riverpod
Future<MetronomeAudioService> metronomeAudioService(MetronomeAudioServiceRef ref) async {
  final service = MetronomeAudioService(...);
  await service.initialize();
  ref.onDispose(service.dispose);
  return service;
}
```

`service.initialize()` never throws — it always resolves after its internal try/catch, regardless of whether asset loading actually succeeded. This means `audioAsync` in `MetronomeScreen` can **never** enter the `AsyncError` state through normal use; `audioAsync.when(... error: (e, st) => _buildError(...))` is dead code.

The screen was clearly designed around the opposite assumption: it has a dedicated `_buildError` view with `l10n.metronomeErrorMessage` ("Couldn't load metronome. Try again.") and a Retry button that calls `ref.invalidate(metronomeAudioServiceProvider)`. But because the failure is already swallowed one layer below, a genuine asset-load failure instead falls through to `_buildContent` — the dial renders, the Play FAB works, `BeatIndicator` pulses — but every `playTick` silently no-ops (`_assetsLoaded == false`), so the metronome is permanently and silently inaudible with **no indication to the user that anything is wrong**. This is arguably worse than the intended failure mode: the "Couldn't load metronome. Try again." UX this phase specifically built and localized (`metronomeErrorMessage`/`commonRetry` in both `app_en.arb`/`app_ru.arb`) is unreachable.

**Fix:** Surface the failure through the screen, e.g. have `MetronomeScreen` check the resolved service instead of relying on `AsyncError`:

```dart
body: audioAsync.when(
  data: (service) => service.assetsLoaded
      ? _buildContent(context, state, notifier)
      : _buildError(context, ref, l10n),
  loading: () => _buildLoading(context, l10n),
  error: (e, st) => _buildError(context, ref, l10n),
),
```

---

### CR-03: Play FAB is not gated on audio-load state — tapping it during load silently drops tick sound

**File:** `lib/features/metronome/metronome_screen.dart:29-41`

**Issue:** `floatingActionButton` is declared as a sibling of `body: audioAsync.when(...)`, not inside it, so the Play/Pause FAB is always enabled — including while `audioAsync` is still `loading` (the "Initializing metronome..." spinner is showing) or in the (currently unreachable, see CR-02) error state. If a user taps Play before `metronomeAudioServiceProvider` resolves, `MetronomeState.togglePlay()` starts the beat timer immediately; any ticks that fire before the provider resolves read `ref.read(metronomeAudioServiceProvider).valueOrNull` as `null` (`metronome_provider.dart:121-126`) and silently produce no sound, even though the beat indicator is already visually cycling and the FAB already shows the pause icon. For a tool whose entire purpose is audible feedback, this is a real (if narrow-window) functional defect with no test coverage — `metronome_screen_test.dart` always uses a fake service that resolves synchronously, so this window is never exercised.

**Fix:** Gate the FAB the same way the body is gated:

```dart
floatingActionButton: audioAsync.hasValue
    ? FloatingActionButton(
        onPressed: notifier.togglePlay,
        child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
      )
    : null,
```

## Warnings

### WR-01: `MetronomeDialPainter.shouldRepaint` ignores color/style changes

**File:** `lib/features/metronome/metronome_dial.dart:88-90`

**Issue:**

```dart
@override
bool shouldRepaint(MetronomeDialPainter oldDelegate) =>
    oldDelegate.bpm != bpm;
```

`ringColor`, `numberStyle`, and `unitStyle` are all resolved from `Theme.of(context)` in `MetronomeDial.build()` and passed into a freshly-constructed `MetronomeDialPainter` on every rebuild, but `shouldRepaint` only compares `bpm`. If the app's theme changes (e.g. dark/light mode toggle) while the BPM value happens to stay the same, `RenderCustomPaint` will skip repainting and the dial will keep rendering with the stale ring color / text style until the next BPM change forces a repaint.

**Fix:**

```dart
@override
bool shouldRepaint(MetronomeDialPainter oldDelegate) =>
    oldDelegate.bpm != bpm ||
    oldDelegate.ringColor != ringColor ||
    oldDelegate.numberStyle != numberStyle ||
    oldDelegate.unitStyle != unitStyle;
```

### WR-02: Tick scheduling drifts under real-clock jitter (invisible to fake-clock tests)

**File:** `lib/providers/metronome_provider.dart:113-133`

**Issue:** `_maybeTick()` schedules the next tick relative to the *actual* elapsed time at which the current 10ms poll happened to fire, not to a fixed schedule anchored at play-start:

```dart
_nextTickDueMs = _stopwatch!.elapsedMilliseconds + intervalMs;
```

Since `Timer.periodic(10ms)` callbacks can legitimately fire a few ms late (main-thread jank, OS scheduling, the inherent up-to-10ms polling granularity itself), each late firing pushes the *next* due time later too — the lateness compounds tick over tick rather than being corrected against an absolute reference. Over a multi-minute practice session this will make the metronome measurably slower than the configured BPM. `metronome_state_test.dart`'s Test 1/Test 5 don't catch this because `flutter_test`'s `FakeAsync`-backed `clock.stopwatch()` fires every scheduled timer at an exact simulated offset with no real jitter, so the drift only manifests on a real device/real clock.

**Fix:** Anchor scheduling to a fixed reference (e.g. record `_playStartMs` once on `togglePlay()` and a running tick counter), computing `_nextTickDueMs = _playStartMs + (_tickCount * intervalMs)` so occasional late polls don't shift the baseline for subsequent ticks. Recomputing `intervalMs` from the counter position (rather than purely "now + interval") can still preserve D-04's "tempo change takes effect on the very next tick" behavior.

### WR-03: (info-adjacent, listed here since it borders correctness) Dead normalization branch in the dial's gesture handler

**File:** `lib/features/metronome/metronome_dial.dart:118-121`

**Issue:** `math.atan2` returns values in `(-π, π]`, so after `+ 90`, `degrees` ranges over `(-90, 270]`. The first branch (`if (degrees > 180) degrees -= 360;`) already folds this into `(-180, 180]` with no gap. The second branch, `if (degrees <= -180) degrees += 360;`, can therefore never be true — `degrees` is always strictly greater than `-180` after the first branch. It's harmless (never executes, never produces a wrong value) but is dead code that could mislead a future reader into thinking `-180` is a reachable case needing this correction.

**Fix:** Remove the branch, or replace both branches with a single explicit `((degrees + 180) % 360) - 180` style normalization with a comment noting the true reachable domain, whichever reads more clearly.

## Info

### IN-01: `debugPrint` is the only signal on tick-asset load/playback failures

**File:** `lib/features/metronome/audio/metronome_audio_service.dart:44,56`

**Issue:** Both failure paths (`initialize()` catch, `playTick()` catch) only `debugPrint`, which is stripped/invisible in release builds. Combined with CR-02, this means a production asset-load failure currently leaves no trace anywhere the user or a crash-reporting pipeline would see it. Once CR-02 is fixed so the failure is properly surfaced to the UI, consider also routing these through whatever error-reporting hook (if any) the app uses elsewhere, so silent-metronome reports are diagnosable.

**Fix:** Not a required change if CR-02 is fixed (the UI will then make the failure visible to the user); worth a follow-up if the project has centralized non-fatal error logging.

---

_Reviewed: 2026-08-28T06:58:55Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
