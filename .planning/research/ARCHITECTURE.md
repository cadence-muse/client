# Architecture: Metronome Integration for v1.3

**Project:** Cadence v1.3 Quality of Life  
**Feature:** Metronome Tool (audio tick + visual pulse, tempo selector)  
**Researched:** 2026-08-27  
**Confidence:** HIGH

## Executive Summary

The metronome is a purely client-side, session-scoped feature with zero backend dependencies. It integrates cleanly into Cadence's existing Riverpod + `lib/features/` architecture via:

1. **Stateless providers** (not AsyncNotifier) for metronome runtime state — no caching or API calls needed
2. **Single `MetronomeScreen`** in `lib/features/metronome/` following the existing feature directory pattern
3. **Two entry points** via `MaterialPageRoute.push()` with optional tempo parameter:
   - Homepage "Tools" section (new button, default 120 BPM)
   - Track detail screen (button, tempo pre-filled from `track['tempo']`)
4. **Reusable route builder** for tempo parameter passing without named routes
5. **Build-last ordering** is safe — zero blocking dependencies on other v1.3 items (WR-01 fix, API sync, song→track rename, date picker)

The feature requires two new provider files (`metronome_provider.dart`) and one new screen directory (`lib/features/metronome/`), plus minor modifications to `home_screen.dart` and `track_detail_screen.dart` to add entry points.

---

## Architecture Overview

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│  HomeScreen / TrackDetailScreen (existing features)      │
│  ├─ "Launch Metronome" button                           │
│  └─ Navigator.push(context, route)                      │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  MetronomeScreen (lib/features/metronome/)              │
│  ├─ Watches metronomeStateProvider                      │
│  ├─ Renders:                                             │
│  │  ├─ Large circular tempo display (e.g., 120 BPM)    │
│  │  ├─ ±5 / ±1 tempo adjustment buttons                │
│  │  ├─ Play / Pause button                              │
│  │  └─ Visual beat indicator (0-3, accent on beat 1)   │
│  └─ Calls ref.read(metronomeStateProvider.notifier)    │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  Riverpod Providers (lib/providers/metronome_provider)  │
│  ├─ metronomeStateProvider                              │
│  │  └─ State: {tempo, isPlaying, currentBeat}          │
│  ├─ metronomeTimerProvider                              │
│  │  └─ Manages interval timer lifecycle                 │
│  └─ metronomeServiceProvider                            │
│     └─ Audio generation (plugin-backed)                 │
└─────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  MetronomeService (lib/services/metronome_service.dart) │
│  ├─ playTick()        → audio output (normal beat)      │
│  ├─ playAccent()      → audio output (beat 1)           │
│  ├─ dispose()         → cleanup                         │
│  └─ Backed by audioplayers plugin                       │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

**Play Sequence (user taps Play):**

```
MetronomeScreen → ref.read(metronomeStateProvider.notifier).play()
    ↓
metronomeStateProvider.notifier updates state: {isPlaying: true}
    ↓
metronomeTimerProvider kicks off interval timer (beat duration from BPM)
    ↓
Each beat fires → ref.read(metronomeServiceProvider).playTick(beat)
    ↓
MetronomeService.playTick() → audio plugin plays sound
    ↓
metronomeStateProvider notifier increments currentBeat (0→1→2→3→0)
    ↓
MetronomeScreen rebuilds, visual indicator animates to new beat
```

**Tempo Change (user taps ±5):**

```
MetronomeScreen → ref.read(metronomeStateProvider.notifier).setTempo(newBPM)
    ↓
Provider state updates: {tempo: newBPM}
    ↓
If isPlaying is true, metronomeTimerProvider must re-compute interval
    ↓
Screen rebuilds with new tempo display
```

---

## New Components (Build Order)

### Phase A: Providers Layer

**File:** `lib/providers/metronome_provider.dart`

Create a new file with three providers:

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'metronome_provider.g.dart';

/// Metronome playback state (non-persisted, session-scoped).
/// Structure: {tempo: int (60-300 BPM), isPlaying: bool, currentBeat: int (0-3)}
@riverpod
class MetronomeState extends _$MetronomeState {
  static const int _minTempo = 60;
  static const int _maxTempo = 300;
  static const int _defaultTempo = 120;

  @override
  Map<String, dynamic> build() => {
    'tempo': _defaultTempo,
    'isPlaying': false,
    'currentBeat': 0,
  };

  /// Set tempo with bounds enforcement.
  void setTempo(int newTempo) {
    final clamped = newTempo.clamp(_minTempo, _maxTempo);
    state = {...state, 'tempo': clamped};
  }

