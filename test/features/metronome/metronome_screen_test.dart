import 'package:cadence/features/metronome/audio/metronome_audio_service.dart';
import 'package:cadence/features/metronome/audio/tick_sound_player.dart';
import 'package:cadence/features/metronome/metronome_dial.dart';
import 'package:cadence/features/metronome/metronome_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_strings.dart';

/// No-op [TickSoundPlayer] double -- lets [MetronomeAudioService] initialize
/// and "play" without ever touching the real audioplayers platform channel
/// (mirroring metronome_state_test.dart's fake).
class FakeTickSoundPlayer implements TickSoundPlayer {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  Widget wrap(int initialBpm) {
    return ProviderScope(
      overrides: [
        metronomeAudioServiceProvider.overrideWith((ref) async {
          final service = MetronomeAudioService(
            accentPlayer: FakeTickSoundPlayer(),
            regularPlayer: FakeTickSoundPlayer(),
          );
          await service.initialize();
          return service;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        home: MetronomeScreen(initialBpm: initialBpm),
      ),
    );
  }

  // The dial paints its BPM number directly onto a Canvas (MetronomeDialPainter),
  // not as a Flutter Text widget -- so tests read the rendered value off the
  // MetronomeDial widget's own `bpm` property, not via find.text().
  int renderedBpm(WidgetTester tester) =>
      tester.widget<MetronomeDial>(find.byType(MetronomeDial)).bpm;

  testWidgets('tapping +1/+5/-1/-5 changes BPM by exactly that delta', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(120));
    await tester.pumpAndSettle();

    expect(renderedBpm(tester), 120);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pump();
    expect(renderedBpm(tester), 121);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add).last);
    await tester.pump();
    expect(renderedBpm(tester), 126);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove).first);
    await tester.pump();
    expect(renderedBpm(tester), 121);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove).last);
    await tester.pump();
    expect(renderedBpm(tester), 120);
  });

  testWidgets('at bpm == 40, -1 and -5 are disabled; +1/+5 remain enabled', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(40));
    await tester.pumpAndSettle();

    expect(renderedBpm(tester), 40);

    final removeButtons = find.widgetWithIcon(IconButton, Icons.remove);
    final addButtons = find.widgetWithIcon(IconButton, Icons.add);

    for (final finder in removeButtons.evaluate()) {
      final button = finder.widget as IconButton;
      expect(button.onPressed, isNull);
    }
    for (final finder in addButtons.evaluate()) {
      final button = finder.widget as IconButton;
      expect(button.onPressed, isNotNull);
    }
  });

  testWidgets('at bpm == 300, +1 and +5 are disabled; -1/-5 remain enabled', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(300));
    await tester.pumpAndSettle();

    expect(renderedBpm(tester), 300);

    final removeButtons = find.widgetWithIcon(IconButton, Icons.remove);
    final addButtons = find.widgetWithIcon(IconButton, Icons.add);

    for (final finder in addButtons.evaluate()) {
      final button = finder.widget as IconButton;
      expect(button.onPressed, isNull);
    }
    for (final finder in removeButtons.evaluate()) {
      final button = finder.widget as IconButton;
      expect(button.onPressed, isNotNull);
    }
  });

  testWidgets('each button tooltip matches the exact UI-SPEC copy', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(120));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip(tester.strings.metronomeMinus5Tooltip),
      findsOneWidget,
    );
    expect(
      find.byTooltip(tester.strings.metronomeMinus1Tooltip),
      findsOneWidget,
    );
    expect(
      find.byTooltip(tester.strings.metronomePlus1Tooltip),
      findsOneWidget,
    );
    expect(
      find.byTooltip(tester.strings.metronomePlus5Tooltip),
      findsOneWidget,
    );

    // Exact en-dash copy per UI-SPEC's Copywriting Contract, not a
    // hyphen-minus.
    expect(find.byTooltip('–5 BPM'), findsOneWidget);
    expect(find.byTooltip('–1 BPM'), findsOneWidget);
    expect(find.byTooltip('+1 BPM'), findsOneWidget);
    expect(find.byTooltip('+5 BPM'), findsOneWidget);
  });
}
