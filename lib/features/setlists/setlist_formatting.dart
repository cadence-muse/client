// ReorderSetlistTracksRequestBody/AddSetlistTracksRequestBody both cap
// `trackIds` at 100 (publicapi.yml). Was independently declared as
// `_maxSetlistTracks` in setlist_detail_screen.dart, create_setlist_screen.dart,
// and add_setlist_tracks_dialog.dart (D-12) -- now a single shared source of
// truth so it can't drift across the 3 consumers.
const int maxSetlistTracks = 100;

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
