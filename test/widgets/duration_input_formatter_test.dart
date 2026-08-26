import 'package:cadence/features/tracks/track_formatting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = DurationTextInputFormatter();

  TextEditingValue value(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

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

    test('a 5th digit appended to an already-4-digit value is rejected, '
        'result equals oldValue unchanged', () {
      final old = value('2305');
      final result = formatter.formatEditUpdate(old, value('23056'));
      expect(result, old);
    });

    test('paste "2:30" as full replacement text reformats to "2:30"', () {
      final result = formatter.formatEditUpdate(value(''), value('2:30'));
      expect(result.text, '2:30');
    });

    test('backspace: oldValue "2:30", newValue "2:3" (last char removed) '
        '-> reformats to "0:23"', () {
      final old = value('2:30');
      final result = formatter.formatEditUpdate(old, value('2:3'));
      expect(result.text, '0:23');
    });

    test('cursor is always collapsed to the end of the reformatted text', () {
      final result = formatter.formatEditUpdate(value(''), value('230'));
      expect(
        result.selection,
        TextSelection.collapsed(offset: result.text.length),
      );
    });

    // The following cases simulate REAL chained keystrokes: each call's
    // oldValue is the literal TextEditingValue returned by the PREVIOUS
    // formatEditUpdate call, not a hand-built raw-digit string. This is the
    // only way to reproduce the reported input-lockup bug, where re-parsing
    // the displayed (already-formatted) text on every keystroke double
    // -counted the formatter's own synthetic zero-padding.

    TextEditingValue typeNext(TextEditingValue previous, String digit) {
      final newText = previous.text + digit;
      return formatter.formatEditUpdate(
        previous,
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    test('chained real keystrokes 2, 3, 0 into an empty field end at "2:30" '
        '(pre-fix this locks up at "00:23" after the second keystroke)', () {
      var current = value('');
      current = typeNext(current, '2');
      current = typeNext(current, '3');
      current = typeNext(current, '0');
      expect(current.text, '2:30');
    });

    test('a 4th chained real keystroke (5) ends at "23:05" — the digit cap '
        'boundary now lands at the correct point (4 real digits)', () {
      var current = value('');
      current = typeNext(current, '2');
      current = typeNext(current, '3');
      current = typeNext(current, '0');
      current = typeNext(current, '5');
      expect(current.text, '23:05');
    });

    test('a 5th chained real keystroke (9) is rejected: result equals the '
        'prior (4-digit) TextEditingValue unchanged, still "23:05"', () {
      var current = value('');
      current = typeNext(current, '2');
      current = typeNext(current, '3');
      current = typeNext(current, '0');
      current = typeNext(current, '5');
      final beforeFifth = current;
      current = typeNext(current, '9');
      expect(current, beforeFifth);
      expect(current.text, '23:05');
    });

    test('one real backspace from the 4-real-keystroke chained state ("23:05") '
        'reformats to "2:30" — drops the last actually-typed digit (5), not a '
        'leading synthetic zero', () {
      var current = value('');
      current = typeNext(current, '2');
      current = typeNext(current, '3');
      current = typeNext(current, '0');
      current = typeNext(current, '5');
      expect(current.text, '23:05');

      final backspaced = current.text.substring(0, current.text.length - 1);
      final result = formatter.formatEditUpdate(
        current,
        TextEditingValue(
          text: backspaced,
          selection: TextSelection.collapsed(offset: backspaced.length),
        ),
      );
      expect(result.text, '2:30');
    });

    TextEditingValue backspaceOnce(TextEditingValue previous) {
      final newText = previous.text.isEmpty
          ? ''
          : previous.text.substring(0, previous.text.length - 1);
      return formatter.formatEditUpdate(
        previous,
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    test('repeated real backspacing from a chained-keystroke value eventually '
        'clears to empty, not a floor of "0:00" (regression for CR-01)', () {
      var current = value('');
      current = typeNext(current, '5');
      expect(current.text, '0:05');

      current = backspaceOnce(current);
      expect(current.text, '');

      // Further backspacing an already-empty value stays empty.
      current = backspaceOnce(current);
      expect(current.text, '');
    });
  });
}
