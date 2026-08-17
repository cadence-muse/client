import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/homepage_provider.dart';
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
    'cache-hit returns cached data immediately with a silent background refresh',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({
        'username': 'cacheduser',
        'bandsCount': 2,
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'username': 'cacheduser', 'bandsCount': 2}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(homepageDataProvider.future);

      expect(data, {'username': 'cacheduser', 'bandsCount': 2});
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
      container.read(homepageDataProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(homepageDataProvider).hasError, isTrue);
  });

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
    // Drain the initial background refresh fired from build()'s cache hit
    // before measuring refresh()'s own dedup behavior.
    await container.read(homepageDataProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    callCount = 0;

    final notifier = container.read(homepageDataProvider.notifier);
    final first = notifier.refresh();
    final second = notifier.refresh();
    await Future.wait([first, second]);

    expect(callCount, 1);
  });

  test(
    'on a cache hit, homepageSyncedAtProvider resolves to the pre-seeded '
    "cache's syncedAt before the background refresh settles, then updates "
    'to a later value once the background refresh completes',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeHomepage({
        'username': 'cacheduser',
        'bandsCount': 2,
      });
      final seededSyncedAt = await cacheService.readHomepageSyncedAt();

      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'username': 'freshuser', 'bandsCount': 3}),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      // Keep both (autoDispose) providers alive across the gaps below,
      // mirroring the persistent subscription a widget's ref.watch would
      // hold in production (HomeScreen watches both).
      container.listen(homepageDataProvider, (_, _) {});
      container.listen(homepageSyncedAtProvider, (_, _) {});

      await container.read(homepageDataProvider.future);

      expect(container.read(homepageSyncedAtProvider), seededSyncedAt);

      // Drain the background refresh fired from build()'s cache hit.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final refreshedSyncedAt = container.read(homepageSyncedAtProvider);
      expect(refreshedSyncedAt, isNotNull);
      expect(refreshedSyncedAt!.isAfter(seededSyncedAt!), isTrue);
    },
  );
}
