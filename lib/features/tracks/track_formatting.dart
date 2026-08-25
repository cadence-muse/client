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

    if (digitsOnly.length > 4) {
      return oldValue;
    }

    final String formatted;
    if (digitsOnly.length <= 2) {
      formatted = '0:${digitsOnly.padLeft(2, '0')}';
    } else {
      final minutes = digitsOnly.substring(0, digitsOnly.length - 2);
      final seconds = digitsOnly.substring(digitsOnly.length - 2);
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
