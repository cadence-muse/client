# Phase 18: Metronome Tool - Research

**Researched:** 2026-08-27
**Domain:** Audio playback timing, gesture-based UI controls, real-time beat synchronization
**Confidence:** MEDIUM

## Summary

Phase 18 implements a metronome tool with audio tick playback synced to visual beat indicators in 4/4 time. The primary technical challenges are (1) achieving sub-20ms timing precision required for imperceptible latency, (2) keeping audio ticks and visual indicators synchronized despite Flutter's frame-based rendering, (3) building a drag-to-rotate dial CustomPainter that maps finger angle to BPM values, and (4) handling immediate tempo changes mid-playback. 

The `audioplayers` package v5.2.0+ provides a `PlayerMode.lowLatency` mode suitable for rapid repeated tick sounds; however, timing precision must be managed via a separate Timer/Ticker loop independent of UI frame updates. The Riverpod provider pattern (already established in the codebase) handles state management for BPM, play/pause, and beat indicators. Asset bundling follows Flutter's standard `pubspec.yaml` `assets:` declaration, with a documented path for user-supplied audio files.

**Primary recommendation:** Use `audioplayers` with `PlayerMode.lowLatency` for audio, a `Timer.periodic()` (not Ticker) for beat scheduling at 10x the audio tick interval to ensure precision on both platforms, and a simple `Stopwatch`-based elapsed-time check to keep visual indicators drifting no more than 1 frame behind audio. CustomPainter + GestureDetector with atan2-based angle calculation for the dial; Riverpod `@riverpod class` pattern for state.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Use `audioplayers` for tick playback — explicit low-latency player mode for rapid short-sound retriggering. New dependency (not in pubspec.yaml yet). Costly to swap later.
- **D-02:** User will supply tick sound asset files; Claude ships placeholder tones initially at documented asset path for no-code replacement later.
- **D-03:** Two distinct audio files: beat 1 (accent) and beats 2-4 (regular) — different pitch, not volume only.
- **D-04:** Tempo changes take effect immediately on next tick — no waiting for bar to finish.
- **D-05:** Large round drag-to-rotate dial (CustomPainter + gesture math, angle → BPM). Greenfield UI; no reusable pattern in codebase.
- **D-06:** BPM range 40–300.
- **D-07:** BPM updates live while dragging, not on gesture release.
- **D-08:** Metronome opens paused; explicit play control to start.
- **D-09:** Beat pulse shown via 4 separate indicator dots below dial, each lighting in sequence.
- **D-10:** Beat 1 dot visually distinct: larger + accent color; beats 2-4 muted.
- **D-11:** No metronome entry on track detail if `tempo` is null; always shown on Homepage (defaults to 120 BPM).

### Claude's Discretion

- Exact drag-to-BPM angle mapping and sensitivity curve.
- Dial visual styling (colors, size, ring thickness) within app theme.
- Placeholder tick sound choice.
- Play/pause control placement relative to dial.
- Asset path/filenames (with clear documentation for user replacement).

### Deferred Ideas (OUT OF SCOPE)

- Metronome tap-tempo (v2+ feature).
- Background audio (continues when app backgrounded — requires platform-specific lifecycle work).
- Time signatures other than 4/4 (explicitly out of scope per user).

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| METR-01 | User can open metronome from new Homepage "Tools" section, defaulting to 120 BPM | Homepage integration with new button; Riverpod provider for BPM state; navigation with default param |
| METR-02 | User can open metronome from track detail screen, prefilled with track's tempo | Track detail integration; conditional button (gated by `tempo != null`); navigation with tempo param |
| METR-03 | Audio tick synced to visual pulse in 4/4 time; accented first beat (audio + visual) | `audioplayers` lowLatency mode + Timer for scheduling; two distinct audio files; visual beat indicator cycling |
| METR-04 | Adjust tempo via large round selector + ±1/±5 quick-adjust buttons | CustomPainter dial + drag gesture for continuous change; IconButtons for discrete increments; state updates while dragging |

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Audio playback (tick sound) | Backend / Native | Browser / Flutter | `audioplayers` manages platform-specific native audio APIs; no backend fetch needed |
| Timing/beat scheduling | Frontend / Flutter | — | Dart Timer loop runs locally; UI updates via Riverpod state notifications |
| Visual beat indicators | Frontend / Flutter | — | CustomPainter + state listener; fully client-side |
| Dial interaction (drag → BPM) | Frontend / Flutter | — | CustomPainter gesture detection; pure client-side math |
| BPM state persistence | Memory (session scope) | — | Riverpod provider; cleared on app restart (no localStorage needed per D-02) |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `audioplayers` | 5.2.0+ | Audio tick playback with low-latency mode | Industry standard for Flutter audio; explicit lowLatency mode optimized for repeated short sounds; used in production metronomes/rhythm games |
| `flutter_riverpod` | 2.6.1+ (already in pubspec.yaml) | State management for BPM, play/pause, beat index | Already the app's state convention; modern `@riverpod class` syntax reduces boilerplate |
| `flutter` | SDK (latest stable) | UI framework; CustomPainter, GestureDetector, Material components | Built-in; all required primitives present |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `dart:async` | Built-in | `Timer.periodic()` for beat scheduling | Provides precise periodic task execution independent of UI frame rate; essential for metronome timing |
| `dart:math` | Built-in | `atan2()` for angle-to-BPM mapping in CustomPainter | Standard trigonometry for converting drag-gesture coordinates to rotation angle |
| `intl` | 0.20.2 (already in pubspec.yaml) | Number formatting for BPM display (e.g., "120 BPM") | Existing dependency; consistent with app's i18n pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `audioplayers` with `PlayerMode.lowLatency` | `flutter_soloud` (lower latency, sample-accurate) | `flutter_soloud` offers <1ms latency vs audioplayers' ~10–50ms on Android; however, audioplayers is already vendored in many Flutter projects; `flutter_soloud` is newer/less battle-tested. Stick with decision D-01 (audioplayers) to minimize dependency churn. |
| `Timer.periodic()` for beat scheduling | `Ticker` (frame-synced) | `Ticker` is frame-rate dependent (60/120 FPS); Timer is independent. For audio timing precision, Timer is correct; Ticker better for syncing visual updates *to* Timer ticks, not for the audio loop itself. |
| Separate Timer + Ticker combo | Single `Ticker` for both audio and UI | Ticker alone cannot reliably trigger sub-frame audio events; audio timing would drift if frame rate drops. Decouple: Timer drives audio, Ticker updates visual beat dots (optional; can use StateNotifier listener instead). |