  /// Increment tempo by delta, with bounds enforcement.
  void adjustTempo(int delta) {
    final current = state['tempo'] as int;
    setTempo(current + delta);
  }

  /// Start playback.
  void play() {
    state = {...state, 'isPlaying': true};
  }

  /// Pause playback without resetting beat position.
  void pause() {
    state = {...state, 'isPlaying': false};
  }

  /// Advance beat (0→1→2→3→0). Called by the timer on each tick.
  void advanceBeat() {
    final current = state['currentBeat'] as int;
    state = {...state, 'currentBeat': (current + 1) % 4};
  }

  /// Reset beat to 0 (called on pause or when tempo changes).
  void resetBeat() {
    state = {...state, 'currentBeat': 0};
  }
}

/// Timer stream that fires once per beat (interval = 60,000 ms / tempo).
/// Only active if metronomeStateProvider.isPlaying is true.
@riverpod
Stream<int> metronomeTimer(Ref ref) async* {
  final metronomeState = ref.watch(metronomeStateProvider);
  final isPlaying = metronomeState['isPlaying'] as bool;
  final tempo = metronomeState['tempo'] as int;

  if (!isPlaying) return;

  final beatDurationMs = (60000 / tempo).round();
  final timer = Timer.periodic(
    Duration(milliseconds: beatDurationMs),
    (timer) {},
  );

  ref.onDispose(() {
    timer.cancel();
  });

  yield* Stream.periodic(Duration(milliseconds: beatDurationMs)).map((i) => i);
}

/// Service provider for audio playback (lazily instantiated once).
/// Delegates to MetronomeService for audio generation.
@riverpod
MetronomeService metronomeService(Ref ref) {
  final service = MetronomeService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
}
```

**Key Design Decisions:**

1. **State shape is a plain `Map<String, dynamic>`** — mirrors existing `BandsListData`, `TrackListData` patterns in codebase
2. **No AsyncNotifier** — metronome has zero network/persistence, so simple `@riverpod` class suffices
3. **`metronomeTimer` is a reactive `Stream`** that watches `metronomeStateProvider` and re-creates the interval whenever `isPlaying` flips
4. **Bounds enforcement** (`_minTempo`, `_maxTempo`) in setters — keeps invalid states impossible

---

### Phase B: Service Layer (Audio Generation)

**File:** `lib/services/metronome_service.dart`

```dart
import 'package:audioplayers/audioplayers.dart';

class MetronomeService {
  late AudioPlayer _audioPlayer;
  bool _initialized = false;

  MetronomeService() {
    _initialize();
  }

  void _initialize() {
    _audioPlayer = AudioPlayer();
    _initialized = true;
  }

