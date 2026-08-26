import 'package:flutter/services.dart';

/// Formats a track's `durationSeconds` as `mm:ss` (D-06), e.g. `225` -> `3:45`.
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
}

/// Auto-formats raw digit keystrokes into `mm:ss` shape as the user types
/// (DUR-04), e.g. typing `230` renders `2:30`. Caps at 4 digits (not 5) so
/// minutes never exceed 2 digits, matching D-03's "99:59 maximum" literally
/// — see the digit-cap correction note in `11-01-PLAN.md`'s `<context>`.
///
/// The raw digit count driving the cap/formatting logic can't be recovered
/// by re-stripping non-digit characters from the full *displayed* text on
/// every call — that text is whatever this formatter itself last rendered
/// (e.g. "0:02" after a single real keystroke), so re-parsing it double
/// -counts the synthetic zero-padding this formatter injects, over-counting
/// the digit cap after only 2-3 real keystrokes and appearing to lock up
/// input. Instead, [_rawTypedDigits] recovers the previously-typed raw digit
/// count from the prior formatted text, and `formatEditUpdate` diffs the new
/// text against the old to find only the newly-typed/removed characters.
///
/// This formatter only shapes keystrokes; it cannot guard against paste or
/// programmatic `controller.text` assignment bypassing the shape entirely.
/// [parseDurationSeconds] independently re-validates at submit time.
class DurationTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final digitsNew = digitsOnly;
    final digitsOld = oldValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final oldRaw = _rawTypedDigits(oldValue.text);

    final String rawDigits;
    if (digitsNew.length >= digitsOld.length &&
        digitsNew.startsWith(digitsOld)) {
      // Append at the end: the common typing/paste-at-end case, since the
      // cursor is always collapsed to the end by this formatter's own prior
      // return. Only the newly-added suffix is appended to the previously
      // -typed raw digits — digitsOld/digitsNew locate which characters are
      // new, they are never trusted as the raw digit count themselves.
      rawDigits = oldRaw + digitsNew.substring(digitsOld.length);
    } else if (digitsNew.length < digitsOld.length &&
        digitsOld.startsWith(digitsNew)) {
      // Removal from the end: ordinary backspace.
      final removed = digitsOld.length - digitsNew.length;
      rawDigits = oldRaw.length > removed
          ? oldRaw.substring(0, oldRaw.length - removed)
          : '';
    } else {
      // Full replace/paste over a selection, or a mid-string edit: trust the
      // new text's digits as the raw source.
      rawDigits = digitsNew;
    }

    if (rawDigits.length > 4) {
      return oldValue;
    }

    if (rawDigits.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final String formatted;
    if (rawDigits.length <= 2) {
      formatted = '0:${rawDigits.padLeft(2, '0')}';
    } else {
      final minutes = rawDigits.substring(0, rawDigits.length - 2);
      final seconds = rawDigits.substring(rawDigits.length - 2);
      formatted = '$minutes:$seconds';
    }

    // Always collapse the cursor to the end of the reformatted text; do not
    // carry over newValue.selection, whose offset can exceed the new text's
    // length and trigger a selection-range assertion.
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Recovers the count of digits the user actually typed from a previously
/// -rendered `mm:ss` string, undoing [DurationTextInputFormatter]'s own
/// synthetic zero-padding (the leading `'0:'` minutes placeholder and the
/// seconds `padLeft(2, '0')`).
///
/// Best-effort inverse: for a `minutes == '0'` display the true prior digit
/// count is inherently ambiguous between 1 and 2 typed digits (both pad
/// identically), but both interpretations format identically and parse to
/// the same duration, so the ambiguity is harmless. There is no ambiguity
/// when `minutes != '0'`.
String _rawTypedDigits(String formatted) {
  if (formatted.isEmpty) return '';

  final parts = formatted.split(':');
  if (parts.length != 2) {
    // Defensive fallback covering the pre-existing isolated unit tests,
    // which pass raw digit strings (e.g. '23') as oldValue.text rather than
    // formatted mm:ss text.
    return formatted.replaceAll(RegExp(r'[^0-9]'), '');
  }

  final minutes = parts[0];
  final seconds = parts[1];

  if (minutes != '0') {
    // Exact: the 3-4 digit formatting branch never pads, so concatenation
    // recovers the original digit sequence with no ambiguity.
    return minutes + seconds;
  }

  if (seconds == '00') return '0';
  if (seconds.length == 2 && seconds.startsWith('0') && seconds != '00') {
    return seconds.substring(1);
  }
  return seconds;
}

/// Parses a `mm:ss` string into total seconds (DUR-01), or `null` if the
/// text is empty (D-06, optional field), malformed, or represents an
/// invalid duration (seconds >= 60, negative values). Independently
/// re-validates at submit time — see [DurationTextInputFormatter]'s doc
/// comment on why the formatter alone cannot guard against paste or
/// programmatic text assignment.
int? parseDurationSeconds(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  final parts = trimmed.split(':');
  if (parts.length != 2) return null;

  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null) return null;
  if (minutes < 0 || seconds < 0) return null;
  if (seconds > 59) return null;

  return minutes * 60 + seconds;
}

/// The 24-value key dropdown (D-10): 12 root notes x major/minor toggle.
/// A client-only convention layered on top of the API's unconstrained
/// `key: string` field (no server-side enum).
const musicalKeys = [
  'C',
  'Cm',
  'C#',
  'C#m',
  'D',
  'Dm',
  'D#',
  'D#m',
  'E',
  'Em',
  'F',
  'Fm',
  'F#',
  'F#m',
  'G',
  'Gm',
  'G#',
  'G#m',
  'A',
  'Am',
  'A#',
  'A#m',
  'B',
  'Bm',
];
