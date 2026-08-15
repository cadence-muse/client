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
    'cache-hit returns cached data immediately with a silent background refresh',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a', 'name': 'Cached Band'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(bandsListDataProvider.future);

      expect(data, [
        {'id': 'a', 'name': 'Cached Band'},
      ]);
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
      container.read(bandsListDataProvider.future),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(bandsListDataProvider).hasError, isTrue);
  });

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
    // Drain the initial background refresh fired from build()'s cache hit
    // before measuring refresh()'s own dedup behavior.
    await container.read(bandsListDataProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    callCount = 0;

    final notifier = container.read(bandsListDataProvider.notifier);
    final first = notifier.refresh();
    final second = notifier.refresh();
    await Future.wait([first, second]);

    expect(callCount, 1);
  });

  test(
    'a local setBands() mutation is not clobbered by a slower in-flight '
    'background refresh (WR-02)',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
      ]);

      final apiClient = buildApiClient((request) async {
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

      // build()'s cache hit fires an unawaited background refresh whose
      // (delayed) response hasn't arrived yet.
      await container.read(bandsListDataProvider.future);

      container
          .read(bandsListDataProvider.notifier)
          .setBands([
            {'id': 'a', 'name': 'Locally Renamed Band'},
          ]);

      // Let the delayed background refresh's response resolve.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final finalState = container.read(bandsListDataProvider).valueOrNull;
      expect(finalState, [
        {'id': 'a', 'name': 'Locally Renamed Band'},
      ]);
    },
  );

  test(
    'a background refresh with no intervening local mutation still updates '
    'state to the fetched data',
    () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'a', 'name': 'Cached Band'},
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
      container.listen(bandsListDataProvider, (_, _) {});

      await container.read(bandsListDataProvider.future);
      // Let the unawaited background refresh settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

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
      // Let the background refresh settle so it doesn't race renameBand().
      await Future<void>.delayed(const Duration(milliseconds: 50));

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
}
