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
}
