# Phase 18: Metronome Tool - Pattern Map

**Mapped:** 2026-08-27
**Files analyzed:** 8 new/modified files
**Analogs found:** 7 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/features/metronome/metronome_screen.dart` | screen | request-response | `lib/features/home/home_screen.dart` | exact |
| `lib/features/metronome/metronome_dial.dart` | component | request-response | Flutter Material CustomPaint/GestureDetector | role-match |
| `lib/features/metronome/beat_indicator.dart` | component | request-response | `lib/widgets/offline_banner.dart` | role-match |
| `lib/features/metronome/audio/metronome_audio_service.dart` | service | file-I/O | N/A (new pattern) | no-match |
| `lib/providers/metronome_provider.dart` | state management | event-driven | `lib/providers/navigation_provider.dart` | role-match |
| `lib/features/home/home_screen.dart` | screen (modified) | request-response | Self (existing pattern) | existing |
| `lib/features/tracks/track_detail_screen.dart` | screen (modified) | request-response | Self (existing pattern) | existing |
| `pubspec.yaml` | config | dependency declaration | Self (existing pattern) | existing |

## Pattern Assignments

### `lib/features/metronome/metronome_screen.dart` (screen, request-response)

**Analog:** `lib/features/home/home_screen.dart` (line 1-60)

**Imports pattern** (lines 1-10):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/metronome_provider.dart';
import 'metronome_dial.dart';
import 'beat_indicator.dart';
import 'audio/metronome_audio_service.dart';
```

**ConsumerWidget structure** (lines 12-14):
```dart
class MetronomeScreen extends ConsumerWidget {
  final int? initialBpm; // Optional parameter for prefill from track.tempo
  const MetronomeScreen({super.key, this.initialBpm});
```

**Async data listening pattern** (from home_screen.dart lines 20-26):
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen<int>(selectedTabIndexProvider, (previous, current) {
    // Listen to provider changes
  });
  
  final homeAsync = ref.watch(homepageDataProvider);
  final l10n = AppLocalizations.of(context)!;
```

**Error handling and state-based UI** (from home_screen.dart lines 48-60):
```dart
body: homeAsync.when(
  data: (data) => _buildContent(context, ref, data),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, stackTrace) {
    return _buildError(context, () => ref.invalidate(homepageDataProvider));
  },
),
```

**AppBar with refresh/action buttons** (from track_detail_screen.dart lines 32-53):
```dart
appBar: AppBar(
  title: Text(title ?? l10n.trackDetailFallbackTitle),
  actions: [
    if (currentTrack != null)
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: isOnline ? l10n.trackDetailEditTooltip : l10n.commonRequiresConnection,
        onPressed: isOnline ? () => { ... } : null,
      ),
  ],
),
```

**Localization usage pattern** (from home_screen.dart line 26):
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.someLocalizedString)
```

---

### `lib/features/metronome/metronome_dial.dart` (component, request-response)

**Analog:** Flutter Material CustomPaint + GestureDetector (no direct codebase analog)

**CustomPainter class structure** (Flutter standard):
```dart
class MetronomeDialPainter extends CustomPainter {
  final int bpm;
  final double dialRadius;

  MetronomeDialPainter({required this.bpm, required this.dialRadius});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw dial circle, rings, BPM text, etc.
  }

  @override
  bool shouldRepaint(MetronomeDialPainter oldDelegate) =>
      oldDelegate.bpm != bpm;
}
```

**StatefulWidget with GestureDetector** (Flutter standard, similar to join_band_dialog.dart):
```dart
class MetronomeDialState extends State<MetronomeDial> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => _onDragUpdate(details.globalPosition),
      child: CustomPaint(
        painter: MetronomeDialPainter(bpm: widget.bpm, dialRadius: _dialRadius),
        size: Size(_dialRadius * 2 + 32, _dialRadius * 2 + 32),
      ),
    );
  }

  void _onDragUpdate(Offset globalPosition) {
    // Calculate angle from drag position using atan2
    final angle = math.atan2(dy, dx);
    // Map angle to BPM range [40, 300]
    final newBpm = _angleToBpm(angle);
    widget.onBpmChanged(newBpm);
  }
}
```

