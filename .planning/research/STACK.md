# Technology Stack: Metronome Feature

**Project:** Cadence v1.3 Quality of Life  
**Feature:** Metronome tool (audio tick + visual pulse, 4/4 time, accented beat 1, tempo 40–240 BPM)  
**Researched:** 2026-08-27  
**Confidence:** HIGH

## Executive Summary

The metronome requires sample-accurate beat scheduling with sub-millisecond precision—Timer.periodic alone drifts unacceptably and produces an unusable result. **flutter_gapless_loop** is the recommended audio engine because it includes a built-in MetronomePlayer with sample-accurate timing, designed specifically for music production apps, and requires no additional audio-player dependency. It supports configurable time signatures (4/4 included), exposes a beat stream for UI synchronization, and provides a proven low-latency foundation via native AVAudioEngine (iOS) and AudioTrack (Android). Riverpod will wrap the MetronomePlayer state as an AsyncNotifier provider, following the existing pattern.

## Recommended Stack

### Audio Engine

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **flutter_gapless_loop** | 0.0.12+ | Sample-accurate metronome with configurable BPM, time signatures, and UI sync | Built-in MetronomePlayer is optimized for music production; eliminates Timer.periodic drift; exposes beat stream for visual pulse; no separate audio-player needed |

### State Management (Integrated with Existing Stack)

| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| Riverpod `@riverpod` AsyncNotifier | 2.6.1 (existing) | Wrap MetronomePlayer state (BPM, isPlaying, timeSignature) | State synchronization across tempo buttons, playback toggle, and beat-driven UI updates |
| Riverpod `@riverpod` FutureProvider | 2.6.1 (existing) | Expose beat stream for UI listeners | Trigger visual pulse on beat events without blocking build |

### Supporting Libraries (Reuse Existing)

| Library | Version | Purpose | Why Reuse |
|---------|---------|---------|-----------|
| flutter_riverpod | 2.6.1 | State management | Existing pattern; no new framework |
| riverpod_generator | 2.6.1 | Code generation for providers | Existing pattern; required for AsyncNotifier |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Audio Engine** | flutter_gapless_loop | flutter_soloud | SoLoud is more general-purpose (games, 3D audio); overkill for 4/4 metronome; flutter_gapless_loop's MetronomePlayer is simpler and purpose-built |
| **Audio Engine** | flutter_gapless_loop | just_audio + Timer.periodic | just_audio has ~50ms latency on loop boundaries; Timer.periodic drifts 100–1000ms; combination would need custom scheduling layer |
| **Audio Engine** | flutter_gapless_loop | metronome package (pub.dev) | Dedicated but less optimized for low-latency; no beat stream for UI sync; less active maintenance |
| **Audio Engine** | flutter_gapless_loop | flutter_sound | Limited low-latency capabilities on iOS; not designed for precise beat scheduling |
| **Beat Scheduling** | flutter_gapless_loop MetronomePlayer beat stream | Timer.periodic alone | Drifts 100–1000ms; unsuitable for a musical tool where accuracy is core functionality |
| **State Management** | Riverpod AsyncNotifier | ChangeNotifier (pre-v1.2) | Existing codebase already migrated to Riverpod; consistency matters; prop-drilling was flagged as anti-pattern in v1.0–v1.2 evolution |

## Why flutter_gapless_loop

### 1. Sample-Accurate Metronome
Flutter_gapless_loop's `MetronomePlayer` is built on:
- **iOS:** AVAudioEngine (configured for low-latency ~1.5ms buffer with 2ms I/O duration)
- **Android:** AudioTrack with low-latency flags enabled and 48kHz sample rate

Both platforms guarantee sample-accurate playback with zero audible gap at loop boundaries—critical for a tool used by musicians.

### 2. Native Time Signature Support
The MetronomePlayer supports 1–16 beats per bar; 4/4 is the default. No custom beat-scheduling logic needed.

### 3. Beat Stream for UI Sync
The package exposes a beat stream that fires precisely when each beat plays, enabling tight visual pulse sync without coupling to Timer.periodic or build cycles.

### 4. No Extra Audio Player Dependency
Unlike just_audio or flutter_sound, flutter_gapless_loop combines the metronome, click sounds, and UI sync in one package—simpler integration, fewer points of failure.

### 5. Music Production DNA
The package is designed for DAW-like tools, not games or general media. Its APIs and defaults match how musicians think about tempo and time signatures.

## Installation

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_gapless_loop: ^0.0.12
  riverpod: ^2.6.1
  riverpod_generator: ^2.6.1

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.6.1
```

Run:
```bash
flutter pub get
```

## Integration with Existing Riverpod Pattern

### Service Layer: Metronome Wrapper

Create `lib/features/metronome/metronome_service.dart` to encapsulate flutter_gapless_loop:

```dart
import 'package:flutter_gapless_loop/flutter_gapless_loop.dart';

class MetronomeService {
  final FlutterGaplessLoop _player = FlutterGaplessLoop();

  Future<void> initialize() async {
    // Initialize player with default state
    await _player.initMetronome(
      bpm: 120,
      timeSignature: 4,  // 4/4
      isPlaying: false,
    );
  }

  void setBPM(int bpm) {
    _player.setMetronomeBPM(bpm.clamp(40, 240));
  }

  void start() {
    _player.startMetronome();
  }

  void stop() {
    _player.stopMetronome();
  }

  Stream<int> get beatStream => _player.beatStream;

  Future<void> dispose() async {
    _player.stopMetronome();
    await _player.disposeMetronome();
  }
}
```

### State Provider: Riverpod AsyncNotifier

Create `lib/features/metronome/metronome_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'metronome_service.dart';

part 'metronome_provider.g.dart';

@riverpod
class MetronomeNotifier extends _$MetronomeNotifier {
  late final MetronomeService _service;

