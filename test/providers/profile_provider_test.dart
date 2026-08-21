import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/offline_no_cache_exception.dart';
import 'package:cadence/providers/profile_provider.dart';
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
    'the fetched data',
    () async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'freshuser'}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(profileDataProvider.future);

      expect(data, {'id': 'u1', 'username': 'freshuser'});
      expect(callCount, 1);
    },
  );

  test(
    'online + stale cache present: build() returns the FRESH network data, '
    'not the cache (online-first ignores a populated cache on the happy '
    'path, not just on a cache miss)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'staleuser'});

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'freshuser'}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(profileDataProvider.future);

      expect(data, {'id': 'u1', 'username': 'freshuser'});
    },
  );

  test(
    'online + fetch throws + cache present: build() returns the cached data '
    'silently, no AsyncError surfaced (D-03)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'cacheduser'});

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'server_error', 'message': 'boom'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(profileDataProvider.future);

      expect(data, {'id': 'u1', 'username': 'cacheduser'});
      expect(container.read(profileDataProvider).hasError, isFalse);
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
        container.read(profileDataProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(profileDataProvider).hasError, isTrue);
    },
  );

  test(
    'offline + cache present: build() returns cached data with zero network '
    'calls',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'cacheduser'});

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'shouldnotbe'}),
          200,
        );
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      final data = await container.read(profileDataProvider.future);

      expect(data, {'id': 'u1', 'username': 'cacheduser'});
      expect(callCount, 0);
    },
  );

  test(
    'offline + no cache: build() throws OfflineNoCacheException (D-06)',
    () async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'unused'}),
          200,
        );
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      await expectLater(
        container.read(profileDataProvider.future),
        throwsA(isA<OfflineNoCacheException>()),
      );
    },
  );

  test('two rapid refresh() calls trigger exactly one network call', () async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeProfile({'id': 'u1', 'username': 'user'});

    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response(jsonEncode({'id': 'u1', 'username': 'user'}), 200);
    });

    final container = buildContainer(apiClient, cacheService);
    // Keep the (autoDispose) provider alive across the gaps below, mirroring
    // the persistent subscription a widget's ref.watch would hold.
    container.listen(profileDataProvider, (_, _) {});
    // Drain build()'s own online-first fetch before measuring refresh()'s
    // own dedup behavior.
    await container.read(profileDataProvider.future);
    callCount = 0;

    final notifier = container.read(profileDataProvider.notifier);
    final first = notifier.refresh();
    final second = notifier.refresh();
    await Future.wait([first, second]);

    expect(callCount, 1);
  });

  test(
    'online build() sets profileSyncedAtProvider from the fresh fetch, '
    'later than the stale seeded cache value',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeProfile({'id': 'u1', 'username': 'cacheduser'});
      final seededSyncedAt = await cacheService.readProfileSyncedAt();

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'id': 'u1', 'username': 'freshuser'}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(profileDataProvider, (_, _) {});
      container.listen(profileSyncedAtProvider, (_, _) {});

      await container.read(profileDataProvider.future);

      final syncedAt = container.read(profileSyncedAtProvider);
      expect(syncedAt, isNotNull);
      expect(syncedAt!.isAfter(seededSyncedAt!), isTrue);
    },
  );
}