**Responsive sizing pattern** (from home_screen.dart/track_detail_screen.dart):
```dart
// Use MediaQuery to size dial responsively
final dialRadius = math.min(
  MediaQuery.of(context).size.width * 0.4,
  160, // Max size cap
);
```

**Callback pattern for value changes** (from join_band_dialog.dart line 77-124):
```dart
// Widget accepts callback to notify parent of state changes
class MetronomeDial extends StatefulWidget {
  final int bpm;
  final ValueChanged<int> onBpmChanged; // Callback signature
  
  const MetronomeDial({
    required this.bpm,
    required this.onBpmChanged,
  });
}

// Call from gesture handler:
widget.onBpmChanged(newBpm);
```

---

### `lib/features/metronome/beat_indicator.dart` (component, request-response)

**Analog:** `lib/widgets/offline_banner.dart` (lines 1-40)

**Imports pattern** (offline_banner.dart lines 1-5):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../generated/app_localizations.dart';
import '../providers/connectivity_provider.dart';
```

**ConsumerWidget structure** (offline_banner.dart lines 10-40):
```dart
class BeatIndicator extends ConsumerWidget {
  final int currentBeat; // 0–3

  const BeatIndicator({required this.currentBeat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Build UI based on state
  }
}
```

**Theme/ColorScheme pattern** (offline_banner.dart lines 21-39):
```dart
final colorScheme = Theme.of(context).colorScheme;
return Container(
  color: colorScheme.errorContainer,
  // Use colorScheme.primary, colorScheme.outlineVariant for accent colors
);
```

**Conditional rendering with Row/Wrap** (from home_screen.dart lines 129-155):
```dart
return Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    for (int i = 0; i < 4; i++)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(...),  // Each beat dot
      ),
  ],
);
```

**AnimatedContainer for visual updates** (Flutter standard):
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 100),
  width: i == currentBeat ? 16 : 8,
  height: i == currentBeat ? 16 : 8,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: i == currentBeat ? colorScheme.primary : colorScheme.outlineVariant,
  ),
)
```

---

### `lib/features/metronome/audio/metronome_audio_service.dart` (service, file-I/O)

**Analog:** None directly (new pattern for audio asset loading)

**Recommended pattern** (based on cache_service.dart and Riverpod conventions):

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'metronome_audio_service.g.dart';

class MetronomeAudioService {
  late AudioPlayer _accentPlayer;
  late AudioPlayer _regularPlayer;
  bool _assetsLoaded = false;

  Future<void> initialize() async {
    _accentPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
    _regularPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

    try {
      await _accentPlayer.setSource(AssetSource('audio/metronome_accent.wav'));
      await _regularPlayer.setSource(AssetSource('audio/metronome_regular.wav'));
      _assetsLoaded = true;
    } catch (e) {
      print('Error loading metronome audio: $e');
      _assetsLoaded = false; // Graceful degradation
    }
  }

  Future<void> playTick(bool isAccent) async {
    if (!_assetsLoaded) return;
    final player = isAccent ? _accentPlayer : _regularPlayer;
    try {
      await player.resume();
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
Future<MetronomeAudioService> metronomAudioService(
  MetronomeAudioServiceRef ref,
) async {
  final service = MetronomeAudioService();
  await service.initialize();
  ref.onDispose(service.dispose);
  return service;
}
```

**Riverpod provider pattern** (from navigation_provider.dart):
```dart
@riverpod
Future<MetronomeAudioService> metronomAudioService(
  MetronomeAudioServiceRef ref,
) async {
  // Initialize async resource
  final service = MetronomeAudioService();
  await service.initialize();
  
  // Register cleanup
  ref.onDispose(service.dispose);
  return service;
}
```

---

### `lib/providers/metronome_provider.dart` (state management, event-driven)

**Analog:** `lib/providers/navigation_provider.dart` (lines 1-27)

**Riverpod class structure** (navigation_provider.dart lines 15-26):
```dart
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
      currentBeat: 0,
    );
  }

