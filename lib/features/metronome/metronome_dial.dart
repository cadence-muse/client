import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Maps [degreesFromTop] -- already normalized to (-180, 180], 0 = 12
/// o'clock/top, positive = clockwise -- to a BPM value in [40, 300] (D-06).
///
/// The dial exposes only a 270-degree sweep (-135 to 135 degrees), leaving a
/// 90-degree dead zone centered at the bottom/6-o'clock position. Angles
/// inside the dead zone -- including both sides of the raw `atan2`
/// discontinuity at ±180, which the caller's normalization maps into the
/// middle of this dead zone, not at either sweep endpoint -- clamp to
/// whichever of -135/135 they are numerically closer to (RESEARCH.md
/// Pitfall 4), which `.clamp(-135, 135)` already does correctly for both
/// sides.
///
/// This function is a trivial, directly-testable pure function; the
/// normalization from a raw `atan2` result into `degreesFromTop` happens in
/// [MetronomeDial]'s gesture handler, not here.
int angleToBpm(double degreesFromTop) {
  final clamped = degreesFromTop.clamp(-135.0, 135.0);
  final t = (clamped + 135) / 270;
  final bpmFloat = 40 + t * (300 - 40);
  return bpmFloat.round().clamp(40, 300);
}

/// Draws the dial's outer ring plus the BPM number and its "BPM" unit label,
/// centered. [bpm], [ringColor], [numberStyle], and [unitStyle] are all
/// resolved by the caller ([MetronomeDial]'s `build()`), since a
/// [CustomPainter] has no [BuildContext] of its own to resolve a [Theme]
/// from.
///
/// The "BPM" unit label is a literal, untranslated string -- matching the
/// existing i18n precedent (`metronomeBpmUnitLabel`/`commonTempoLabel`
/// already render "BPM" identically in both English and Russian ARB files)
/// -- so no localized string needs to be threaded through the painter.
class MetronomeDialPainter extends CustomPainter {
  MetronomeDialPainter({
    required this.bpm,
    required this.ringColor,
    required this.numberStyle,
    required this.unitStyle,
  });

  final int bpm;
  final Color ringColor;
  final TextStyle numberStyle;
  final TextStyle? unitStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final numberPainter = TextPainter(
      text: TextSpan(text: '$bpm', style: numberStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final unitPainter = TextPainter(
      text: TextSpan(text: 'BPM', style: unitStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final totalHeight = numberPainter.height + unitPainter.height;
    final numberOffset = Offset(
      center.dx - numberPainter.width / 2,
      center.dy - totalHeight / 2,
    );
    final unitOffset = Offset(
      center.dx - unitPainter.width / 2,
      numberOffset.dy + numberPainter.height,
    );

    numberPainter.paint(canvas, numberOffset);
    unitPainter.paint(canvas, unitOffset);
  }

  @override
  bool shouldRepaint(MetronomeDialPainter oldDelegate) =>
      oldDelegate.bpm != bpm ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.numberStyle != numberStyle ||
      oldDelegate.unitStyle != unitStyle;
}

/// The large round drag-to-rotate BPM dial (D-05). Dragging a finger around
/// the dial's circumference updates [onBpmChanged] live, on every
/// `onPanUpdate` frame (D-07) -- both `onPanStart` and `onPanUpdate` are
/// wired to the same handler, so the dial jumps to the touch-down angle
/// immediately AND updates live while dragging.
///
/// Sized to `min(80% of screen width, 320px)`, square, per UI-SPEC's "Dial
/// Sizing (Responsive)" row.
class MetronomeDial extends StatelessWidget {
  const MetronomeDial({
    required this.bpm,
    required this.onBpmChanged,
    super.key,
  });

  final int bpm;
  final ValueChanged<int> onBpmChanged;

  @override
  Widget build(BuildContext context) {
    final diameter = math.min(MediaQuery.of(context).size.width * 0.8, 320.0);

    void handleDrag(Offset localPosition) {
      final dx = localPosition.dx - diameter / 2;
      final dy = localPosition.dy - diameter / 2;
      final angleRadians = math.atan2(dy, dx);
      // atan2 returns (-pi, pi], so after "+ 90" degrees ranges over
      // (-90, 270]. This fold is enough to normalize into (-180, 180] with
      // no gap -- degrees can never be <= -180 afterward, so no second
      // correction branch is needed.
      var degrees = angleRadians * 180 / math.pi + 90;
      if (degrees > 180) degrees -= 360;
      onBpmChanged(angleToBpm(degrees));
    }

    return SizedBox(
      width: diameter,
      height: diameter,
      child: GestureDetector(
        onPanStart: (details) => handleDrag(details.localPosition),
        onPanUpdate: (details) => handleDrag(details.localPosition),
        child: CustomPaint(
          size: Size.square(diameter),
          painter: MetronomeDialPainter(
            bpm: bpm,
            ringColor: Theme.of(context).colorScheme.outlineVariant,
            numberStyle: Theme.of(context).textTheme.headlineLarge!.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            unitStyle: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
