import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient buildApiClient(
    Future<http.Response> Function(http.Request) handler,
  ) {
    return ApiClient(
      baseUrl: 'http://localhost',
      getToken: () => 'test-token',
      onUnauthorized: () async {},
      httpClient: MockClient(handler),
    );
  }

  ProviderContainer buildContainer(
    ApiClient apiClient,
    CacheService cacheService,
  ) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'cache-hit returns cached detail map immediately with a silent background refresh',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', {
        'id': 'b1',
        'name': 'Cached Band',
        'ownerId': 'u1',
        'members': [
          {'id': 'u1', 'username': 'alice'},
        ],
        'inviteCode': 'abc-123',
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'b1',
            'name': 'Cached Band',
            'ownerId': 'u1',
            'members': [
              {'id': 'u1', 'username': 'alice'},
            ],
            'inviteCode': 'abc-123',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandDetailDataProvider('b1').future);

      expect(data['id'], 'b1');
      expect(data['name'], 'Cached Band');
    },
  );

  test('no cache and network failure yields AsyncError', () async {
    final cacheService = CacheService.inMemory();
    final apiClient = buildApiClient((request) async {
      return http.Response(
        jsonEncode({'code': 'network_error', 'message': 'offline'}),
        500,
      );
    });

    final container = buildContainer(apiClient, cacheService);

    await expectLater(
      container.read(bandDetailDataProvider('b1').future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(bandDetailDataProvider('b1')).hasError, isTrue);
  });

  test(
    'updateName() merges the new name into cached state without an '
    'additional network fetch',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', {
        'id': 'b1',
        'name': 'Old Name',
        'ownerId': 'u1',
        'members': [
          {'id': 'u1', 'username': 'alice'},
        ],
        'inviteCode': 'abc-123',
      });

      var getBandCallCount = 0;
      final apiClient = buildApiClient((request) async {
        getBandCallCount++;
        return http.Response(
          jsonEncode({
            'id': 'b1',
            'name': 'Old Name',
            'ownerId': 'u1',
            'members': [
              {'id': 'u1', 'username': 'alice'},
            ],
            'inviteCode': 'abc-123',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      // bandDetailDataProvider is autoDispose (plain @riverpod); a bare
      // container.read() doesn't hold a subscription, so the provider would
      // get disposed and silently rebuilt (resetting state to AsyncLoading
      // then a fresh cache-hit) between reads. Keep it alive for the
      // duration of this test the same way a watching widget would.
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);

      // Establish the provider (cache-hit path — data returns from cache
      // immediately, but a silent background refresh is also fired per
      // build()'s cache-first contract; let that settle before recording a
      // baseline, so this test isolates updateName()'s own call count
      // rather than racing that unrelated background refresh).
      final initial = await container.read(
        bandDetailDataProvider('b1').future,
      );
      expect(initial['name'], 'Old Name');
      // The unawaited background refresh chains several awaits (HTTP send +
      // response decode) before it settles; a real (not just microtask-tick)
      // delay is needed so it reliably completes before the baseline below
      // is captured — otherwise it can race past updateName() and clobber
      // the merged name back to the stale network value.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final baselineCallCount = getBandCallCount;

      await container
          .read(bandDetailDataProvider('b1').notifier)
          .updateName('New Name');

      final updated = container.read(bandDetailDataProvider('b1')).valueOrNull;
      expect(updated?['name'], 'New Name');
      // Other fields are preserved by the merge, not dropped.
      expect(updated?['id'], 'b1');
      expect(updated?['inviteCode'], 'abc-123');
      // updateName() itself triggered no additional GET /api/band/{bandId}
      // fetch beyond whatever had already happened via the background
      // refresh above.
      expect(getBandCallCount, baselineCallCount);

      // The merged name is also persisted to the local cache.
      final cached = await cacheService.readBandDetail('b1');
      expect(cached?['name'], 'New Name');
    },
  );

  test(
    'a local updateName() mutation is not clobbered by a slower in-flight '
    'background refresh (WR-02)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', {
        'id': 'b1',
        'name': 'Cached Band',
        'ownerId': 'u1',
        'members': [
          {'id': 'u1', 'username': 'alice'},
        ],
        'inviteCode': 'abc-123',
      });

      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'id': 'b1',
            'name': 'Stale Network Name',
            'ownerId': 'u1',
            'members': [
              {'id': 'u1', 'username': 'alice'},
            ],
            'inviteCode': 'abc-123',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);

      // build()'s cache hit fires an unawaited background refresh whose
      // (delayed) response hasn't arrived yet.
      await container.read(bandDetailDataProvider('b1').future);

      await container
          .read(bandDetailDataProvider('b1').notifier)
          .updateName('Locally Renamed');

      // Let the delayed background refresh's response resolve.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final finalState = container
          .read(bandDetailDataProvider('b1'))
          .valueOrNull;
      expect(finalState?['name'], 'Locally Renamed');
    },
  );

  test(
    'a background refresh with no intervening local mutation still updates '
    'state to the fetched data',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', {
        'id': 'b1',
        'name': 'Cached Band',
        'ownerId': 'u1',
        'members': [
          {'id': 'u1', 'username': 'alice'},
        ],
        'inviteCode': 'abc-123',
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'b1',
            'name': 'Fresh Network Name',
            'ownerId': 'u1',
            'members': [
              {'id': 'u1', 'username': 'alice'},
            ],
            'inviteCode': 'abc-123',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);

      await container.read(bandDetailDataProvider('b1').future);
      // Let the unawaited background refresh settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final finalState = container
          .read(bandDetailDataProvider('b1'))
          .valueOrNull;
      expect(finalState?['name'], 'Fresh Network Name');
    },
  );

  test(
    'on a cache hit, bandDetailSyncedAtProvider(bandId) resolves to the '
    "pre-seeded cache's syncedAt before the background refresh settles, "
    'then updates to a later value once the background refresh completes',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', {
        'id': 'b1',
        'name': 'Cached Band',
        'ownerId': 'u1',
        'members': [
          {'id': 'u1', 'username': 'alice'},
        ],
        'inviteCode': 'abc-123',
      });
      final seededSyncedAt = await cacheService.readBandDetailSyncedAt('b1');

      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'id': 'b1',
            'name': 'Fresh Band',
            'ownerId': 'u1',
            'members': [
              {'id': 'u1', 'username': 'alice'},
            ],
            'inviteCode': 'abc-123',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);
      final syncedAtSub = container.listen(
        bandDetailSyncedAtProvider('b1'),
        (_, _) {},
      );
      addTearDown(syncedAtSub.close);

      await container.read(bandDetailDataProvider('b1').future);

      expect(
        container.read(bandDetailSyncedAtProvider('b1')),
        seededSyncedAt,
      );

      // Drain the background refresh fired from build()'s cache hit.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final refreshedSyncedAt = container.read(
        bandDetailSyncedAtProvider('b1'),
      );
      expect(refreshedSyncedAt, isNotNull);
      expect(refreshedSyncedAt!.isAfter(seededSyncedAt!), isTrue);
    },
  );
}
