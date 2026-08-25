import 'package:cadence/features/tracks/track_formatting.dart';

/// Pluralizes a track count for display, e.g. `1` -> `'1 track'`, `8` ->
/// `'8 tracks'`.
String pluralizeTracks(int count) => count == 1 ? '1 track' : '$count tracks';

/// Composes a setlist list row's trailing text, e.g. `'8 tracks, 42:35'`.
/// Reused unmodified by Plan 05's global cross-band Setlists tab.
String tracksAndDuration(int tracksCount, int durationSeconds) =>
    '${pluralizeTracks(tracksCount)}, ${durationSeconds.asMinutesSeconds}';

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
