import 'package:cadence/features/tracks/track_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDurationSeconds()', () {
    test('"2:30" -> 150', () {
      expect(parseDurationSeconds('2:30'), 150);
    });

    test('"" -> null', () {
      expect(parseDurationSeconds(''), isNull);
    });

    test('"   " -> null (D-06 optional)', () {
      expect(parseDurationSeconds('   '), isNull);
    });

    test('"230" (no colon) -> null', () {
      expect(parseDurationSeconds('230'), isNull);
    });

    test('"2:30:00" (3 parts) -> null', () {
      expect(parseDurationSeconds('2:30:00'), isNull);
    });

    test('"5:60" -> null (DUR-02, seconds >= 60)', () {
      expect(parseDurationSeconds('5:60'), isNull);
    });

    test(
      '"-1:30" -> null (defense-in-depth; unreachable via keystrokes but '
      'guards paste/programmatic set)',
      () {
        expect(parseDurationSeconds('-1:30'), isNull);
      },
    );

    test('"abc:def" -> null', () {
      expect(parseDurationSeconds('abc:def'), isNull);
    });

    test('"99:59" -> 5999 (max valid value under the 4-digit cap)', () {
      expect(parseDurationSeconds('99:59'), 5999);
    });
  });
}
