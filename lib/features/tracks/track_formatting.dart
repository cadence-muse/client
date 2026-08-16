/// Formats a track's `durationSeconds` as `mm:ss` (D-06), e.g. `225` -> `3:45`.
extension DurationFormatting on int {
  String get asMinutesSeconds =>
      '${this ~/ 60}:${(this % 60).toString().padLeft(2, '0')}';
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
