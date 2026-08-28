import 'package:cadence/features/metronome/metronome_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal stateful harness rendering the current BPM as a [Text] widget
/// above the [MetronomeDial], so drag-driven [onBpmChanged] callbacks are
/// observable through the widget tree (mirroring how [MetronomeScreen]
/// itself wires the dial to Riverpod state, without pulling in the full
/// screen/provider stack for a dial-only test file).
class _DialHarness extends StatefulWidget {
  const _DialHarness({required this.initialBpm});

  final int initialBpm;

  @override
  State<_DialHarness> createState() => _DialHarnessState();
}

class _DialHarnessState extends State<_DialHarness> {
  late int _bpm = widget.initialBpm;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('$_bpm'),
            MetronomeDial(
              bpm: _bpm,
              onBpmChanged: (value) => setState(() => _bpm = value),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('angleToBpm', () {
    test('angleToBpm(-135) returns 40 (sweep start) (Test 1)', () {
      expect(angleToBpm(-135), 40);
    });

    test('angleToBpm(135) returns 300 (sweep end) (Test 2)', () {
      expect(angleToBpm(135), 300);
    });

    test('angleToBpm(0) returns 170 (sweep midpoint: 40 + 0.5*(300-40)) '
        '(Test 3)', () {
      expect(angleToBpm(0), 170);
    });

    test('angleToBpm(150) returns 300 (past sweep end, right-side dead zone, '
        'clamps to nearer endpoint not a jump to 40) (Test 4)', () {
      expect(angleToBpm(150), 300);
    });

    test('angleToBpm(-150) returns 40 (past sweep start, left-side dead zone, '
        'clamps to nearer endpoint) (Test 5)', () {
      expect(angleToBpm(-150), 40);
    });

    test('angleToBpm(-179.9) and angleToBpm(179.9) -- both sides of the raw '
        'atan2 discontinuity, deep inside the dead zone -- both return valid '
        'in-range values with no exception and no wraparound to the opposite '
        'endpoint (Test 6)', () {
      final left = angleToBpm(-179.9);
      final right = angleToBpm(179.9);

      expect(left, inInclusiveRange(40, 300));
      expect(right, inInclusiveRange(40, 300));
      expect(left, 40);
      expect(right, 300);
    });
  });

  group('MetronomeDial widget', () {
    testWidgets(
      'dragging updates the displayed BPM live, on every onPanUpdate frame, '
      'before the gesture completes',
      (tester) async {
        await tester.pumpWidget(const _DialHarness(initialBpm: 120));

        expect(find.text('120'), findsOneWidget);

        final dialCenter = tester.getCenter(find.byType(MetronomeDial));
        // Start the drag near the top of the dial (close to BPM 170's
        // midpoint angle) then move right -- clockwise -- to increase BPM.
        final gesture = await tester.startGesture(
          dialCenter + const Offset(0, -100),
        );
        await tester.pump();

        await gesture.moveBy(const Offset(100, 0));
        await tester.pump();

        // Still mid-gesture (no gesture.up() yet) -- the BPM text must have
        // already changed from the initial 120, proving the update fired on
        // onPanUpdate, not only on gesture completion.
        expect(find.text('120'), findsNothing);

        await gesture.up();
        await tester.pump();
      },
    );

    testWidgets(
      'dial diameter equals min(width*0.8, 320) on a narrow ~360px surface',
      (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(360, 800)),
            child: MaterialApp(
              home: Scaffold(
                body: MetronomeDial(bpm: 120, onBpmChanged: (_) {}),
              ),
            ),
          ),
        );

        final customPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(MetronomeDial),
            matching: find.byType(CustomPaint),
          ),
        );

        expect(customPaint.size, const Size(288, 288));
      },
    );

    testWidgets('dial diameter caps at 320 on a wide ~800px surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 1200)),
          child: MaterialApp(
            home: Scaffold(body: MetronomeDial(bpm: 120, onBpmChanged: (_) {})),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(MetronomeDial),
          matching: find.byType(CustomPaint),
        ),
      );

      expect(customPaint.size, const Size(320, 320));
    });
  });
}
