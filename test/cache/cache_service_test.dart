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
}
