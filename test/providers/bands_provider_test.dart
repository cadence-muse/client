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

  test(
    'online + no cache: build() fetches directly from the API and returns '
    'the fetched list',
    () async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Fresh Band'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandsListDataProvider.future);

      expect(data, [
        {'id': 'a', 'name': 'Fresh Band'},
      ]);
      expect(callCount, 1);
    },
  );

  test(
    'online + stale cache present: build() returns the FRESH network data, '
    'not the cache (online-first ignores a populated cache on the happy '
    'path, not just on a cache miss)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Stale Cached Band'},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Fresh Network Band'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandsListDataProvider.future);

      expect(data, [
        {'id': 'a', 'name': 'Fresh Network Band'},
      ]);
    },
  );

  test(
    'online + fetch throws + cache present: build() returns the cached list '
    'silently, no AsyncError surfaced (D-03)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'server_error', 'message': 'boom'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandsListDataProvider.future);

      expect(data, [
        {'id': 'a', 'name': 'Cached Band'},
      ]);
      expect(container.read(bandsListDataProvider).hasError, isFalse);
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
        container.read(bandsListDataProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(bandsListDataProvider).hasError, isTrue);
    },
  );

  test(
    'offline + cache present: build() returns cached data with zero network '
    'calls',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Should Not Be Fetched'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      final data = await container.read(bandsListDataProvider.future);

      expect(data, [
        {'id': 'a', 'name': 'Cached Band'},
      ]);
      expect(callCount, 0);
    },
  );

  test(
    'offline + no cache: build() throws OfflineNoCacheException (D-06)',
    () async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      await expectLater(
        container.read(bandsListDataProvider.future),
        throwsA(isA<OfflineNoCacheException>()),
      );
    },
  );

  test('two rapid refresh() calls trigger exactly one network call', () async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBands([
      {'id': 'a', 'name': 'Band'},
    ]);

    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'a', 'name': 'Band'},
          ],
        }),
        200,
      );
    });

    final container = buildContainer(apiClient, cacheService);
    // Keep the (autoDispose) provider alive across the gaps below, mirroring
    // the persistent subscription a widget's ref.watch would hold.
    container.listen(bandsListDataProvider, (_, _) {});
    // Drain build()'s own online-first fetch before measuring refresh()'s
    // own dedup behavior.
    await container.read(bandsListDataProvider.future);
    callCount = 0;

    final notifier = container.read(bandsListDataProvider.notifier);
    final first = notifier.refresh();
    final second = notifier.refresh();
    await Future.wait([first, second]);

    expect(callCount, 1);
  });

  test(
    'a local setBands() mutation is not clobbered by a slower in-flight '
    'refresh() (WR-02)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        if (callCount == 1) {
          // build()'s own online-first fetch — resolves immediately.
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'a', 'name': 'Cached Band'},
              ],
            }),
            200,
          );
        }
        // The explicit refresh() below — delayed so setBands() below can
        // land first.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Stale Network Band'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(bandsListDataProvider, (_, _) {});

      await container.read(bandsListDataProvider.future);

      final notifier = container.read(bandsListDataProvider.notifier);
      final refreshFuture = notifier.refresh();

      notifier.setBands([
        {'id': 'a', 'name': 'Locally Renamed Band'},
      ]);

      await refreshFuture;

      final finalState = container.read(bandsListDataProvider).valueOrNull;
      expect(finalState, [
        {'id': 'a', 'name': 'Locally Renamed Band'},
      ]);
    },
  );

  test(
    'a refresh() with no intervening local mutation still updates state to '
    'the fetched data',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 'a', 'name': 'Cached Band'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Fresh Network Band'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(bandsListDataProvider, (_, _) {});

      await container.read(bandsListDataProvider.future);
      await container.read(bandsListDataProvider.notifier).refresh();

      final finalState = container.read(bandsListDataProvider).valueOrNull;
      expect(finalState, [
        {'id': 'a', 'name': 'Fresh Network Band'},
      ]);
    },
  );

  test(
    'renameBand() patches only the matching entry in-place and persists it',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Old'},
        {'id': 'b', 'name': 'Other'},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Old'},
              {'id': 'b', 'name': 'Other'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(bandsListDataProvider, (_, _) {});
      await container.read(bandsListDataProvider.future);

      container.read(bandsListDataProvider.notifier).renameBand('a', 'New');

      final state = container.read(bandsListDataProvider).valueOrNull;
      expect(state, [
        {'id': 'a', 'name': 'New'},
        {'id': 'b', 'name': 'Other'},
      ]);

      final cached = await cacheService.readBands();
      expect(cached, [
        {'id': 'a', 'name': 'New'},
        {'id': 'b', 'name': 'Other'},
      ]);
    },
  );

  test(
    'patchBandOwner() patches only the matching entry\'s ownerId in-place '
    'and persists it',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Band A', 'ownerId': 'u1'},
        {'id': 'b', 'name': 'Band B', 'ownerId': 'u1'},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Band A', 'ownerId': 'u1'},
              {'id': 'b', 'name': 'Band B', 'ownerId': 'u1'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(bandsListDataProvider, (_, _) {});
      await container.read(bandsListDataProvider.future);

      container
          .read(bandsListDataProvider.notifier)
          .patchBandOwner('a', 'newOwnerId');

      final state = container.read(bandsListDataProvider).valueOrNull;
      expect(state, [
        {'id': 'a', 'name': 'Band A', 'ownerId': 'newOwnerId'},
        {'id': 'b', 'name': 'Band B', 'ownerId': 'u1'},
      ]);

      final cached = await cacheService.readBands();
      expect(cached, [
        {'id': 'a', 'name': 'Band A', 'ownerId': 'newOwnerId'},
        {'id': 'b', 'name': 'Band B', 'ownerId': 'u1'},
      ]);
    },
  );

  test(
    'online build() sets bandsListSyncedAtProvider from the fresh fetch, '
    'later than the stale seeded cache value',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);
      final seededSyncedAt = await cacheService.readBandsSyncedAt();

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Fresh Band'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(bandsListDataProvider, (_, _) {});
      container.listen(bandsListSyncedAtProvider, (_, _) {});

      await container.read(bandsListDataProvider.future);

      final syncedAt = container.read(bandsListSyncedAtProvider);
      expect(syncedAt, isNotNull);
      expect(syncedAt!.isAfter(seededSyncedAt!), isTrue);
    },
  );
}
