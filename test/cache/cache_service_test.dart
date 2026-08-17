import 'dart:io';

import 'package:cadence/cache/cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    await CacheService.initialize();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('writeProfile then readProfile roundtrips the same map', () async {
    final cache = CacheService.instance;
    await cache.writeProfile({'id': 'u1', 'username': 'alice'});

    final result = await cache.readProfile();

    expect(result, {'id': 'u1', 'username': 'alice'});
  });

  test('readProfile returns null when nothing was written', () async {
    final cache = CacheService.instance;

    final result = await cache.readProfile();

    expect(result, isNull);
  });

  test(
    'readProfileSyncedAt is null before any write and a recent DateTime '
    'immediately after writeProfile()',
    () async {
      final cache = CacheService.instance;

      expect(await cache.readProfileSyncedAt(), isNull);

      await cache.writeProfile({'id': 'u1', 'username': 'alice'});

      final syncedAt = await cache.readProfileSyncedAt();
      expect(syncedAt, isNotNull);
      expect(
        DateTime.now().difference(syncedAt!).inSeconds,
        lessThan(5),
      );
    },
  );

  test('writeHomepage then readHomepage roundtrips the same map', () async {
    final cache = CacheService.instance;
    await cache.writeHomepage({'username': 'alice', 'bandsCount': 3});

    final result = await cache.readHomepage();

    expect(result, {'username': 'alice', 'bandsCount': 3});
  });

  test('readHomepage returns null when nothing was written', () async {
    final cache = CacheService.instance;

    final result = await cache.readHomepage();

    expect(result, isNull);
  });

  test('clearAll() empties both profileBox and homepageBox', () async {
    final cache = CacheService.instance;
    await cache.writeProfile({'id': 'u1', 'username': 'alice'});
    await cache.writeHomepage({'username': 'alice', 'bandsCount': 3});

    await cache.clearAll();

    expect(await cache.readProfile(), isNull);
    expect(await cache.readHomepage(), isNull);
    expect(await cache.readBandTracks('b1'), isNull);
    expect(await cache.readBandSetlists('b1'), isNull);
  });

  test(
    'readBandDetail after a real Hive close+reopen returns fully typed '
    'nested collections (CR-01)',
    () async {
      var cache = CacheService.instance;
      await cache.writeBandDetail('b1', {
        'id': 'b1',
        'name': 'The Testers',
        'ownerId': 'u1',
        'inviteCode': 'ABC123',
        'members': [
          {'id': 'u1', 'username': 'alice'},
          {'id': 'u2', 'username': 'bob'},
        ],
      });

      // A real disk deserialization pass only happens on a fresh box open —
      // within the same open-box session, Hive serves get() straight from
      // its in-memory frame cache and never exercises
      // BinaryReaderImpl.readMap()/readList(), which is what actually
      // produces the untyped Map<dynamic, dynamic>/List<dynamic> containers
      // CR-01 is about. Close and reopen to force that real read path.
      await Hive.close();
      Hive.init(tempDir.path);
      await CacheService.initialize();
      cache = CacheService.instance;

      final result = await cache.readBandDetail('b1');

      expect(result, isNotNull);
      final members = (result!['members'] as List)
          .cast<Map<String, dynamic>>();
      expect(members[0]['username'], 'alice');
      expect(members[1]['username'], 'bob');
    },
  );

  test(
    'readBands after a real Hive close+reopen returns a fully typed '
    'list of maps (CR-01)',
    () async {
      var cache = CacheService.instance;
      await cache.writeBands([
        {'id': 'b1', 'name': 'The Testers'},
        {'id': 'b2', 'name': 'The Others'},
      ]);

      await Hive.close();
      Hive.init(tempDir.path);
      await CacheService.initialize();
      cache = CacheService.instance;

      final result = await cache.readBands();

      expect(result, isNotNull);
      expect(result![0]['name'], 'The Testers');
      expect(result[1]['name'], 'The Others');
    },
  );

  test(
    'readBandTracks after a real Hive close+reopen returns a fully typed '
    'list of maps, with an entry missing all optional fields (CR-01)',
    () async {
      var cache = CacheService.instance;
      await cache.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Song One', 'artist': 'Artist One'},
      ]);

      await Hive.close();
      Hive.init(tempDir.path);
      await CacheService.initialize();
      cache = CacheService.instance;

      final result = await cache.readBandTracks('b1');

      expect(result, isNotNull);
      expect(result![0]['id'], 't1');
      expect(result[0]['title'], 'Song One');
      expect(result[0]['artist'], 'Artist One');
      expect(result[0].containsKey('durationSeconds'), isFalse);
    },
  );

  test(
    'readBandTrackDetail after a real Hive close+reopen returns fully typed '
    'BandTrack fields including tempo/key/notes (CR-01)',
    () async {
      var cache = CacheService.instance;
      await cache.writeBandTrackDetail('b1', 't1', {
        'id': 't1',
        'title': 'Song One',
        'artist': 'Artist One',
        'durationSeconds': 225,
        'tempo': 120,
        'key': 'C',
        'notes': 'Play it slow on the bridge',
      });

      await Hive.close();
      Hive.init(tempDir.path);
      await CacheService.initialize();
      cache = CacheService.instance;

      final result = await cache.readBandTrackDetail('b1', 't1');

      expect(result, isNotNull);
      expect(result!['title'], 'Song One');
      expect(result['tempo'], 120);
      expect(result['key'], 'C');
      expect(result['notes'], 'Play it slow on the bridge');
    },
  );

  test(
    'writeUserTracks/readUserTracks round-trip both a null filter '
    '(user_tracks_all key) and a specific bandIdFilter (user_tracks_{id} '
    'key), without colliding with each other or with band-scoped tracksBox '
    'entries',
    () async {
      final cache = CacheService.instance;
      await cache.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Band-Scoped Track', 'artist': 'Artist'},
      ]);
      await cache.writeUserTracks(null, [
        {
          'id': 't1',
          'title': 'All Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'The Testers',
        },
        {
          'id': 't2',
          'title': 'Another Track',
          'artist': 'Artist',
          'bandId': 'b2',
          'bandName': 'The Others',
        },
      ]);
      await cache.writeUserTracks('b1', [
        {
          'id': 't1',
          'title': 'All Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'The Testers',
        },
      ]);

      final allTracks = await cache.readUserTracks(null);
      final filteredTracks = await cache.readUserTracks('b1');
      final bandScopedTracks = await cache.readBandTracks('b1');

      expect(allTracks, hasLength(2));
      expect(filteredTracks, hasLength(1));
      expect(filteredTracks![0]['title'], 'All Track');
      expect(bandScopedTracks, hasLength(1));
      expect(bandScopedTracks![0]['title'], 'Band-Scoped Track');
    },
  );

  test(
    'readBandSetlists after a real Hive close+reopen returns a fully typed '
    'list of maps, with an entry missing the optional eventDate field',
    () async {
      var cache = CacheService.instance;
      await cache.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': 'Friday Night Show',
          'tracksCount': 8,
          'durationSeconds': 2555,
        },
      ]);

      await Hive.close();
      Hive.init(tempDir.path);
      await CacheService.initialize();
      cache = CacheService.instance;

      final result = await cache.readBandSetlists('b1');

      expect(result, isNotNull);
      expect(result![0]['id'], 's1');
      expect(result[0]['name'], 'Friday Night Show');
      expect(result[0]['tracksCount'], 8);
      expect(result[0]['durationSeconds'], 2555);
      expect(result[0].containsKey('eventDate'), isFalse);
    },
  );

  test(
    'readSetlistDetail after a real Hive close+reopen returns fully typed '
    'BandSetlist fields including a nested tracks array (CR-01)',
    () async {
      var cache = CacheService.instance;
      await cache.writeSetlistDetail('b1', 's1', {
        'id': 's1',
        'name': 'Friday Night Show',
        'durationSeconds': 2555,
        'eventLocation': 'The Venue',
        'eventDate': '2026-09-01',
        'tracks': [
          {
            'trackId': 't1',
            'position': 0,
            'title': 'Song One',
            'artist': 'Artist One',
            'durationSeconds': 225,
          },
          {
            'trackId': 't2',
            'position': 1,
            'title': 'Song Two',
            'artist': 'Artist Two',
          },
        ],
      });

      await Hive.close();
      Hive.init(tempDir.path);
      await CacheService.initialize();
      cache = CacheService.instance;

      final result = await cache.readSetlistDetail('b1', 's1');

      expect(result, isNotNull);
      expect(result!['name'], 'Friday Night Show');
      final tracks = (result['tracks'] as List).cast<Map<String, dynamic>>();
      expect(tracks, hasLength(2));
      expect(tracks[0]['title'], 'Song One');
      expect(tracks[1]['title'], 'Song Two');
      expect(tracks[1].containsKey('durationSeconds'), isFalse);
    },
  );

  test(
    'writeUserSetlists/readUserSetlists round-trip both a null filter '
    '(user_setlists_all key) and a specific bandIdFilter '
    '(user_setlists_{id} key), without colliding with each other or with '
    'band-scoped setlistsBox entries (band_{id}/detail_{bandId}_{setlistId} '
    'keys)',
    () async {
      final cache = CacheService.instance;
      await cache.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': 'Band-Scoped Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
        },
      ]);
      await cache.writeSetlistDetail('b1', 's1', {
        'id': 's1',
        'name': 'Band-Scoped Setlist',
        'durationSeconds': 200,
        'tracks': <Map<String, dynamic>>[],
      });
      await cache.writeUserSetlists(null, [
        {
          'id': 's1',
          'name': 'All Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
          'bandId': 'b1',
          'bandName': 'The Testers',
        },
        {
          'id': 's2',
          'name': 'Another Setlist',
          'tracksCount': 2,
          'durationSeconds': 400,
          'bandId': 'b2',
          'bandName': 'The Others',
        },
      ]);
      await cache.writeUserSetlists('b1', [
        {
          'id': 's1',
          'name': 'All Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
          'bandId': 'b1',
          'bandName': 'The Testers',
        },
      ]);

      final allSetlists = await cache.readUserSetlists(null);
      final filteredSetlists = await cache.readUserSetlists('b1');
      final bandScopedSetlists = await cache.readBandSetlists('b1');
      final bandScopedDetail = await cache.readSetlistDetail('b1', 's1');

      expect(allSetlists, hasLength(2));
      expect(filteredSetlists, hasLength(1));
      expect(filteredSetlists![0]['name'], 'All Setlist');
      expect(bandScopedSetlists, hasLength(1));
      expect(bandScopedSetlists![0]['name'], 'Band-Scoped Setlist');
      expect(bandScopedDetail, isNotNull);
      expect(bandScopedDetail!['name'], 'Band-Scoped Setlist');
    },
  );
}