  /// Play an accented tick (beat 1 of 4/4).
  /// Asset should be a distinct sound (e.g., higher pitch, louder).
  Future<void> playAccent() async {
    if (!_initialized) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/metronome_accent.wav'));
    } catch (_) {
      // Silent fallback if audio file not found or plugin unavailable
    }
  }

  /// Play a regular tick (beats 2-4 of 4/4).
  Future<void> playTick() async {
    if (!_initialized) return;
    try {
      await _audioPlayer.play(AssetSource('sounds/metronome_tick.wav'));
    } catch (_) {
      // Silent fallback
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
```

**Notes:**

- Requires `audioplayers` package in `pubspec.yaml`
- Audio assets (`sounds/metronome_accent.wav`, `sounds/metronome_tick.wav`) must exist in `assets/` directory
- Fallback behavior (catch-silently) allows graceful degradation if audio init fails

---

### Phase C: UI Layer — MetronomeScreen

**File:** `lib/features/metronome/metronome_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/metronome_provider.dart';

class MetronomeScreen extends ConsumerStatefulWidget {
  const MetronomeScreen({
    super.key,
    this.initialTempo,
  });

  /// Optional initial tempo passed from entry point (e.g., track's tempo).
  /// Defaults to 120 if not provided.
  final int? initialTempo;

  @override
  ConsumerState<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends ConsumerState<MetronomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize tempo from parameter or default.
    if (widget.initialTempo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(metronomeStateProvider.notifier).setTempo(widget.initialTempo!);
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeStateProvider);
    final tempo = state['tempo'] as int;
    final isPlaying = state['isPlaying'] as bool;
    final currentBeat = state['currentBeat'] as int;
    final l10n = AppLocalizations.of(context)!;

    // Listen to timer to advance beats
    ref.listen<AsyncValue<int>>(metronomeTimerProvider, (previous, next) {
      if (next.hasValue && next.value != previous?.value) {
        ref.read(metronomeStateProvider.notifier).advanceBeat();
        final beat = ref.read(metronomeStateProvider)['currentBeat'] as int;
        final service = ref.read(metronomeServiceProvider);
        if (beat == 0) {
          service.playAccent();
        } else {
          service.playTick();
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.metronomeTitle),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large circular tempo display
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$tempo',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    Text(
                      'BPM',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Beat indicator (0-3, accent on beat 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final isActive = currentBeat == i;
                final isAccent = i == 0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? (isAccent
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.secondary)
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                );
              }),
            ),
            const SizedBox(height: 48),

            // Tempo adjustment buttons (±5, ±1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    ref.read(metronomeStateProvider.notifier).adjustTempo(-5);
                  },
                  child: const Text('−5'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(metronomeStateProvider.notifier).adjustTempo(-1);
                  },
                  child: const Text('−1'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(metronomeStateProvider.notifier).adjustTempo(1);
                  },
                  child: const Text('+1'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(metronomeStateProvider.notifier).adjustTempo(5);
                  },
                  child: const Text('+5'),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Play / Pause button
            FloatingActionButton.large(
              onPressed: isPlaying
                  ? () => ref.read(metronomeStateProvider.notifier).pause()
                  : () => ref.read(metronomeStateProvider.notifier).play(),
              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Key Design Decisions:**

1. **`ConsumerStatefulWidget`** — needed to set initial tempo in `initState`
2. **`ref.listen<AsyncValue<int>>(metronomeTimerProvider, ...)`** listens to timer ticks and advances beat + plays sound
3. **Visual beat indicator** is a row of 4 circles — active beat highlighted, beat 0 (accent) is a different color
4. **Tempo adjustment buttons** are inline (±5, ±1) — quick actions matching the spec

---

## Integration Points

### 1. HomePage "Tools" Section Entry

**File:** `lib/features/home/home_screen.dart`

Add import:
```dart
import '../metronome/metronome_screen.dart';
```

In `_buildContent()`, after the Quick Actions section, add:

```dart
const SizedBox(height: 32),
Text(
  l10n.homeToolsTitle,
  style: Theme.of(context).textTheme.headlineSmall,
),
const SizedBox(height: 16),
ElevatedButton.icon(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MetronomeScreen(),
      ),
    );
  },
  icon: const Icon(Icons.music_note),
  label: Text(l10n.homeToolsMetronome),
),
```

---

### 2. TrackDetailScreen Entry Point

**File:** `lib/features/tracks/track_detail_screen.dart`

Add import:
```dart
import '../metronome/metronome_screen.dart';
```

In AppBar actions (after Edit button), add:

```dart
if (currentTrack != null)
  IconButton(
    icon: const Icon(Icons.music_note),
    tooltip: l10n.trackDetailMetronomeTooltip,
    onPressed: () {
      final tempo = currentTrack['tempo'] as int?;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MetronomeScreen(
            initialTempo: tempo ?? 120,
          ),
        ),
      );
    },
  ),
```

---

### 3. Localization Strings

**File:** `lib/l10n/app_en.arb` (add entries)

```json
{
  "metronomeTitle": "Metronome",
  "homeToolsTitle": "Tools",
  "homeToolsMetronome": "Metronome",
  "trackDetailMetronomeTooltip": "Open metronome with this track's tempo"
}
```

**File:** `lib/l10n/app_ru.arb`

```json
{
  "metronomeTitle": "Метроном",
  "homeToolsTitle": "Инструменты",
  "homeToolsMetronome": "Метроном",
  "trackDetailMetronomeTooltip": "Открыть метроном с темпом трека"
}
```

Then run `flutter gen-l10n` to regenerate `AppLocalizations`.

---

## Build Order and Dependency Analysis

Since the metronome has **zero blocking dependencies** on other v1.3 items:

| Item | Depends On Metronome? | Metronome Depends On? |
|------|----------------------|----------------------|
| WR-01 (invite-code copy) | No | No |
| API sync (SearchQuery) | No | No |
| song→track rename | No | No |
| Date picker | No | No |
| **Metronome** | — | **No external deps** |

### Suggested Build Order

1. **First:** Implement provider layer (`metronome_provider.dart`)
2. **Second:** Implement service layer (`metronome_service.dart`)
3. **Third:** Implement UI layer (`MetronomeScreen`)
4. **Fourth:** Wire entry points (`home_screen.dart`, `track_detail_screen.dart`)
5. **Fifth:** Add localization strings and regenerate l10n

**Why build last in the milestone:** The feature has zero dependencies, so it can be built at any point. Building it last means other features are stable and less likely to require refactoring.

---

## Technical Decisions & Tradeoffs

### State Management: `@riverpod` Notifier vs. AsyncNotifier

**Decision:** Use simple `@riverpod` Notifier (not AsyncNotifier).

**Rationale:**
- No network calls or async I/O on state path
- No caching or persistence (session-scoped only)
- `AsyncNotifier` is overkill and would complicate code
- Existing patterns (`ThemeController`) show Notifier is appropriate here

---

### Timer Implementation: Riverpod Stream vs. Dart Timer

**Decision:** Use a Riverpod `Stream` provider (`metronomeTimerProvider`) that wraps a Dart `Timer`.

**Rationale:**
- Reactive: re-creates timer automatically when `isPlaying` flips
- Disposal: Riverpod's `ref.onDispose` cleans up the timer
- Testable: Stream can be stubbed in tests
- Follows existing codebase patterns (`connectivityProvider` is a Stream)

---

### Audio Playback: `audioplayers` Plugin

**Decision:** Use `audioplayers` plugin with pre-recorded `.wav` assets.

**Rationale:**
- Standard choice for cross-platform audio in Flutter
- Handles web fallback gracefully
- Asset-based playback is simpler than on-device synthesis
- Silent failure is acceptable (visual indicator still works)

---

### Entry Point: Named Routes vs. MaterialPageRoute.push()

**Decision:** Use `MaterialPageRoute.push()` with optional `initialTempo` parameter.

**Rationale:**
- Existing codebase has no named-route system
- Simple and explicit for passing tempo parameter
- Consistent with existing screens (EditTrackScreen, CreateBandScreen)

---

### Tempo Bounds: 60–300 BPM

**Decision:** Enforce min 60 BPM, max 300 BPM.

**Rationale:**
- 60 BPM is the slowest reasonable tempo for most genres
- 300 BPM is the fastest reasonable upper bound
- Clamping prevents invalid state

---

### 4/4 Only (No Time Signature Selection)

**Decision:** Hardcode 4/4 time, no UI selection.

**Rationale:**
- Spec explicitly states "4/4 only with accented beat 1"
- 4/4 is most common; adding time-sig selection adds complexity for minimal gain
- Feature scope is "quick metronome tool," not a full DAW

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Timer fires during screen rebuild, causing jank | `ref.listen()` is async-safe; audio playback runs on background thread via audioplayers |
| Initial tempo parameter invalid or missing | Default to 120 in provider; `setTempo()` clamps bounds |
| Audio assets missing on device | Silent fallback in `playTick()` / `playAccent()`; visual indicator still works |
| Screen popped while timer active | `ref.onDispose` cancels timer on screen exit; cleanup automatic |
| Multiple MetronomeScreen instances open | Each gets its own state; only the top-most will play sounds (as expected) |

---

## Files to Create / Modify

### New Files

| File | Purpose |
|------|---------|
| `lib/providers/metronome_provider.dart` | State, timer, service providers |
| `lib/features/metronome/metronome_screen.dart` | Main UI component |
| `lib/services/metronome_service.dart` | Audio playback wrapper |
| `assets/sounds/metronome_accent.wav` | Audio asset (beat 1) |
| `assets/sounds/metronome_tick.wav` | Audio asset (beats 2-4) |

### Modified Files

| File | Change |
|------|--------|
| `lib/features/home/home_screen.dart` | Add "Tools" section with Metronome button |
| `lib/features/tracks/track_detail_screen.dart` | Add Metronome button with tempo pre-fill |
| `lib/l10n/app_en.arb` | Add metronome strings |
| `lib/l10n/app_ru.arb` | Add metronome strings (Russian) |
| `pubspec.yaml` | Add `audioplayers` dependency |

---

## No Breaking Changes

- **Existing providers:** Not modified
- **Existing screens:** Append-only (new buttons, no refactoring)
- **Existing navigation:** No changes to routing system
- **Existing state:** Metronome state is siloed in `metronomeStateProvider`; no cross-feature pollution
- **Existing APIs:** No API calls; zero impact on offline caching, cache service, or authentication

---

## Summary

The metronome integrates cleanly as a self-contained feature with:
- **No architectural changes** to existing code
- **Minimal new dependencies** (just `audioplayers` package)
- **Clear separation of concerns** (providers, service, UI)
- **Safe to build last** in v1.3 (zero blocking dependencies)
- **Reusable patterns** that mirror existing screens and providers in the codebase

The feature is a textbook example of "add new feature without refactoring existing code" — precisely what the existing architecture is designed for.
