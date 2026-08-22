import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/offline_no_cache_exception.dart';
import 'package:cadence/providers/tracks_provider.dart';
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

  group('TrackListData', () {
    test('online + no cache: build() fetches directly from the API and '
        'returns the fetched list', () async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 't1', 'title': 'Fresh Track', 'artist': 'Fresh Artist'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(trackListDataProvider('b1').future);

      expect(data, [
        {'id': 't1', 'title': 'Fresh Track', 'artist': 'Fresh Artist'},
      ]);
      expect(callCount, 1);
    });

    test('online + stale cache present: build() returns the FRESH network '
        'data, not the cache (online-first ignores a populated cache on the '
        'happy path, not just on a cache miss)', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Stale Cached Track', 'artist': 'Artist'},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 't1', 'title': 'Fresh Network Track', 'artist': 'Artist'},
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(trackListDataProvider('b1').future);

      expect(data, [
        {'id': 't1', 'title': 'Fresh Network Track', 'artist': 'Artist'},
      ]);
    });

    test('online + fetch throws + cache present: build() returns the cached '
        'list silently, no AsyncError surfaced (D-03)', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Cached Track', 'artist': 'Artist'},
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'server_error', 'message': 'boom'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(trackListDataProvider('b1').future);

      expect(data, [
        {'id': 't1', 'title': 'Cached Track', 'artist': 'Artist'},
      ]);
      expect(container.read(trackListDataProvider('b1')).hasError, isFalse);
    });

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
          container.read(trackListDataProvider('b1').future),
          throwsA(isA<ApiException>()),
        );
        expect(container.read(trackListDataProvider('b1')).hasError, isTrue);
      },
    );

    test('offline + cache present: build() returns cached data with zero '
        'network calls', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTracks('b1', [
        {'id': 't1', 'title': 'Cached Track', 'artist': 'Artist'},
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 't1', 'title': 'Should Not Be Fetched', 'artist': 'x'},
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

      final data = await container.read(trackListDataProvider('b1').future);

      expect(data, [
        {'id': 't1', 'title': 'Cached Track', 'artist': 'Artist'},
      ]);
      expect(callCount, 0);
    });

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
          container.read(trackListDataProvider('b1').future),
          throwsA(isA<OfflineNoCacheException>()),
        );
      },
    );

    test(
      'two rapid refresh() calls trigger exactly one network call',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandTracks('b1', [
          {'id': 't1', 'title': 'Track', 'artist': 'Artist'},
        ]);

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track', 'artist': 'Artist'},
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(trackListDataProvider('b1'), (_, _) {});
        await container.read(trackListDataProvider('b1').future);
        callCount = 0;

        final notifier = container.read(trackListDataProvider('b1').notifier);
        final first = notifier.refresh();
        final second = notifier.refresh();
        await Future.wait([first, second]);

        expect(callCount, 1);
      },
    );

    test(
      'a local removeFromList() mutation is not reverted by a slower '
      'in-flight refresh() that still includes the removed track (WR-02)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandTracks('b1', [
          {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
          {'id': 't2', 'title': 'Track Two', 'artist': 'Artist'},
        ]);

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          if (callCount == 1) {
            // build()'s own online-first fetch — resolves immediately.
            return http.Response(
              jsonEncode({
                'items': [
                  {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
                  {'id': 't2', 'title': 'Track Two', 'artist': 'Artist'},
                ],
              }),
              200,
            );
          }
          // The explicit refresh() below — delayed so removeFromList() can
          // land first.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
                {'id': 't2', 'title': 'Track Two', 'artist': 'Artist'},
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(trackListDataProvider('b1'), (_, _) {});

        await container.read(trackListDataProvider('b1').future);

        final notifier = container.read(trackListDataProvider('b1').notifier);
        final refreshFuture = notifier.refresh();

        notifier.removeFromList('t2');

        await refreshFuture;

        final finalState = container
            .read(trackListDataProvider('b1'))
            .valueOrNull;
        expect(finalState, [
          {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
        ]);

        // CR-01 regression: the persisted cache must match the in-memory
        // state — the stale refresh() response must not have overwritten
        // it with the pre-deletion snapshot.
        final cachedTracks = await cacheService.readBandTracks('b1');
        expect(cachedTracks, [
          {'id': 't1', 'title': 'Track One', 'artist': 'Artist'},
        ]);
      },
    );
  });

  group('TrackDetailData', () {
    test('online + no cache: build() fetches directly from the API and '
        'returns the fetched detail', () async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Fresh Track',
            'artist': 'Fresh Artist',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(
        trackDetailDataProvider('b1', 't1').future,
      );

      expect(data, {
        'id': 't1',
        'title': 'Fresh Track',
        'artist': 'Fresh Artist',
      });
      expect(callCount, 1);
    });

    test('online + stale cache present: build() returns the FRESH network '
        'data, not the cache', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTrackDetail('b1', 't1', {
        'id': 't1',
        'title': 'Stale Cached Track',
        'artist': 'Artist',
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Fresh Network Track',
            'artist': 'Artist',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(
        trackDetailDataProvider('b1', 't1').future,
      );

      expect(data, {
        'id': 't1',
        'title': 'Fresh Network Track',
        'artist': 'Artist',
      });
    });

    test('online + fetch throws + cache present: build() returns the cached '
        'detail silently, no AsyncError surfaced (D-03)', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTrackDetail('b1', 't1', {
        'id': 't1',
        'title': 'Cached Track',
        'artist': 'Artist',
      });

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'server_error', 'message': 'boom'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(
        trackDetailDataProvider('b1', 't1').future,
      );

      expect(data, {'id': 't1', 'title': 'Cached Track', 'artist': 'Artist'});
      expect(
        container.read(trackDetailDataProvider('b1', 't1')).hasError,
        isFalse,
      );
    });

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
          container.read(trackDetailDataProvider('b1', 't1').future),
          throwsA(isA<ApiException>()),
        );
        expect(
          container.read(trackDetailDataProvider('b1', 't1')).hasError,
          isTrue,
        );
      },
    );

    test('offline + cache present: build() returns cached data with zero '
        'network calls', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTrackDetail('b1', 't1', {
        'id': 't1',
        'title': 'Cached Track',
        'artist': 'Artist',
      });

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Should Not Be Fetched',
            'artist': 'x',
          }),
          200,
        );
      });

      final container = buildContainer(
        apiClient,
        cacheService,
        isOnline: false,
      );

      final data = await container.read(
        trackDetailDataProvider('b1', 't1').future,
      );

      expect(data, {'id': 't1', 'title': 'Cached Track', 'artist': 'Artist'});
      expect(callCount, 0);
    });

    test(
      'offline + no cache: build() throws OfflineNoCacheException (D-06)',
      () async {
        final cacheService = CacheService.inMemory();
        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({'id': 't1', 'title': 'x', 'artist': 'x'}),
            200,
          );
        });

        final container = buildContainer(
          apiClient,
          cacheService,
          isOnline: false,
        );

        await expectLater(
          container.read(trackDetailDataProvider('b1', 't1').future),
          throwsA(isA<OfflineNoCacheException>()),
        );
      },
    );

    test(
      'two rapid refresh() calls trigger exactly one network call',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandTrackDetail('b1', 't1', {
          'id': 't1',
          'title': 'Track',
          'artist': 'Artist',
        });

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({'id': 't1', 'title': 'Track', 'artist': 'Artist'}),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(trackDetailDataProvider('b1', 't1'), (_, _) {});
        await container.read(trackDetailDataProvider('b1', 't1').future);
        callCount = 0;

        final notifier = container.read(
          trackDetailDataProvider('b1', 't1').notifier,
        );
        final first = notifier.refresh();
        final second = notifier.refresh();
        await Future.wait([first, second]);

        expect(callCount, 1);
      },
    );

    test('a local updateFields() mutation is not clobbered by a slower '
        'in-flight refresh() (WR-02)', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandTrackDetail('b1', 't1', {
        'id': 't1',
        'title': 'Cached Track',
        'artist': 'Cached Artist',
      });

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({
              'id': 't1',
              'title': 'Cached Track',
              'artist': 'Cached Artist',
            }),
            200,
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return http.Response(
          jsonEncode({
            'id': 't1',
            'title': 'Cached Track',
            'artist': 'Cached Artist',
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(trackDetailDataProvider('b1', 't1'), (_, _) {});

      await container.read(trackDetailDataProvider('b1', 't1').future);

      final notifier = container.read(
        trackDetailDataProvider('b1', 't1').notifier,
      );
      final refreshFuture = notifier.refresh();

      notifier.updateFields({'title': 'Locally Renamed Track'});

      await refreshFuture;

      final finalState = container
          .read(trackDetailDataProvider('b1', 't1'))
          .valueOrNull;
      expect(finalState, {
        'id': 't1',
        'title': 'Locally Renamed Track',
        'artist': 'Cached Artist',
      });

      // CR-01 regression: the persisted cache must match the in-memory
      // state — the stale refresh() response must not have overwritten it
      // with the pre-mutation snapshot.
      final cachedTrack = await cacheService.readBandTrackDetail('b1', 't1');
      expect(cachedTrack, {
        'id': 't1',
        'title': 'Locally Renamed Track',
        'artist': 'Cached Artist',
      });
    });
  });

  group('UserTracksListData', () {
    test('online + no cache: build() fetches directly from the API and '
        'returns the fetched list', () async {
      final cacheService = CacheService.inMemory();
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Fresh Track',
                'artist': 'Fresh Artist',
                'bandId': 'b1',
                'bandName': 'Band One',
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(userTracksListDataProvider.future);

      expect(data, [
        {
          'id': 't1',
          'title': 'Fresh Track',
          'artist': 'Fresh Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);
      expect(callCount, 1);
    });

    test('online + stale cache present: build() returns the FRESH network '
        'data, not the cache', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeUserTracks(null, [
        {
          'id': 't1',
          'title': 'Stale Cached Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Fresh Network Track',
                'artist': 'Artist',
                'bandId': 'b1',
                'bandName': 'Band One',
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(userTracksListDataProvider.future);

      expect(data, [
        {
          'id': 't1',
          'title': 'Fresh Network Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);
    });

    test('online + fetch throws + cache present: build() returns the cached '
        'list silently, no AsyncError surfaced (D-03)', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeUserTracks(null, [
        {
          'id': 't1',
          'title': 'Cached Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'server_error', 'message': 'boom'}),
          500,
        );
      });

      final container = buildContainer(apiClient, cacheService);

      final data = await container.read(userTracksListDataProvider.future);

      expect(data, [
        {
          'id': 't1',
          'title': 'Cached Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);
      expect(container.read(userTracksListDataProvider).hasError, isFalse);
    });

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
          container.read(userTracksListDataProvider.future),
          throwsA(isA<ApiException>()),
        );
        expect(container.read(userTracksListDataProvider).hasError, isTrue);
      },
    );

    test('offline + cache present: build() returns cached data with zero '
        'network calls', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeUserTracks(null, [
        {
          'id': 't1',
          'title': 'Cached Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);

      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't1',
                'title': 'Should Not Be Fetched',
                'artist': 'x',
                'bandId': 'b1',
                'bandName': 'Band One',
              },
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

      final data = await container.read(userTracksListDataProvider.future);

      expect(data, [
        {
          'id': 't1',
          'title': 'Cached Track',
          'artist': 'Artist',
          'bandId': 'b1',
          'bandName': 'Band One',
        },
      ]);
      expect(callCount, 0);
    });

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
          container.read(userTracksListDataProvider.future),
          throwsA(isA<OfflineNoCacheException>()),
        );
      },
    );

    test(
      'two rapid refresh() calls trigger exactly one network call',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserTracks(null, [
          {
            'id': 't1',
            'title': 'Track',
            'artist': 'Artist',
            'bandId': 'b1',
            'bandName': 'Band One',
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
                  'id': 't1',
                  'title': 'Track',
                  'artist': 'Artist',
                  'bandId': 'b1',
                  'bandName': 'Band One',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(userTracksListDataProvider, (_, _) {});
        await container.read(userTracksListDataProvider.future);
        callCount = 0;

        final notifier = container.read(userTracksListDataProvider.notifier);
        final first = notifier.refresh();
        final second = notifier.refresh();
        await Future.wait([first, second]);

        expect(callCount, 1);
      },
    );

    test('changing selectedBandIdFilterProvider triggers a rebuild whose '
        'listUserTracks call receives the new bandIdFilter', () async {
      final cacheService = CacheService.inMemory();

      final capturedBandIdFilters = <String?>[];
      final capturedMethods = <String>[];
      final apiClient = buildApiClient((request) async {
        capturedBandIdFilters.add(request.url.queryParameters['bandId']);
        capturedMethods.add(request.method);
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 't2',
                'title': 'Track Two',
                'artist': 'Artist',
                'bandId': 'band-x',
                'bandName': 'Band X',
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(userTracksListDataProvider, (_, _) {});
      await container.read(userTracksListDataProvider.future);
      capturedBandIdFilters.clear();
      capturedMethods.clear();

      container.read(selectedBandIdFilterProvider.notifier).setFilter('band-x');
      await container.read(userTracksListDataProvider.future);

      expect(capturedBandIdFilters, contains('band-x'));
      expect(capturedMethods, everyElement('POST'));
    });
  });
}