  // Public state-changing methods
  void setBPM(int newBPM) { ... }
  void togglePlay() { ... }
}
```

**Theme provider pattern** (theme_provider.dart lines 6-12):
```dart
@riverpod
class ThemeController extends _$ThemeController {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) => state = mode;
}
```

**State data class with copyWith** (inferred from RESEARCH.md pattern):
```dart
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

**Timer-based state updates** (Dart standard, no direct codebase analog):
```dart
void _startBeatTimer() {
  _beatTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
    _checkAndPlayTick();
  });
}

void _checkAndPlayTick() {
  final intervalMs = (60000.0 / state.bpm / 4).round();
  final expectedTime = state.currentBeat * intervalMs;
  final elapsed = _stopwatch.elapsedMilliseconds;

  if ((elapsed - expectedTime).abs() < 20) {
    final isAccent = state.currentBeat == 0;
    _playTick(isAccent);
    
    final nextBeat = (state.currentBeat + 1) % 4;
    state = state.copyWith(currentBeat: nextBeat);
  }
}
```

**Initialization with ref.onDispose cleanup** (pattern from bands_provider.dart line 39-63):
```dart
@override
MetronomData build() {
  ref.onDispose(() {
    _beatTimer?.cancel();
    _stopwatch.stop();
  });
  
  return const MetronomData(bpm: 120, isPlaying: false, currentBeat: 0);
}
```

---

### `lib/features/home/home_screen.dart` (screen, modified)

**Existing pattern to extend** (lines 121-155):

Add a new "Tools" section below Quick Actions following the same Card/header pattern:

```dart
// After the Wrap with Quick Actions buttons, add:
const SizedBox(height: 32), // Use xl spacing (32px)

// "Tools" section header
Text(
  l10n.homeToolsHeader, // "Tools"
  style: Theme.of(context).textTheme.titleMedium,
),
const SizedBox(height: 16),

// Metronome tool button
Wrap(
  spacing: 16,
  runSpacing: 8,
  children: [
    ElevatedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const MetronomeScreen(initialBpm: 120),
        ),
      ),
      icon: const Icon(Icons.music_note), // or Icons.speed
      label: Text(l10n.homeMetronomeButton), // "Metronome"
    ),
  ],
),
```

**Import to add** (top of file):
```dart
import '../metronome/metronome_screen.dart';
```

---

### `lib/features/tracks/track_detail_screen.dart` (screen, modified)

**Existing pattern to extend** (lines 34-53):

Add a metronome icon button to AppBar.actions, conditional on `tempo != null`:

```dart
appBar: AppBar(
  title: Text(title ?? l10n.trackDetailFallbackTitle),
  actions: [
    if (currentTrack != null && tempo != null)
      IconButton(
        icon: const Icon(Icons.speed), // or Icons.music_note
        tooltip: l10n.trackDetailMetronomeTooltip, // "Practice with metronome"
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MetronomeScreen(initialBpm: tempo),
          ),
        ),
      ),
    if (currentTrack != null)
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: isOnline ? l10n.trackDetailEditTooltip : l10n.commonRequiresConnection,
        // ... rest of edit button
      ),
  ],
),
```

**Import to add** (top of file):
```dart
import '../metronome/metronome_screen.dart';
```

**Access tempo value** (line 79, already exists):
```dart
final tempo = track['tempo'] as int?;
```

---

### `pubspec.yaml` (config, dependency)

**Existing pattern to extend** (lines 10-24):

Add `audioplayers` dependency:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.6.0
  flutter_secure_storage: ^11.0.0
  flutter_riverpod: ^2.6.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  riverpod_annotation: ^2.6.1
  connectivity_plus: ^7.3.1
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2
  shared_preferences: ^2.2.0
  audioplayers: ^5.2.0  # NEW: Audio tick playback with low-latency mode
