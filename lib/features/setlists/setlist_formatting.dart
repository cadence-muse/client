/// Formats a setlist's `durationSeconds` in words (D-05), e.g. `2555` ->
/// `'42m 35s'`. Distinct from Track's `mm:ss` presentation
/// (`track_formatting.dart`'s `asMinutesSeconds`) — the two features
/// intentionally use different duration formats per their respective
/// UI-SPECs.
extension DurationFormatting on int {
  String get asMinutesAndSeconds => '${this ~/ 60}m ${this % 60}s';
}

/// Pluralizes a track count for display, e.g. `1` -> `'1 track'`, `8` ->
/// `'8 tracks'`.
String pluralizeTracks(int count) => count == 1 ? '1 track' : '$count tracks';

/// Composes a setlist list row's trailing text, e.g. `'8 tracks, 42m 35s'`.
/// Reused unmodified by Plan 05's global cross-band Setlists tab.
String tracksAndDuration(int tracksCount, int durationSeconds) =>
    '${pluralizeTracks(tracksCount)}, ${durationSeconds.asMinutesAndSeconds}';

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats an optional ISO-8601 `eventDate` string as `'MMM d, yyyy'`
/// (e.g. `'Aug 16, 2026'`), returning `'No date set'` (D-07) when
/// [dateString] is `null`/empty or fails to parse.
String formatEventDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) return 'No date set';
  try {
    final date = DateTime.parse(dateString);
    return '${_monthAbbreviations[date.month - 1]} ${date.day}, ${date.year}';
  } catch (_) {
    return 'No date set';
  }
}
