import 'package:cadence/features/tracks/track_formatting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = DurationTextInputFormatter();

  TextEditingValue value(String text) =>
      TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));

  group('DurationTextInputFormatter', () {
    test('empty stays empty', () {
      final result = formatter.formatEditUpdate(value(''), value(''));
      expect(result.text, '');
    });

    test('"2" -> "0:02"', () {
      final result = formatter.formatEditUpdate(value(''), value('2'));
      expect(result.text, '0:02');
    });

    test('"23" -> "0:23"', () {
      final result = formatter.formatEditUpdate(value('2'), value('23'));
      expect(result.text, '0:23');
    });

    test('"230" -> "2:30"', () {
      final result = formatter.formatEditUpdate(value('23'), value('230'));
      expect(result.text, '2:30');
    });

    test('"2305" -> "23:05"', () {
      final result = formatter.formatEditUpdate(value('230'), value('2305'));
      expect(result.text, '23:05');
    });

    test(
      'a 5th digit appended to an already-4-digit value is rejected, '
      'result equals oldValue unchanged',
      () {
        final old = value('2305');
        final result = formatter.formatEditUpdate(old, value('23056'));
        expect(result, old);
      },
    );

    test('paste "2:30" as full replacement text reformats to "2:30"', () {
      final result = formatter.formatEditUpdate(value(''), value('2:30'));
      expect(result.text, '2:30');
    });

    test(
      'backspace: oldValue "2:30", newValue "2:3" (last char removed) '
      '-> reformats to "0:23"',
      () {
        final old = value('2:30');
        final result = formatter.formatEditUpdate(old, value('2:3'));
        expect(result.text, '0:23');
      },
    );

    test('cursor is always collapsed to the end of the reformatted text', () {
      final result = formatter.formatEditUpdate(value(''), value('230'));
      expect(result.selection, TextSelection.collapsed(offset: result.text.length));
    });
  });
}