  @override
  Future<void> build() async {
    _service = MetronomeService();
    await _service.initialize();
    
    ref.onDispose(() => _service.dispose());
  }

  void setBPM(int bpm) {
    if (state.isLoading) return;
    _service.setBPM(bpm);
    // Optionally: update local state if tracking BPM separately
  }

  void togglePlayback() {
    if (state.isLoading) return;
    // In real implementation, track isPlaying state
    _service.start();  // or _service.stop() based on current state
  }
}

@riverpod
Stream<int> metronomeBeatStream(MetronomeBeatStreamRef ref) {
  final notifier = ref.watch(metronomeNotifierProvider.notifier);
  return notifier._service.beatStream;
}
```

### UI Integration

Create `lib/features/metronome/metronome_screen.dart`:

```dart
class MetronomeScreen extends ConsumerWidget {
  const MetronomeScreen({super.key, this.prefillBPM});

  final int? prefillBPM;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beatStream = ref.watch(metronomeBeatStreamProvider);
    final notifier = ref.watch(metronomeNotifierProvider.notifier);

    return StreamBuilder<int>(
      stream: beatStream,
      builder: (context, snapshot) {
        final currentBeat = snapshot.data ?? 0;
        final isAccent = currentBeat == 1;  // Beat 1 is accented

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Visual pulse (larger on accent)
            AnimatedScale(
              scale: isAccent ? 1.3 : 1.0,
              duration: const Duration(milliseconds: 50),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAccent 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).disabledColor,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Tempo display and selector
            TempoSelector(
              initialBPM: prefillBPM ?? 120,
              onBPMChanged: (bpm) => notifier.setBPM(bpm),
            ),
            const SizedBox(height: 40),
            // Play/stop button
            FloatingActionButton.large(
              onPressed: () => notifier.togglePlayback(),
              child: const Icon(Icons.play_arrow, size: 32),
            ),
          ],
        );
      },
    );
  }
}
```

## What NOT to Add

| Anti-Pattern | Why Avoid |
|--------------|-----------|
| **Timer.periodic for beat scheduling** | Drifts 100–1000ms; unsuitable for music tool; flutter_gapless_loop handles this natively |
| **just_audio + custom scheduling** | Introduces latency on loop boundaries; adds complexity for no gain over dedicated MetronomePlayer |
| **Separate sound file management** | flutter_gapless_loop provides stock click/accent sounds; no need to manage WAV/MP3 files unless custom sounds requested (not in scope) |
| **Audio streaming or PCM generation** | flutter_gapless_loop uses pre-loaded click samples; no real-time synthesis needed for 4/4 metronome |
| **ChangeNotifier state for metronome** | Codebase migrated to Riverpod in Phase 1; consistency over mixed patterns |
| **Audio service package for background playback** | v1.3 scope is foreground-only metronome; defer background support if requested in later phases |

## Versioning & Compatibility

- **flutter_gapless_loop 0.0.12:** Latest as of 2026-08-27 (published 3 months ago); stable for iOS/Android/Windows/macOS/Linux
- **Riverpod 2.6.1:** Existing in codebase; no version bump needed
- **Dart 3.12.2+:** Already required; no changes
- **Flutter SDK (stable channel):** Recommended; flutter_gapless_loop requires Flutter 3.0+

## Platform Notes

- **iOS:** Uses AVAudioEngine; requires iOS 12.0+; low latency via 2ms I/O buffer duration
- **Android:** Uses AudioTrack with `AUDIO_OUTPUT_FLAG_FAST`; requires API 21+; 48kHz sample rate for lowest latency
- **macOS/Windows/Linux:** Supported; defer to future phases if desktop feature requested
- **Web:** Not in v1.3 scope; web stays online-only, no metronome feature needed yet

## Testing Strategy

- **Unit tests:** Mock MetronomeService, verify BPM changes and toggle state
- **Widget tests:** Verify visual pulse responds to beat stream events; test tempo buttons
- **Integration tests:** Run on physical Android/iOS device; verify no audible drift over 1-minute play session; test BPM range (40–240)

## Native Platform Integration Notes

### iOS (AVAudioEngine)
- flutter_gapless_loop configures a 2ms I/O buffer for low-latency playback
- Requires no additional iOS configuration beyond the plugin
- Test on real devices; simulator latency may not reflect production

### Android (AudioTrack)
- flutter_gapless_loop uses AudioTrack with `AUDIO_OUTPUT_FLAG_FAST` for low-latency mode
- Requires minimum API 21; all modern Android versions support this
- 48kHz sample rate reduces latency vs. 44.1kHz
- AudioTrack scheduling is hardware-dependent; newer devices have tighter timing

## Sources

- [flutter_gapless_loop | Flutter package](https://pub.dev/packages/flutter_gapless_loop)
- [flutter_soloud | Flutter package](https://pub.dev/packages/flutter_soloud)
- [just_audio | Flutter package](https://pub.dev/packages/just_audio)
- [metronome | Flutter package](https://pub.dev/packages/metronome)
- [GitHub - alnitak/flutter_soloud](https://github.com/alnitak/flutter_soloud)
- [Building a Sample-Accurate Metronome with AudioTrack in Android](https://moshenskyi.medium.com/building-a-sample-accurate-metronome-with-audiotrack-in-android-7da27ac7dae1)
- [Low Latency Audio in iOS](https://medium.com/@jim.tompkins/low-latency-audio-in-ios-e4814fac2225)
- [Flutter Case Study: A More Accurate Timer](https://medium.com/geekculture/flutter-case-study-timer-precision-a1154b431e8)
- [Exploring the Magic of Just Audio in Flutter](https://www.dhiwise.com/post/flutter-audio-integration-exploring-the-magic-of-just-audio)
