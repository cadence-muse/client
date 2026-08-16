import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/setlists_provider.dart';
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

  group('SetlistListData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandSetlists('b1', [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
          },
        ]);

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Cached Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          setlistListDataProvider('b1').future,
        );

        expect(data, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
          },
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
        container.read(setlistListDataProvider('b1').future),
        throwsA(isA<ApiException>()),
      );
      expect(container.read(setlistListDataProvider('b1')).hasError, isTrue);
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandSetlists('b1', [
        {
          'id': 's1',
          'name': 'Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
        },
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 's1',
                'name': 'Setlist',
                'tracksCount': 1,
                'durationSeconds': 200,
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(setlistListDataProvider('b1'), (_, _) {});
      await container.read(setlistListDataProvider('b1').future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(setlistListDataProvider('b1').notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test(
      'a local removeFromList() mutation is not reverted by a slower '
      'in-flight background refresh that still includes the removed '
      'setlist (WR-02)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandSetlists('b1', [
          {
            'id': 's1',
            'name': 'Setlist One',
            'tracksCount': 1,
            'durationSeconds': 200,
          },
          {
            'id': 's2',
            'name': 'Setlist Two',
            'tracksCount': 2,
            'durationSeconds': 400,
          },
        ]);

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Setlist One',
                  'tracksCount': 1,
                  'durationSeconds': 200,
                },
                {
                  'id': 's2',
                  'name': 'Setlist Two',
                  'tracksCount': 2,
                  'durationSeconds': 400,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistListDataProvider('b1'), (_, _) {});

        // build()'s cache hit fires an unawaited background refresh whose
        // (delayed) response hasn't arrived yet.
        await container.read(setlistListDataProvider('b1').future);

        container
            .read(setlistListDataProvider('b1').notifier)
            .removeFromList('s2');

        // Let the delayed background refresh's response resolve.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = container
            .read(setlistListDataProvider('b1'))
            .valueOrNull;
        expect(finalState, [
          {
            'id': 's1',
            'name': 'Setlist One',
            'tracksCount': 1,
            'durationSeconds': 200,
          },
        ]);
      },
    );
  });

  group('SetlistDetailData', () {
    test(
      'cache-hit returns cached data immediately with a silent background refresh',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 600,
          'tracks': [
            {
              'trackId': 't1',
              'position': 0,
              'title': 'Track One',
              'artist': 'Artist',
            },
          ],
        });

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Cached Setlist',
              'durationSeconds': 600,
              'tracks': [
                {
                  'trackId': 't1',
                  'position': 0,
                  'title': 'Track One',
                  'artist': 'Artist',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          setlistDetailDataProvider('b1', 's1').future,
        );

        expect(data['name'], 'Cached Setlist');
        expect((data['tracks'] as List), hasLength(1));
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
        container.read(setlistDetailDataProvider('b1', 's1').future),
        throwsA(isA<ApiException>()),
      );
      expect(
        container.read(setlistDetailDataProvider('b1', 's1')).hasError,
        isTrue,
      );
    });

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeSetlistDetail('b1', 's1', {
        'id': 's1',
        'name': 'Setlist',
        'durationSeconds': 200,
        'tracks': <Map<String, dynamic>>[],
      });

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'Setlist',
            'durationSeconds': 200,
            'tracks': <Map<String, dynamic>>[],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
      await container.read(setlistDetailDataProvider('b1', 's1').future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      callCount = 0;

      final notifier = container.read(
        setlistDetailDataProvider('b1', 's1').notifier,
      );
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test(
      'a local updateFields() mutation is not clobbered by a slower '
      'in-flight background refresh (WR-02)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 200,
          'tracks': <Map<String, dynamic>>[],
        });

        final apiClient = buildApiClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Cached Setlist',
              'durationSeconds': 200,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});

        // build()'s cache hit fires an unawaited background refresh whose
        // (delayed) response hasn't arrived yet.
        await container.read(setlistDetailDataProvider('b1', 's1').future);

        container
            .read(setlistDetailDataProvider('b1', 's1').notifier)
            .updateFields({'name': 'Locally Renamed Setlist'});

        // Let the delayed background refresh's response resolve.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final finalState = container
            .read(setlistDetailDataProvider('b1', 's1'))
            .valueOrNull;
        expect(finalState, {
          'id': 's1',
          'name': 'Locally Renamed Setlist',
          'durationSeconds': 200,
          'tracks': <Map<String, dynamic>>[],
        });
      },
    );
  });
}
