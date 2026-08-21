import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/offline_no_cache_exception.dart';
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
    CacheService cacheService, {
    bool isOnline = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(isOnline),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Map<String, dynamic> band({String name = 'Band'}) => {
    'id': 'b1',
    'name': name,
    'ownerId': 'u1',
    'members': [
      {'id': 'u1', 'username': 'alice'},
    ],
    'inviteCode': 'abc-123',
  };

  test(
    'online + no cache: build() fetches directly from the API and returns '
    'the fetched detail map',
    () async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(jsonEncode(band(name: 'Fresh Band')), 200);
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandDetailDataProvider('b1').future);

      expect(data['name'], 'Fresh Band');
      expect(callCount, 1);
    },
  );

  test(
    'online + stale cache present: build() returns the FRESH network data, '
    'not the cache',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Stale Cached'));

      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode(band(name: 'Fresh Network')), 200);
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandDetailDataProvider('b1').future);

      expect(data['name'], 'Fresh Network');
    },
  );

  test(
    'online + fetch throws + cache present: build() returns the cached '
    'detail map silently, no AsyncError surfaced (D-03)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Cached Band'));

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'server_error', 'message': 'boom'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandDetailDataProvider('b1').future);

      expect(data['name'], 'Cached Band');
      expect(container.read(bandDetailDataProvider('b1')).hasError, isFalse);
    },
  );

  test(
    'online + fetch throws + no cache: build() rethrows as an AsyncError',
    () async {
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
    },
  );

  test(
    'offline + cache present: build() returns cached data with zero network '
    'calls',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Cached Band'));

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode(band(name: 'Should Not Be Fetched')),
          200,
        );
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      final data = await container.read(bandDetailDataProvider('b1').future);

      expect(data['name'], 'Cached Band');
      expect(callCount, 0);
    },
  );

  test(
    'offline + no cache: build() throws OfflineNoCacheException (D-06)',
    () async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode(band()), 200);
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      await expectLater(
        container.read(bandDetailDataProvider('b1').future),
        throwsA(isA<OfflineNoCacheException>()),
      );
    },
  );

  test(
    'updateName() merges the new name into cached state without an '
    'additional network fetch',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Old Name'));

      var getBandCallCount = 0;
      final apiClient = buildApiClient((request) async {
        getBandCallCount++;
        return http.Response(jsonEncode(band(name: 'Old Name')), 200);
      });

      final container = buildContainer(apiClient, cacheService);

      // bandDetailDataProvider is autoDispose (plain @riverpod); a bare
      // container.read() doesn't hold a subscription, so the provider would
      // get disposed and silently rebuilt between reads. Keep it alive for
      // the duration of this test the same way a watching widget would.
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(
        bandDetailDataProvider('b1').future,
      );
      expect(initial['name'], 'Old Name');
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
      // fetch beyond build()'s own online-first fetch.
      expect(getBandCallCount, baselineCallCount);

      // The merged name is also persisted to the local cache.
      final cached = await cacheService.readBandDetail('b1');
      expect(cached?['name'], 'New Name');
    },
  );

  test(
    'rotateInviteCode() merges the new code into cached state without an '
    'additional network fetch',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band());

      var getBandCallCount = 0;
      final apiClient = buildApiClient((request) async {
        getBandCallCount++;
        return http.Response(jsonEncode(band()), 200);
      });

      final container = buildContainer(apiClient, cacheService);
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);

      final initial = await container.read(
        bandDetailDataProvider('b1').future,
      );
      expect(initial['inviteCode'], 'abc-123');
      final baselineCallCount = getBandCallCount;

      await container
          .read(bandDetailDataProvider('b1').notifier)
          .rotateInviteCode('new-code');

      final updated = container.read(bandDetailDataProvider('b1')).valueOrNull;
      expect(updated?['inviteCode'], 'new-code');
      // Other fields are preserved by the merge, not dropped.
      expect(updated?['id'], 'b1');
      expect(updated?['name'], 'Band');
      // rotateInviteCode() itself triggered no additional
      // GET /api/band/{bandId} fetch beyond build()'s own online-first
      // fetch.
      expect(getBandCallCount, baselineCallCount);

      final cached = await cacheService.readBandDetail('b1');
      expect(cached?['inviteCode'], 'new-code');
    },
  );

  test(
    'a local updateName() mutation is not clobbered by a slower in-flight '
    'refresh() (WR-02)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Cached Band'));

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        if (callCount == 1) {
          // build()'s own online-first fetch — resolves immediately.
          return http.Response(jsonEncode(band(name: 'Cached Band')), 200);
        }
        // The explicit refresh() below — delayed so updateName() below can
        // land first.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode(band(name: 'Stale Network Name')),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);

      await container.read(bandDetailDataProvider('b1').future);

      final notifier = container.read(bandDetailDataProvider('b1').notifier);
      final refreshFuture = notifier.refresh();

      await notifier.updateName('Locally Renamed');

      await refreshFuture;

      final finalState = container
          .read(bandDetailDataProvider('b1'))
          .valueOrNull;
      expect(finalState?['name'], 'Locally Renamed');
    },
  );

  test(
    'a refresh() with no intervening local mutation still updates state to '
    'the fetched data',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Cached Band'));

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(jsonEncode(band(name: 'Cached Band')), 200);
        }
        return http.Response(jsonEncode(band(name: 'Fresh Network')), 200);
      });

      final container = buildContainer(apiClient, cacheService);
      final sub = container.listen(bandDetailDataProvider('b1'), (_, _) {});
      addTearDown(sub.close);

      await container.read(bandDetailDataProvider('b1').future);
      await container.read(bandDetailDataProvider('b1').notifier).refresh();

      final finalState = container
          .read(bandDetailDataProvider('b1'))
          .valueOrNull;
      expect(finalState?['name'], 'Fresh Network');
    },
  );

  test(
    'online build() sets bandDetailSyncedAtProvider(bandId) from the fresh '
    'fetch, later than the stale seeded cache value',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Cached Band'));
      final seededSyncedAt = await cacheService.readBandDetailSyncedAt('b1');

      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode(band(name: 'Fresh Band')), 200);
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

      final syncedAt = container.read(bandDetailSyncedAtProvider('b1'));
      expect(syncedAt, isNotNull);
      expect(syncedAt!.isAfter(seededSyncedAt!), isTrue);
    },
  );
}
