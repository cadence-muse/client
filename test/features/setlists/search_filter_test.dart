import 'package:cadence/features/setlists/add_setlist_tracks_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure unit tests for [trackMatchesSearchQuery] (D-02): case-insensitive
/// substring match against a track's title or artist. No widget pump
/// needed — this is a plain function.
void main() {
  final track = {'title': 'Wonderwall', 'artist': 'Oasis'};

  test('matches on a title substring using a differently-cased query', () {
    expect(trackMatchesSearchQuery(track, 'wonder'), isTrue);
    expect(trackMatchesSearchQuery(track, 'WONDER'), isTrue);
  });

  test('matches on an artist substring', () {
    expect(trackMatchesSearchQuery(track, 'oasis'), isTrue);
  });

  test('returns false when neither title nor artist contains the query', () {
    expect(trackMatchesSearchQuery(track, 'nothing matches this'), isFalse);
  });

  test('returns true for every track when the query is empty', () {
    expect(trackMatchesSearchQuery(track, ''), isTrue);
  });

  test(
    'returns true when the query exactly equals the full title '
    '(adjacency edge case)',
    () {
      expect(trackMatchesSearchQuery(track, 'Wonderwall'), isTrue);
    },
  );
}
