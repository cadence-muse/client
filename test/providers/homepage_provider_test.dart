import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/homepage_provider.dart';
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
    'the fetched data',
    () async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'username': 'freshuser', 'bandsCount': 2}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(homepageDataProvider.future);

      expect(data, {'username': 'freshuser', 'bandsCount': 2});
      expect(callCount, 1);
    },
  );

  test(
    'online + stale cache present: build() returns the FRESH network data, '
    'not the cache (online-first ignores a populated cache on the happy '
    'path, not just on a cache miss)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({
        'username': 'staleuser',
        'bandsCount': 1,
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': 'freshuser', 'bandsCount': 2}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(homepageDataProvider.future);

      expect(data, {'username': 'freshuser', 'bandsCount': 2});
    },
  );

  test(
    'online + fetch throws + cache present: build() returns the cached data '
    'silently, no AsyncError surfaced (D-03)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({
        'username': 'cacheduser',
        'bandsCount': 2,
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'server_error', 'message': 'boom'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(homepageDataProvider.future);

      expect(data, {'username': 'cacheduser', 'bandsCount': 2});
      expect(container.read(homepageDataProvider).hasError, isFalse);
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
        container.read(homepageDataProvider.future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(homepageDataProvider).hasError, isTrue);
    },
  );

  test(
    'offline + cache present: build() returns cached data with zero network '
    'calls',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({
        'username': 'cacheduser',
        'bandsCount': 2,
      });

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'username': 'shouldnotbe', 'bandsCount': 99}),
          200,
        );
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      final data = await container.read(homepageDataProvider.future);

      expect(data, {'username': 'cacheduser', 'bandsCount': 2});
      expect(callCount, 0);
    },
  );

  test(
    'offline + no cache: build() throws OfflineNoCacheException (D-06)',
    () async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': 'unused', 'bandsCount': 0}),
          200,
        );
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      await expectLater(
        container.read(homepageDataProvider.future),
        throwsA(isA<OfflineNoCacheException>()),
      );
    },
  );

  test('two rapid refresh() calls trigger exactly one network call', () async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeHomepage({'username': 'user', 'bandsCount': 1});

    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response(
        jsonEncode({'username': 'user', 'bandsCount': 1}),
        200,
      );
    });

    final container = buildContainer(apiClient, cacheService);
    // Keep the (autoDispose) provider alive across the gaps below, mirroring
    // the persistent subscription a widget's ref.watch would hold.
    container.listen(homepageDataProvider, (_, _) {});
    // Drain build()'s own online-first fetch before measuring refresh()'s
    // own dedup behavior.
    await container.read(homepageDataProvider.future);
    callCount = 0;

    final notifier = container.read(homepageDataProvider.notifier);
    final first = notifier.refresh();
    final second = notifier.refresh();
    await Future.wait([first, second]);

    expect(callCount, 1);
  });
}