```

**Asset bundling** (lines 44-45, extend existing):

```yaml
flutter:
  uses-material-design: true
  generate: true

  assets:
    - assets/images/logo.png
    - assets/audio/  # NEW: Audio assets for metronome ticks

  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg
```

---

## Shared Patterns

### ConsumerWidget Pattern
**Source:** `lib/features/home/home_screen.dart` and `lib/widgets/offline_banner.dart`
**Apply to:** All Metronome feature screens and components
```dart
class SomeWidget extends ConsumerWidget {
  const SomeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final someData = ref.watch(someProvider);
    // Build UI
  }
}
```

### Riverpod State Management Pattern
**Source:** `lib/providers/navigation_provider.dart` and `lib/providers/theme_provider.dart`
**Apply to:** `metronome_provider.dart`
```dart
@riverpod
class SomeNotifier extends _$SomeNotifier {
  @override
  SomeState build() {
    ref.onDispose(() {
      // Cleanup resources
    });
    return const SomeState(...);
  }

  void updateState(newValue) => state = state.copyWith(...);
}
```

### Error Handling and Async UI
**Source:** `lib/features/home/home_screen.dart` (lines 48-60) and `lib/features/tracks/track_detail_screen.dart` (lines 55-68)
**Apply to:** MetronomeScreen if audio loading is async
```dart
body: audioAsync.when(
  data: (_) => _buildContent(context, ref),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, stackTrace) {
    return _buildError(context, () => ref.invalidate(someProvider));
  },
),
```

### Navigation Pattern
**Source:** `lib/features/home/home_screen.dart` (lines 134-136) and `lib/features/bands/join_band_dialog.dart` (lines 50-54)
**Apply to:** All navigation from Home/TrackDetail to MetronomeScreen
```dart
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => MetronomeScreen(initialBpm: 120),
  ),
)
```

### Theme/ColorScheme Usage
**Source:** `lib/widgets/offline_banner.dart` (lines 21-39) and `lib/features/tracks/track_detail_screen.dart` (lines 82, 99, 112, 143)
**Apply to:** All components (dial, beat indicator, buttons)
```dart
final colorScheme = Theme.of(context).colorScheme;
// Primary accent: colorScheme.primary
// Neutral accent: colorScheme.outlineVariant
// Error states: colorScheme.error
```

### Localization Pattern
**Source:** `lib/features/home/home_screen.dart` (lines 26, 108-109, etc.)
**Apply to:** All user-facing strings in Metronome screens
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.homeToolsHeader),  // String keys added to app_localizations.dart
```

---

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `lib/features/metronome/audio/metronome_audio_service.dart` | service | file-I/O | No audio asset loading service exists; new pattern required. RESEARCH.md provides complete implementation guide. |
| `lib/features/metronome/metronome_dial.dart` | component | request-response | No CustomPainter + gesture-based control exists in codebase; greenfield UI. Flutter standard patterns + RESEARCH.md angle-to-BPM mapping guide required. |

---

## Metadata

**Analog search scope:** 
- `lib/features/*/` screens (14 files)
- `lib/providers/` state management (9 files)
- `lib/widgets/` reusable components (2 files)
- `lib/app.dart`, `lib/main.dart`, `lib/theme/`

**Files scanned:** 30+

**Pattern extraction date:** 2026-08-27

**Key findings:**
- Project uses `@riverpod` class pattern consistently (Riverpod v2.6.1+)
- All screens are ConsumerWidget or ConsumerStatefulWidget (never plain StatelessWidget)
- Async data loading uses `.when(data:, loading:, error:)` pattern
- Navigation always uses `Navigator.of(context).push(MaterialPageRoute(...))`
- Localization uses `AppLocalizations.of(context)!` helper
- Theme colors accessed via `Theme.of(context).colorScheme`
- No existing CustomPainter or audio services; metronome dial and audio service are greenfield patterns