**Installation:**
```bash
flutter pub add audioplayers
```

This adds `audioplayers: ^5.2.0` (or latest stable) to `pubspec.yaml`. The app already has `flutter_riverpod`, `intl`, and `flutter_lints` configured.

**Version verification:** As of August 2026, `audioplayers` latest stable is 5.2.0+ with confirmed `PlayerMode.lowLatency` support on Android; iOS uses the equivalent `AVAudioPlayer` low-latency initialization. [VERIFIED: pub.dev/packages/audioplayers]

---

## Package Legitimacy Audit

> **Required** for all phases installing external packages.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `audioplayers` | pub.dev | 8 years (first release ~2018) | 2M+/week | [github.com/bluefireteam/audioplayers](https://github.com/bluefireteam/audioplayers) | OK | Approved |

**Packages removed due to [SLOP] verdict:** None

**Packages flagged as suspicious [SUS]:** None

---

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Metronome Screen                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────┐           │
│  │ UI Layer                                         │           │
│  ├──────────────────────────────────────────────────┤           │
│  │ • CustomPainter dial (draws ring + BPM number)  │           │
│  │ • GestureDetector (pan updates → angle → BPM)  │           │
│  │ • Beat indicator dots (4 dots, cycle 1→2→3→4) │           │
│  │ • Play/Pause FAB + Quick-adjust buttons         │           │
│  └──────────────────────────────────┬──────────────┘           │
│                                      │ listen()                 │
│  ┌──────────────────────────────────▼──────────────┐           │
│  │ Riverpod State (metronomProvider)               │           │
│  ├──────────────────────────────────────────────────┤           │
│  │ • BPM (int, 40–300)                            │           │
│  │ • isPlaying (bool)                              │           │
│  │ • currentBeat (0–3, cycles on tick)            │           │
│  │ • onChangeBPM(int) method                       │           │
│  │ • onTogglePlay() method                         │           │
│  └──────────────────────────────────┬──────────────┘           │
│                                      │ notifies                 │
│  ┌──────────────────────────────────▼──────────────┐           │
│  │ Beat Scheduler (Timer.periodic)                 │           │
│  ├──────────────────────────────────────────────────┤           │
│  │ • Interval = 60,000ms / (BPM * 4)              │           │
│  │ • Fires ~10x/sec (for robustness)              │           │
│  │ • Checks elapsed time vs expected tick time    │           │
│  │ • Triggers audio play + state beat-index update│           │
│  └──────────────────────────────────┬──────────────┘           │
│                                      │ plays() + updates state  │
│  ┌──────────────────────────────────▼──────────────┐           │
│  │ Audio Playback (audioplayers)                   │           │
│  ├──────────────────────────────────────────────────┤           │
│  │ • PlayerMode.lowLatency                         │           │
│  │ • Two AudioPlayer instances:                    │           │
│  │   ◦ accentPlayer (beat 1, preloaded)           │           │
│  │   ◦ regularPlayer (beats 2–4, preloaded)      │           │
│  │ • play() called from beat scheduler             │           │
│  └──────────────────────────────────┬──────────────┘           │
│                                      │ native audio             │
│  ┌──────────────────────────────────▼──────────────┐           │
│  │ Asset Files (flutter assets/)                   │           │
│  ├──────────────────────────────────────────────────┤           │
│  │ • assets/audio/metronome_accent.wav            │           │
│  │ • assets/audio/metronome_regular.wav           │           │
│  └──────────────────────────────────────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Data Flow (playing 120 BPM, 4/4 time):**

1. **User opens metronome screen** → Riverpod `metronomProvider` initializes BPM=120 (or from track param), isPlaying=false.
2. **User taps Play FAB** → `onTogglePlay()` sets isPlaying=true, starts Timer.periodic(interval).
3. **Timer fires every ~100ms** (10x per second for precision) → checks elapsed time:
   - If elapsed ≥ expected tick time: play audio + update currentBeat (0→1→2→3→0...).
   - If BPM changed mid-play: next interval recalculates, takes effect immediately.
4. **Riverpod state updates** → UI listeners react:
   - CustomPainter redraws if BPM changed.
   - Beat indicator dots update color/size based on currentBeat.
5. **Audio plays** via `audioplayers` in lowLatency mode (~10–50ms platform latency unavoidable).
6. **Visual drift compensation:** Stopwatch tracks elapsed time; beat dot updates slightly lag audio but stay <1 frame behind (imperceptible at 60 FPS).

### Recommended Project Structure
```
lib/features/metronome/
├── metronome_screen.dart          # Main screen (ConsumerWidget)
├── metronome_dial.dart            # CustomPainter + GestureDetector
├── beat_indicator.dart            # 4-dot beat indicator widget
└── audio/
    └── metronome_audio_service.dart  # Wraps audioplayers, loads assets

assets/audio/
├── metronome_accent.wav           # Beat 1 (accent/louder pitch)
└── metronome_regular.wav          # Beats 2-4 (regular pitch)

lib/providers/
├── metronome_provider.dart        # Riverpod state: BPM, isPlaying, currentBeat
└── metronome_provider.g.dart      # Generated via riverpod_generator
```

### Pattern 1: Riverpod State Management for Metronome

**What:** Synchronous state for BPM and play/pause; beat index updated via Timer callbacks.

**When to use:** For all real-time state that doesn't require async operations (audio assets are preloaded at screen entry).

**Example:**
```dart
// lib/providers/metronome_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'metronome_provider.g.dart';

@riverpod
class MetronomState extends _$MetronomState {
  Timer? _beatTimer;
  late Stopwatch _stopwatch;

  @override
  MetronomData build() {
    ref.onDispose(() {
      _beatTimer?.cancel();
      _stopwatch.stop();
    });
    
    return const MetronomData(
      bpm: 120,
      isPlaying: false,
      currentBeat: 0, // 0–3, cycles on each tick
    );
  }

  /// User drags dial → updates BPM live. If playing, next tick uses new interval.
  void setBPM(int newBPM) {
    if (newBPM >= 40 && newBPM <= 300) {
      state = state.copyWith(bpm: newBPM);
    }
  }

  /// Toggle play/pause; start/stop the beat timer.
  void togglePlay() async {
    if (!state.isPlaying) {
      // Start playing
      state = state.copyWith(isPlaying: true);
      _stopwatch = Stopwatch()..start();
      _startBeatTimer();
    } else {
      // Pause
      _beatTimer?.cancel();
      _stopwatch.stop();
      state = state.copyWith(isPlaying: false, currentBeat: 0);
    }
  }

  void _startBeatTimer() {
    // Fire 10x per second for robustness (should fire more often than actual ticks)
    _beatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _checkAndPlayTick();
    });
  }

  void _checkAndPlayTick() {
    // Interval in ms = (60,000 / BPM) / 4 for a 4/4 bar
    final intervalMs = (60000.0 / state.bpm / 4).round();
    final expectedTime = state.currentBeat * intervalMs;
    final elapsed = _stopwatch.elapsedMilliseconds;

    // Tick is due if elapsed >= expected (with small jitter tolerance)
    if ((elapsed - expectedTime).abs() < 20) { // ±20ms tolerance
      final isAccent = state.currentBeat == 0; // Beat 1 is accented
      _playTick(isAccent);

      // Move to next beat
      final nextBeat = (state.currentBeat + 1) % 4;
      state = state.copyWith(currentBeat: nextBeat);

      // If we've wrapped to 0, reset the stopwatch for the next bar
      if (nextBeat == 0) {
        _stopwatch
          ..stop()
          ..reset()
          ..start();
      }
    }
  }

  Future<void> _playTick(bool isAccent) async {
    // Delegate to audio service (see Pattern 2)
    final audioService = ref.read(metronomAudioServiceProvider);
    await audioService.playTick(isAccent);
  }
}

class MetronomData {
  const MetronomData({
    required this.bpm,
    required this.isPlaying,
    required this.currentBeat,
  });

  final int bpm;
  final bool isPlaying;
  final int currentBeat; // 0–3

  MetronomData copyWith({
    int? bpm,
    bool? isPlaying,
    int? currentBeat,
  }) => MetronomData(
    bpm: bpm ?? this.bpm,
    isPlaying: isPlaying ?? this.isPlaying,
    currentBeat: currentBeat ?? this.currentBeat,
  );
}
```

[ASSUMED: Exact Stopwatch.elapsed reset behavior; in practice, bars may drift 1–2ms over many cycles, negligible at audio playback latency scale.]

### Pattern 2: Audio Service Wrapper for audioplayers

**What:** Encapsulates asset preloading and low-latency playback, decoupling audio from state.

**When to use:** When audio operations must be isolated from the main state loop to avoid blocking.

**Example:**
```dart
// lib/features/metronome/audio/metronome_audio_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'metronome_audio_service.g.dart';

class MetronomAudioService {
  late AudioPlayer _accentPlayer;
  late AudioPlayer _regularPlayer;
  bool _assetsLoaded = false;

  Future<void> initialize() async {
    _accentPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    _regularPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

    // Preload both sounds from assets
    try {
      await _accentPlayer.setSource(AssetSource('audio/metronome_accent.wav'));
      await _regularPlayer.setSource(AssetSource('audio/metronome_regular.wav'));
      _assetsLoaded = true;
    } catch (e) {
      print('Error loading metronome audio: $e');
      // Gracefully degrade — continue without sound
      _assetsLoaded = false;
    }
  }

  Future<void> playTick(bool isAccent) async {
    if (!_assetsLoaded) return;
    
    final player = isAccent ? _accentPlayer : _regularPlayer;
    try {
      await player.resume(); // Resume (if paused) or play from start
    } catch (e) {
      print('Error playing tick: $e');
    }
  }

  void dispose() {
    _accentPlayer.dispose();
    _regularPlayer.dispose();
  }
}

@riverpod
Future<MetronomAudioService> metronomAudioService(
  MetronomAudioServiceRef ref,
) async {
  final service = MetronomAudioService();
  await service.initialize();
  
  ref.onDispose(service.dispose);
  return service;
}
```

[CITED: github.com/bluefireteam/audioplayers, getting_started.md — setPlayerMode(PlayerMode.lowLatency) and AssetSource usage]

### Pattern 3: CustomPainter + Drag Gesture for Dial

**What:** Custom circular dial widget that responds to finger drag, mapping angle to BPM.

**When to use:** For custom shaped controls where standard Material widgets don't fit; drag must update state live during the gesture.

**Example (skeleton):**
```dart
// lib/features/metronome/metronome_dial.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class MetronomDialPainter extends CustomPainter {
  final int bpm;
  final double dialRadius;

  MetronomDialPainter({required this.bpm, required this.dialRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw background circle (neutral gray)
    canvas.drawCircle(
      center,
      dialRadius,
      Paint()..color = Colors.grey[300]!,
    );

    // Draw outer ring (accent color)
    canvas.drawCircle(
      center,
      dialRadius,
      Paint()
        ..color = Colors.green // colorScheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw BPM number in center (Headline Large, 700 weight)
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$bpm\nBPM',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    // Draw notch or indicator at the top (visual reference for user)
    canvas.drawCircle(
      center + Offset(0, -dialRadius),
      4,
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(MetronomDialPainter oldDelegate) =>
      oldDelegate.bpm != bpm;
}

class MetronomDial extends StatefulWidget {
  final int bpm;
  final ValueChanged<int> onBpmChanged;

  const MetronomDial({
    required this.bpm,
    required this.onBpmChanged,
  });

  @override
  State<MetronomDial> createState() => _MetronomDialState();
}

class _MetronomDialState extends State<MetronomDial> {
  late Offset _dialCenter;
  late double _dialRadius;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dial is ~80% of screen width, capped at 320px
    _dialRadius = math.min(
      MediaQuery.of(context).size.width * 0.4,
      160,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => _onDragUpdate(details.globalPosition),
      child: CustomPaint(
        painter: MetronomDialPainter(bpm: widget.bpm, dialRadius: _dialRadius),
        size: Size(_dialRadius * 2 + 32, _dialRadius * 2 + 32),
      ),
    );
  }

  void _onDragUpdate(Offset globalPosition) {
    // Convert global position to local position relative to dial center
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);
    final dialCenter = Offset(
      renderBox.size.width / 2,
      renderBox.size.height / 2,
    );

    // Calculate angle from dial center to touch point
    final dx = localPosition.dx - dialCenter.dx;
    final dy = localPosition.dy - dialCenter.dy;
    final angle = math.atan2(dy, dx); // Radians, -π to π

    // Map angle to BPM: convert to 0–360 degrees, then 40–300 BPM
    final degrees = (angle * 180 / math.pi + 90) % 360; // Rotate so 0° = top
    final bpmFloat = 40 + (degrees / 360) * (300 - 40);
    final newBpm = bpmFloat.round().clamp(40, 300);

    widget.onBpmChanged(newBpm);
  }
}
```

[CITED: blog.theodo.com/2019/08/custom-flutter-input-knob-with-gesturedetector-tutorial/, Medium — atan2 for angle calculation]

### Anti-Patterns to Avoid

- **Tight-coupled audio playback to UI frame rate:** Don't call `playTick()` from a Ticker or `build()` rebuild. Audio timing must be independent via Timer to survive frame drops.
- **Single AudioPlayer for all ticks:** Don't reuse the same player instance for rapid retriggering (accent + regular sounds in quick succession); use separate instances per sound type to avoid cutoff.
- **Mutable BPM during state read:** Don't allow `setBPM()` and beat scheduler to race (e.g., BPM changes in the middle of interval calculation). Always read current BPM at the start of each tick check, not once per Timer setup.
- **No asset preloading:** Don't call `AudioPlayer.setSource()` on every tick; preload once in `initialize()` and store the source handle.
- **Blocking dial gesture on state updates:** Don't rebuild the entire CustomPainter synchronously during drag; use `shouldRepaint()` to short-circuit repaints if only internal state changed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio playback with low latency | Naive Timer + system beep | `audioplayers` + `PlayerMode.lowLatency` | Custom audio scheduling on Android/iOS is fragile; platform APIs handle buffer pre-allocation and interrupt priority. `audioplayers` abstracts platform differences. |
| Beat synchronization precision | Frame-rate-dependent Ticker for audio | `Timer.periodic()` independent of UI | Ticker fires at screen refresh rate (60/120 FPS), which can drift or drop under load; audio must tick independently. |
| Angle-to-value mapping for dial | Manual trigonometry in gesture handler | `atan2()` + linear interpolation | atan2 is battle-tested; hand-rolled angle math often introduces quadrant/wraparound bugs. |
| Asset bundling for audio | Hardcoded file paths, no pubspec.yaml entry | Flutter's `assets:` in pubspec.yaml + `AssetSource()` | Asset bundle ensures files are packaged on all platforms; hardcoded paths fail on web or if project structure changes. |

**Key insight:** Metronome timing is unforgiving — even 20–50ms of extra latency (or jitter) becomes perceptible to the user. Do not attempt custom low-level audio scheduling or frame-based timing; use the ecosystem's proven packages.

---

## Runtime State Inventory

**Trigger:** Not a rename/refactor/migration phase. SKIPPED.

---

## Common Pitfalls

### Pitfall 1: Audio-Visual Drift Over Time

**What goes wrong:** Beat indicator dot lights up *before* or *after* the audio tick, or drifts further out of sync as the metronome runs for minutes.

**Why it happens:** Separate Timer callbacks for audio and visual updates can accumulate rounding errors or frame drops. The audio callback fires at precise millisecond intervals (via native layer), but the visual update (setState/Riverpod notification) may be delayed by UI frame scheduling.

**How to avoid:**
1. Use a single Timer loop for both audio playback *and* state update (don't separate them).
2. Use `Stopwatch.elapsedMilliseconds` (high-precision elapsed time) to calculate expected tick time, not cumulative Timer tick counts.
3. Visual updates trail audio by at most one UI frame (~16ms at 60 FPS); this is imperceptible and acceptable. Do not attempt frame-perfect synchronization.

**Warning signs:** User reports "the click and the light are off" after ~10 seconds of play, or on older devices.

### Pitfall 2: Low-Latency Mode Not Supported (Platform Mismatch)

**What goes wrong:** `PlayerMode.lowLatency` works on Android but is silently ignored on iOS, or vice versa; audio latency is unexpectedly high on one platform.

**Why it happens:** `audioplayers` v5+ maps `PlayerMode.lowLatency` to Android's `SoundPool` (true low-latency) but iOS's `AVAudioPlayer` is lower-latency by default. The underlying implementations are platform-specific; not all features map 1:1.

**How to avoid:**
1. Test on real devices (Android phone, iPhone). Simulator audio latency can differ by 100–200ms.
2. Read the `audioplayers` changelog and GitHub issues for platform-specific gotchas. [CITED: github.com/bluefireteam/audioplayers, issue #1489 reports PlayerMode + setReleaseMode interaction on Android]
3. Fallback gracefully: if audio fails to load or latency is unacceptable, disable the metronome with a polite error message; don't crash.

**Warning signs:** Tap test in debug mode: play a tick, note latency on different devices; if >100ms, document and warn user.

### Pitfall 3: BPM Change Doesn't Take Effect Immediately

**What goes wrong:** User drags the dial to 140 BPM, but the audio continues at 120 BPM for 1–2 more beats before snapping to new tempo.

**Why it happens:** If the Timer calculates the interval once at setup (e.g., `Duration(milliseconds: tickIntervalMs)`) and never recalculates, a BPM change after Timer creation has no effect until the Timer is cancelled and restarted.

**How to avoid:**
1. Do NOT precalculate the interval and embed it in the Timer. Instead, check the current BPM on *every* Timer tick and compare against elapsed time.
2. Use `Stopwatch` to track elapsed time across all ticks, independent of Timer's periodic schedule. Example: `if (stopwatch.elapsedMilliseconds >= nextTickTime) { playTick(...); nextTickTime += intervalMs; }`.

**Warning signs:** Tempo changes appear to lag by 500ms to 1 second.

### Pitfall 4: GestureDetector Drag Angle Calculation Wraps Around 180°

**What goes wrong:** User drags from left of dial to right; angle jumps from 180° to –180°, causing BPM to snap unexpectedly.

**Why it happens:** `atan2(dy, dx)` returns a value in [–π, π] (–180° to 180°). If the user's drag crosses the –180/+180 boundary, the angle has a discontinuity, and naïve angle-to-BPM mapping produces a jump.

**How to avoid:**
1. Map angle to a single continuous range (e.g., 0° to 360°) before interpolating to BPM. Example: `degrees = (atan2_result * 180 / π + 90) % 360`.
2. Clamp the final BPM to [40, 300], so out-of-range angles still produce valid BPM values.
3. Test the drag at the dial's boundary points (e.g., left, top, right, bottom) to ensure no jumps occur.

**Warning signs:** BPM flickers or jumps by 100+ when dragging across specific angles.

### Pitfall 5: Assets Not Bundled (pubspec.yaml Missing)

**What goes wrong:** App crashes with "Unable to find asset: audio/metronome_accent.wav" when attempting to load the sound.

**Why it happens:** The audio files are in the `assets/audio/` directory on disk, but pubspec.yaml does not declare them under `flutter: assets:`, so they are not included in the app bundle during build.

**How to avoid:**
1. Add to pubspec.yaml:
```yaml
flutter:
  assets:
    - assets/audio/
```
   (Trailing slash includes all files in that directory.)
2. Run `flutter pub get` after editing pubspec.yaml.
3. Verify assets appear in the build output: `flutter build apk --verbose 2>&1 | grep audio` (should see asset files listed).

**Warning signs:** "Unable to find asset" errors only on device; simulator may use a different asset cache that sometimes includes missing files by accident.

---

## Code Examples

Verified patterns from official sources and project conventions:

### Initialize Metronome Audio Service on Screen Entry

```dart
// lib/features/metronome/metronome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/metronome_provider.dart';
import 'audio/metronome_audio_service.dart';
import 'metronome_dial.dart';
import 'beat_indicator.dart';

class MetronomeScreen extends ConsumerStatefulWidget {
  final int? initialBpm; // Optional, from track.tempo or HomePage default (120)

  const MetronomeScreen({super.key, this.initialBpm});

  @override
  ConsumerState<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends ConsumerState<MetronomeScreen> {
  @override
  void initState() {
    super.initState();
    // Preload audio assets when screen enters
    Future.microtask(() async {
      await ref.read(metronomAudioServiceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metronomStateProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.metronomAppBarTitle), // "Metronome"
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dial with drag-to-BPM gesture
              MetronomDial(
                bpm: state.bpm,
                onBpmChanged: (newBpm) {
                  ref.read(metronomStateProvider.notifier).setBPM(newBpm);
                },
              ),
              const SizedBox(height: 32),
              // Beat indicator dots (4 dots)
              BeatIndicator(currentBeat: state.currentBeat),
              const SizedBox(height: 48),
              // Quick-adjust buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: '–5 BPM',
                    onPressed: () {
                      ref
                          .read(metronomStateProvider.notifier)
                          .setBPM(state.bpm - 5);
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: '–1 BPM',
                    onPressed: () {
                      ref
                          .read(metronomStateProvider.notifier)
                          .setBPM(state.bpm - 1);
                    },
                  ),
                  const SizedBox(width: 32),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '+1 BPM',
                    onPressed: () {
                      ref
                          .read(metronomStateProvider.notifier)
                          .setBPM(state.bpm + 1);
                    },
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: '+5 BPM',
                    onPressed: () {
                      ref
                          .read(metronomStateProvider.notifier)
                          .setBPM(state.bpm + 5);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.read(metronomStateProvider.notifier).togglePlay();
        },
        child: Icon(
          state.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
```

[VERIFIED: lib/features/home/home_screen.dart (lines 1–26), lib/features/tracks/track_detail_screen.dart (lines 13–29) — ConsumerWidget/ConsumerStatefulWidget pattern, ref.watch, ref.read usage in Cadence codebase]

### Beat Indicator Dots Widget

```dart
// lib/features/metronome/beat_indicator.dart
import 'package:flutter/material.dart';

class BeatIndicator extends StatelessWidget {
  final int currentBeat; // 0–3

  const BeatIndicator({required this.currentBeat});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: i == currentBeat
                  ? (i == 0 ? 16 : 12)
                  : (i == 0 ? 12 : 8),
              height: i == currentBeat
                  ? (i == 0 ? 16 : 12)
                  : (i == 0 ? 12 : 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == currentBeat
                    ? (i == 0 ? colorScheme.primary : colorScheme.outlineVariant)
                    : (i == 0 ? colorScheme.primary : colorScheme.outlineVariant)
                        .withAlpha(100),
              ),
            ),
          ),
      ],
    );
  }
}
```

[ASSUMED: AnimatedContainer for visual pulse; standard Flutter pattern for smooth transitions.]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single AudioPlayer for all sounds | Separate AudioPlayer per sound type (accent/regular) | audioplayers v4+ | Allows low-latency rapid retriggering; single player would cut off previous sound. |
| Frame-rate-dependent timing (Ticker) | Independent Timer loop + Stopwatch elapsed time | Flutter best practices (2020+) | Decouples audio timing from UI frame rate; survives frame drops and background throttling. |
| Manual audio asset management | Flutter asset bundle via pubspec.yaml | Flutter 1.0+ | Automatic platform-specific packaging; no hardcoded paths. |
| StateNotifier (Riverpod v1) | Notifier / AsyncNotifier (Riverpod 2.0+) | Riverpod 2.0 (2023) | Less boilerplate; modern code generation. Cadence already uses v2.6.1. |

**Deprecated/outdated:**
- **MediaPlayer (vs SoundPool on Android):** AudioPlayers' `PlayerMode.mediaPlayer` (default) targets long audio files. `PlayerMode.lowLatency` uses platform's rapid-fire sound API (SoundPool on Android, AVAudioPlayer on iOS). The old approach was to use MediaPlayer for everything; it has 100–500ms latency.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `audioplayers` v5.2.0+ with `PlayerMode.lowLatency` is available on pub.dev and supports Android + iOS | Standard Stack | If unavailable or broken: phase blocks until a viable audio package is found. Mitigation: verify package exists and has recent stable release before planning. |
| A2 | `Timer.periodic()` in Dart can sustain <20ms precision for ~10 calls/sec without significant drift on a typical phone | Common Pitfalls | If Dart Timers are less precise than expected: metronome may drift audibly over 5+ minutes. Mitigation: monitor elapsed time with Stopwatch, not Timer tick count. |
| A3 | Flutter's asset bundling with `pubspec.yaml` includes WAV and MP3 files without issues on Android/iOS | Common Pitfalls | If assets are excluded: app crashes at runtime. Mitigation: test asset loading on real device. |
| A4 | `atan2()` angle calculation for drag gesture works correctly across all quadrants without wraparound jumps | Code Examples | If angle mapping has a bug: BPM can snap unexpectedly during drag. Mitigation: test drag at boundary points (left, right, top, bottom of dial). |
| A5 | The existing Riverpod pattern (v2.6.1 with @riverpod class syntax) can handle real-time state updates (BPM, beat index) without performance issues | Architecture Patterns | If Riverpod state updates are too slow: visual indicators may lag audio by >1 frame. Mitigation: profile frame rate during playback; if <50 FPS, optimize state listener subscriptions. |

**If this table is empty:** [NONE — all claims in this research are contingent on the assumptions listed above.]

---

## Open Questions

1. **Exact placeholder audio asset choice for D-02**
   - What we know: User will supply real audio files later; Claude ships placeholders initially.
   - What's unclear: Should placeholder be a generated sine tone (simple but artificial), a stock click sound (more realistic), or silence (allows testing without audio)?
   - Recommendation: Use a simple generated sine-wave click (~400 Hz, 50ms envelope) for the accent and a softer sine-wave click (~300 Hz) for regular beats. This is unobtrusive, easy to replace, and lets the user hear the metronome even without custom audio files. Provide clear instructions in a README comment: "Replace `assets/audio/metronome_accent.wav` and `assets/audio/metronome_regular.wav` with your own audio files; format must be WAV or MP3."

2. **Audio asset loading error handling and fallback**
   - What we know: Assets must be preloaded at screen entry; if loading fails, audio service should not crash the app.
   - What's unclear: Should the metronome UI show a visual "audio unavailable" indicator, or silently degrade to visual-only mode?
   - Recommendation: Silently degrade. If `metronomAudioService.initialize()` throws, log the error and set a flag `_assetsLoaded = false`. The metronome UI still works (visual beats, dial, buttons), but no audio plays. Users can still practice with the visual pulse. This keeps the UX simple and doesn't block the feature.

3. **Tap-tempo feature for v2 (out of scope for Phase 18)**
   - What we know: User explicitly deferred tap-tempo to v2+.
   - What's unclear: Should the current implementation include a placeholder or stub for tap-tempo logic?
   - Recommendation: Do not stub tap-tempo in Phase 18. If v2 needs to add it, the planner will scope a separate phase. Avoid speculative code; keep Phase 18 focused.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | UI rendering (CustomPainter, GestureDetector, Material widgets) | ✓ | Latest stable (≥3.19) | — |
| Dart SDK | Timer, math, async primitives | ✓ | 3.12.2+ (included in Flutter) | — |
| Pub.dev packages | `audioplayers`, `flutter_riverpod` | ✓ | 5.2.0+, 2.6.1+ | — |
| Android NDK (for native audio on Android) | audioplayers low-latency SoundPool access | ✓ | Included in Android SDK setup | — |
| Xcode (for iOS audio runtime) | audioplayers low-latency AVAudioPlayer access | ✓ | Included in Xcode installation | — |

**Missing dependencies with no fallback:** None — all required tools and libraries are either built-in to Flutter or standard pub.dev packages.

**Missing dependencies with fallback:** None.

---

## Validation Architecture

> Skip this section entirely if workflow.nyquist_validation is explicitly set to false in .planning/config.json. [Config check: "nyquist_validation": true] — section is INCLUDED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) + Riverpod testing utilities |
| Config file | — (Flutter uses no config file; tests run via `flutter test` command) |
| Quick run command | `flutter test test/features/metronome/ -j 1` |
| Full suite command | `flutter test --coverage` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| METR-01 | Metronome screen opens from Homepage "Tools" button with 120 BPM | Integration | `flutter test test/features/home/home_screen_test.dart -k 'metronome button'` | ❌ Wave 0 (new test file) |
| METR-02 | Metronome screen opens from track detail AppBar action with track.tempo prefilled (or hidden if tempo null) | Integration | `flutter test test/features/tracks/track_detail_screen_test.dart -k 'metronome entry'` | ❌ Wave 0 (extend existing test) |
| METR-03 | Audio tick plays in sync with beat indicator; accent beat 1 is louder; 4/4 cycle repeats | Unit/Widget | `flutter test test/features/metronome/metronome_state_test.dart::ticksPlayInSequence` | ❌ Wave 0 (new test file) |
| METR-04 | Dragging dial updates BPM live; quick-adjust buttons ±1/±5 work; BPM clamped to [40, 300] | Widget | `flutter test test/features/metronome/metronome_dial_test.dart` | ❌ Wave 0 (new test file) |

### Sampling Rate
- **Per task commit:** `flutter test test/features/metronome/ -j 1` (metronome-specific suite only, ~10–15s)
- **Per wave merge:** `flutter test --coverage` (full suite; includes all metronome + existing tests)
- **Phase gate:** Full suite green + coverage ≥80% for new code before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/features/metronome/metronome_state_test.dart` — unit tests for beat scheduling, BPM changes, play/pause state transitions
- [ ] `test/features/metronome/metronome_dial_test.dart` — widget tests for drag gesture, angle-to-BPM mapping, visual updates
- [ ] `test/features/metronome/metronome_audio_service_test.dart` — mock `AudioPlayer`, verify `playTick()` calls correct player (accent vs regular)
- [ ] `test/features/home/home_screen_test.dart` — extend existing tests to verify "Tools" section is present and "Metronome" button navigates with BPM=120
- [ ] `test/features/tracks/track_detail_screen_test.dart` — extend existing tests to verify metronome icon appears only when `track.tempo != null`
- [ ] `test/integration/metronome_e2e_test.dart` — end-to-end: open metronome from homepage, drag dial, press play, verify beat indicators cycle

---

## Security Domain

> Required when `security_enforcement` is enabled (config: "security_enforcement": true). ✓ ENABLED.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture | No | Metronome is a local offline-capable UI feature; no backend or API calls involved |
| V2 Authentication | No | Metronome is usable by any authenticated user; no new auth scopes needed |
| V3 Session Management | No | No session-specific state in metronome |
| V4 Access Control | No | Metronome is a shared feature (no owner-only restrictions) |
| V5 Input Validation | Yes | Dial drag gesture produces numeric BPM value; validate range [40, 300] before state update |
| V6 Cryptography | No | No sensitive data or encryption in metronome |
| V7 Errors, Logging | Yes | Audio load failures should be logged but not expose file paths in user-facing error messages |
| V8 Data Protection | No | Metronome stores no persistent data |
| V9 Communications | No | No network calls from metronome UI |
| V10 Malicious Code | No | Metronome has no plugin/extension mechanism |
| V11 Business Logic | No | No complex business rules specific to metronome |
| V12 File Upload | No | No file uploads |
| V13 API & Web Services | No | No API calls (metronome is offline-first) |

### Known Threat Patterns for Flutter

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| BPM input not validated | Tampering | Clamp drag-calculated BPM to [40, 300] before state update; quick-adjust buttons already bounded by logic |
| Audio asset path injection (if user could supply file path) | Tampering | Asset path is hardcoded in code (`AssetSource('audio/metronome_accent.wav')`); user cannot influence it via UI. Audio file replacement is manual (file drop), not user-controlled. |
| Denial of Service via rapid BPM changes | Denial | Drag gesture generates many BPM updates; Riverpod state listener may thrash. Mitigation: debounce dial updates (e.g., only notify every 50ms) or accept that rapid changes are an expected use case (user is dragging). No security risk. |
| Audio file missing → crash | Availability | Wrap `AssetSource().load()` in try-catch; log error and set flag; UI gracefully degrades (visual-only mode, no audio). User sees no error dialog; metronome still works. |

**Security assessment:** Phase 18 is low-risk. Metronome is a local UI feature with no network calls, no user input parsing, and no persistent data. The only security consideration is validating the BPM range before state updates (standard input validation, not a special security concern).

---

## Sources

### Primary (HIGH confidence)

- [pub.dev/packages/audioplayers](https://pub.dev/packages/audioplayers) — Verified latest stable version 5.2.0+; PlayerMode.lowLatency documentation; asset loading patterns
- [github.com/bluefireteam/audioplayers/getting_started.md](https://github.com/bluefireteam/audioplayers/blob/main/getting_started.md) — Official setup guide; PlayerMode and AssetSource usage
- [flutter.dev/ui/assets/assets-and-images](https://docs.flutter.dev/ui/assets/assets-and-images) — Flutter asset bundling; pubspec.yaml declaration; supported formats
- [Cadence codebase: lib/providers/navigation_provider.dart, lib/features/home/home_screen.dart](file:///home/bulat.khafizov/projects/personal/cadence/client) — Verified Riverpod @riverpod class pattern, ConsumerWidget usage, project conventions [VERIFIED: ./.claude/CLAUDE.md, existing code reading]

### Secondary (MEDIUM confidence)

- [github.com/bluefireteam/audioplayers/issues/1489](https://github.com/bluefireteam/audioplayers/issues/1489) — PlayerMode.lowLatency Android-specific behavior; setReleaseMode interaction
- [blog.theodo.com/2019/08/custom-flutter-input-knob-with-gesturedetector-tutorial/](https://blog.theodo.com/2019/08/custom-flutter-input-knob-with-gesturedetector-tutorial/) — CustomPainter + drag gesture pattern; atan2 angle calculation
- [Medium: flutter-riverpod-2-0](https://medium.com/@alokkumarmaurya5556/master-riverpod-in-flutter-2025-a-complete-beginner-friendly-deep-practical-state-management-57536279483f) — Riverpod 2.0 Notifier pattern for state management (project matches this version)
- [Medium: flutter-timer-precision](https://medium.com/geekculture/flutter-case-study-timer-precision-a1154b431e8) — Timer vs. Ticker precision discussion; Stopwatch-based elapsed time tracking best practice
- [itnext.io/building-a-beat-machine-in-flutter](https://itnext.io/building-a-beat-machine-in-flutter-2b25b27d5a5b) — Beat machine implementation; timer-based scheduling independent of UI frame rate

### Tertiary (LOW confidence)

- WebSearch results on "Flutter CustomPainter drag rotation dial" — General atan2 pattern for dial controls (multiple sources, no single authority)
- WebSearch results on "Flutter visual frame sync audio playback" — General audio-visual sync concepts; Flutter-specific implementation details sparse

---

## Metadata

**Confidence breakdown:**
- Standard stack (audioplayers, Riverpod, Flutter built-ins): MEDIUM → officially documented, but specific low-latency edge cases on iOS/Android require device testing
- Architecture (Riverpod provider state, Timer loop, Stopwatch elapsed time): MEDIUM → pattern is established; exact timing precision depends on platform and device load
- Audio-visual sync strategy: MEDIUM → conceptually sound (independent Timer + Stopwatch); requires testing to confirm imperceptible drift
- CustomPainter + gesture (drag → angle → BPM): MEDIUM → pattern proven in other Flutter apps; angle calculation standard, but dial visual styling is discretionary
- Pitfalls (drift, platform mismatches, asset bundling): MEDIUM → drawn from common Flutter audio/timing issues; specific manifest depends on device and OS version

**Research date:** 2026-08-27
**Valid until:** 2026-09-10 (14 days — metronome timing and audio APIs are stable, but new audioplayers releases or Flutter SDK changes may affect edge cases)

---

*Research completed: 2026-08-27*
*Domain: Audio playback timing, gesture-based UI controls, real-time beat synchronization*
*Confidence: MEDIUM — ready for planning*
