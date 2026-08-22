import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/offline_no_cache_exception.dart';
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

  group('SetlistListData', () {
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
                {
                  'id': 's1',
                  'name': 'Fresh Setlist',
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
            'name': 'Fresh Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
          },
        ]);
        expect(callCount, 1);
      },
    );

    test(
      'online + stale cache present: build() returns the FRESH network '
      'data, not the cache (online-first ignores a populated cache on the '
      'happy path, not just on a cache miss)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeBandSetlists('b1', [
          {
            'id': 's1',
            'name': 'Stale Cached Setlist',
            'tracksCount': 1,
            'durationSeconds': 100,
          },
        ]);

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Fresh Network Setlist',
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
            'name': 'Fresh Network Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
          },
        ]);
      },
    );

    test(
      'online + fetch throws + cache present: build() returns the cached '
      'list silently, no AsyncError surfaced (D-03)',
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
            jsonEncode({'code': 'server_error', 'message': 'boom'}),
            500,
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
        expect(
          container.read(setlistListDataProvider('b1')).hasError,
          isFalse,
        );
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
          container.read(setlistListDataProvider('b1').future),
          throwsA(isA<ApiException>()),
        );
        expect(
          container.read(setlistListDataProvider('b1')).hasError,
          isTrue,
        );
      },
    );

    test(
      'offline + cache present: build() returns cached data with zero '
      'network calls',
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

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Should Not Be Fetched',
                  'tracksCount': 3,
                  'durationSeconds': 600,
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
          container.read(setlistListDataProvider('b1').future),
          throwsA(isA<OfflineNoCacheException>()),
        );
      },
    );

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
      // Drain build()'s own online-first fetch before measuring refresh()'s
      // own dedup behavior.
      await container.read(setlistListDataProvider('b1').future);
      callCount = 0;

      final notifier = container.read(setlistListDataProvider('b1').notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test(
      'a local removeFromList() mutation is not clobbered by a slower '
      'in-flight refresh() (WR-02)',
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

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          if (callCount == 1) {
            // build()'s own online-first fetch — resolves immediately.
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
          }
          // The explicit refresh() below — delayed so removeFromList() can
          // land first.
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

        await container.read(setlistListDataProvider('b1').future);

        final notifier = container.read(
          setlistListDataProvider('b1').notifier,
        );
        final refreshFuture = notifier.refresh();

        notifier.removeFromList('s2');

        await refreshFuture;

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

    test(
      'online build() sets setlistListSyncedAtProvider from the fresh '
      'fetch, later than the stale seeded cache value',
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
        final seededSyncedAt = await cacheService.readBandSetlistsSyncedAt(
          'b1',
        );

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Fresh Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistListDataProvider('b1'), (_, _) {});
        container.listen(setlistListSyncedAtProvider('b1'), (_, _) {});

        await container.read(setlistListDataProvider('b1').future);

        final syncedAt = container.read(setlistListSyncedAtProvider('b1'));
        expect(syncedAt, isNotNull);
        expect(syncedAt!.isAfter(seededSyncedAt!), isTrue);
      },
    );
  });

  group('SetlistDetailData', () {
    test(
      'online + no cache: build() fetches directly from the API and '
      'returns the fetched setlist',
      () async {
        final cacheService = CacheService.inMemory();
        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Fresh Setlist',
              'durationSeconds': 600,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          setlistDetailDataProvider('b1', 's1').future,
        );

        expect(data['name'], 'Fresh Setlist');
        expect(callCount, 1);
      },
    );

    test(
      'online + stale cache present: build() returns the FRESH network '
      'data, not the cache',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Stale Cached Setlist',
          'durationSeconds': 100,
          'tracks': <Map<String, dynamic>>[],
        });

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Fresh Network Setlist',
              'durationSeconds': 600,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          setlistDetailDataProvider('b1', 's1').future,
        );

        expect(data['name'], 'Fresh Network Setlist');
      },
    );

    test(
      'online + fetch throws + cache present: build() returns the cached '
      'setlist silently, no AsyncError surfaced (D-03)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 600,
          'tracks': <Map<String, dynamic>>[],
        });

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({'code': 'server_error', 'message': 'boom'}),
            500,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(
          setlistDetailDataProvider('b1', 's1').future,
        );

        expect(data['name'], 'Cached Setlist');
        expect(
          container.read(setlistDetailDataProvider('b1', 's1')).hasError,
          isFalse,
        );
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
          container.read(setlistDetailDataProvider('b1', 's1').future),
          throwsA(isA<ApiException>()),
        );
        expect(
          container.read(setlistDetailDataProvider('b1', 's1')).hasError,
          isTrue,
        );
      },
    );

    test(
      'offline + cache present: build() returns cached data with zero '
      'network calls',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 600,
          'tracks': <Map<String, dynamic>>[],
        });

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Should Not Be Fetched',
              'durationSeconds': 600,
              'tracks': <Map<String, dynamic>>[],
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
          setlistDetailDataProvider('b1', 's1').future,
        );

        expect(data['name'], 'Cached Setlist');
        expect(callCount, 0);
      },
    );

    test(
      'offline + no cache: build() throws OfflineNoCacheException (D-06)',
      () async {
        final cacheService = CacheService.inMemory();
        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Setlist',
              'durationSeconds': 0,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(
          apiClient,
          cacheService,
          isOnline: false,
        );

        await expectLater(
          container.read(setlistDetailDataProvider('b1', 's1').future),
          throwsA(isA<OfflineNoCacheException>()),
        );
      },
    );

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
      'refresh(force: true) is not silently absorbed into an already '
      'in-flight refresh() — it is guaranteed a fetch that starts no '
      'earlier than its own call (WR-01)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Setlist',
          'durationSeconds': 400,
          'tracks': [
            {
              'trackId': 't1',
              'position': 0,
              'title': 'Song One',
              'artist': 'Artist One',
              'durationSeconds': 200,
            },
            {
              'trackId': 't2',
              'position': 1,
              'title': 'Song Two',
              'artist': 'Artist Two',
              'durationSeconds': 200,
            },
          ],
        });

        var callCount = 0;
        var initialFetchDone = false;
        final apiClient = buildApiClient((request) async {
          callCount++;
          if (!initialFetchDone) {
            initialFetchDone = true;
            // build()'s own online-first fetch — resolves immediately with
            // both tracks still present.
            return http.Response(
              jsonEncode({
                'id': 's1',
                'name': 'Setlist',
                'durationSeconds': 400,
                'tracks': [
                  {
                    'trackId': 't1',
                    'position': 0,
                    'title': 'Song One',
                    'artist': 'Artist One',
                    'durationSeconds': 200,
                  },
                  {
                    'trackId': 't2',
                    'position': 1,
                    'title': 'Song Two',
                    'artist': 'Artist Two',
                    'durationSeconds': 200,
                  },
                ],
              }),
              200,
            );
          }
          if (callCount == 1) {
            // The first refresh() call (e.g. removing t1's post-mutation
            // resync) — held open so a second, forced refresh() call (e.g.
            // removing t2's post-mutation resync) can be requested while
            // this one is still in flight. Resolves with a stale snapshot
            // (as if this fetch had started before t2 was removed
            // server-side).
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return http.Response(
              jsonEncode({
                'id': 's1',
                'name': 'Setlist',
                'durationSeconds': 200,
                'tracks': [
                  {
                    'trackId': 't2',
                    'position': 0,
                    'title': 'Song Two',
                    'artist': 'Artist Two',
                    'durationSeconds': 200,
                  },
                ],
              }),
              200,
            );
          }
          // The queued, forced refresh() call's own fetch — reflects both
          // t1 and t2 having been removed server-side by the time it runs.
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Setlist',
              'durationSeconds': 0,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
        await container.read(setlistDetailDataProvider('b1', 's1').future);
        callCount = 0;

        final notifier = container.read(
          setlistDetailDataProvider('b1', 's1').notifier,
        );
        final first = notifier.refresh();
        final second = notifier.refresh(force: true);
        await Future.wait([first, second]);

        expect(callCount, 2);
        final finalState = container
            .read(setlistDetailDataProvider('b1', 's1'))
            .valueOrNull;
        expect(finalState?['tracks'], <Map<String, dynamic>>[]);
      },
    );

    test(
      'a local updateFields() mutation is not clobbered by a slower '
      'in-flight refresh() (WR-02)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 200,
          'tracks': <Map<String, dynamic>>[],
        });

        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          if (callCount == 1) {
            // build()'s own online-first fetch — resolves immediately.
            return http.Response(
              jsonEncode({
                'id': 's1',
                'name': 'Cached Setlist',
                'durationSeconds': 200,
                'tracks': <Map<String, dynamic>>[],
              }),
              200,
            );
          }
          // The explicit refresh() below — delayed so updateFields() can
          // land first.
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

        await container.read(setlistDetailDataProvider('b1', 's1').future);

        final notifier = container.read(
          setlistDetailDataProvider('b1', 's1').notifier,
        );
        final refreshFuture = notifier.refresh();

        notifier.updateFields({'name': 'Locally Renamed Setlist'});

        await refreshFuture;

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

    test(
      'reorderTracks() reorders the tracks list to match the given trackIds, '
      'preserving each track\'s full map (not just its id)',
      () async {
        final cacheService = CacheService.inMemory();
        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Setlist',
              'durationSeconds': 600,
              'tracks': [
                {
                  'trackId': 'A',
                  'position': 0,
                  'title': 'Track A',
                  'artist': 'Artist A',
                  'durationSeconds': 200,
                },
                {
                  'trackId': 'B',
                  'position': 1,
                  'title': 'Track B',
                  'artist': 'Artist B',
                  'durationSeconds': 200,
                },
                {
                  'trackId': 'C',
                  'position': 2,
                  'title': 'Track C',
                  'artist': 'Artist C',
                  'durationSeconds': 200,
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
        await container.read(setlistDetailDataProvider('b1', 's1').future);

        await container
            .read(setlistDetailDataProvider('b1', 's1').notifier)
            .reorderTracks(['C', 'A', 'B']);

        final tracks =
            container
                    .read(setlistDetailDataProvider('b1', 's1'))
                    .valueOrNull!['tracks']
                as List;
        expect(tracks, [
          {
            'trackId': 'C',
            'position': 2,
            'title': 'Track C',
            'artist': 'Artist C',
            'durationSeconds': 200,
          },
          {
            'trackId': 'A',
            'position': 0,
            'title': 'Track A',
            'artist': 'Artist A',
            'durationSeconds': 200,
          },
          {
            'trackId': 'B',
            'position': 1,
            'title': 'Track B',
            'artist': 'Artist B',
            'durationSeconds': 200,
          },
        ]);
      },
    );

    test(
      'reorderTracks() is a local patch only — it never triggers a network '
      'call',
      () async {
        final cacheService = CacheService.inMemory();
        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Setlist',
              'durationSeconds': 400,
              'tracks': [
                {
                  'trackId': 'A',
                  'position': 0,
                  'title': 'Track A',
                  'artist': 'Artist A',
                },
                {
                  'trackId': 'B',
                  'position': 1,
                  'title': 'Track B',
                  'artist': 'Artist B',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
        await container.read(setlistDetailDataProvider('b1', 's1').future);
        callCount = 0;

        await container
            .read(setlistDetailDataProvider('b1', 's1').notifier)
            .reorderTracks(['B', 'A']);

        expect(callCount, 0);
      },
    );

    test(
      'online build() sets setlistDetailSyncedAtProvider from the fresh '
      'fetch, later than the stale seeded cache value',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeSetlistDetail('b1', 's1', {
          'id': 's1',
          'name': 'Cached Setlist',
          'durationSeconds': 600,
          'tracks': <Map<String, dynamic>>[],
        });
        final seededSyncedAt = await cacheService.readSetlistDetailSyncedAt(
          'b1',
          's1',
        );

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'id': 's1',
              'name': 'Fresh Setlist',
              'durationSeconds': 600,
              'tracks': <Map<String, dynamic>>[],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(setlistDetailDataProvider('b1', 's1'), (_, _) {});
        container.listen(
          setlistDetailSyncedAtProvider('b1', 's1'),
          (_, _) {},
        );

        await container.read(setlistDetailDataProvider('b1', 's1').future);

        final syncedAt = container.read(
          setlistDetailSyncedAtProvider('b1', 's1'),
        );
        expect(syncedAt, isNotNull);
        expect(syncedAt!.isAfter(seededSyncedAt!), isTrue);
      },
    );
  });

  group('UserSetlistsListData', () {
    test(
      'online + no cache: build() fetches directly from the API and '
      'returns the fetched list',
      () async {
        final cacheService = CacheService.inMemory();
        var callCount = 0;
        final apiClient = buildApiClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Fresh Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                  'bandId': 'b1',
                  'bandName': 'Band One',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(userSetlistsListDataProvider.future);

        expect(data, [
          {
            'id': 's1',
            'name': 'Fresh Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);
        expect(callCount, 1);
      },
    );

    test(
      'online + stale cache present: build() returns the FRESH network '
      'data, not the cache',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserSetlists(null, [
          {
            'id': 's1',
            'name': 'Stale Cached Setlist',
            'tracksCount': 1,
            'durationSeconds': 100,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Fresh Network Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                  'bandId': 'b1',
                  'bandName': 'Band One',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);

        final data = await container.read(userSetlistsListDataProvider.future);

        expect(data, [
          {
            'id': 's1',
            'name': 'Fresh Network Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);
      },
    );

    test(
      'online + fetch throws + cache present: build() returns the cached '
      'list silently, no AsyncError surfaced (D-03)',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserSetlists(null, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
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

        final data = await container.read(userSetlistsListDataProvider.future);

        expect(data, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);
        expect(container.read(userSetlistsListDataProvider).hasError, isFalse);
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
          container.read(userSetlistsListDataProvider.future),
          throwsA(isA<ApiException>()),
        );
        expect(container.read(userSetlistsListDataProvider).hasError, isTrue);
      },
    );

    test(
      'offline + cache present: build() returns cached data with zero '
      'network calls',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserSetlists(null, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
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
                  'id': 's1',
                  'name': 'Should Not Be Fetched',
                  'tracksCount': 3,
                  'durationSeconds': 600,
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

        final data = await container.read(userSetlistsListDataProvider.future);

        expect(data, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
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
          container.read(userSetlistsListDataProvider.future),
          throwsA(isA<OfflineNoCacheException>()),
        );
      },
    );

    test('two rapid refresh() calls trigger exactly one network call', () async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeUserSetlists(null, [
        {
          'id': 's1',
          'name': 'Setlist',
          'tracksCount': 1,
          'durationSeconds': 200,
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
                'id': 's1',
                'name': 'Setlist',
                'tracksCount': 1,
                'durationSeconds': 200,
                'bandId': 'b1',
                'bandName': 'Band One',
              },
            ],
          }),
          200,
        );
      });

      final container = buildContainer(apiClient, cacheService);
      container.listen(userSetlistsListDataProvider, (_, _) {});
      await container.read(userSetlistsListDataProvider.future);
      callCount = 0;

      final notifier = container.read(userSetlistsListDataProvider.notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test(
      'online build() sets userSetlistsSyncedAtProvider from the fresh '
      'fetch, later than the stale seeded cache value',
      () async {
        final cacheService = CacheService.inMemory();
        await cacheService.writeUserSetlists(null, [
          {
            'id': 's1',
            'name': 'Cached Setlist',
            'tracksCount': 3,
            'durationSeconds': 600,
            'bandId': 'b1',
            'bandName': 'Band One',
          },
        ]);
        final seededSyncedAt = await cacheService.readUserSetlistsSyncedAt(
          null,
        );

        final apiClient = buildApiClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 's1',
                  'name': 'Fresh Setlist',
                  'tracksCount': 3,
                  'durationSeconds': 600,
                  'bandId': 'b1',
                  'bandName': 'Band One',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(userSetlistsListDataProvider, (_, _) {});
        container.listen(userSetlistsSyncedAtProvider, (_, _) {});

        await container.read(userSetlistsListDataProvider.future);

        final syncedAt = container.read(userSetlistsSyncedAtProvider);
        expect(syncedAt, isNotNull);
        expect(syncedAt!.isAfter(seededSyncedAt!), isTrue);
      },
    );

    test(
      'changing selectedSetlistBandIdFilterProvider triggers a rebuild whose '
      'listUserSetlists call receives the new bandIdFilter',
      () async {
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
                  'id': 's2',
                  'name': 'Setlist Two',
                  'tracksCount': 1,
                  'durationSeconds': 200,
                  'bandId': 'band-x',
                  'bandName': 'Band X',
                },
              ],
            }),
            200,
          );
        });

        final container = buildContainer(apiClient, cacheService);
        container.listen(userSetlistsListDataProvider, (_, _) {});
        await container.read(userSetlistsListDataProvider.future);
        capturedBandIdFilters.clear();
        capturedMethods.clear();

        container
            .read(selectedSetlistBandIdFilterProvider.notifier)
            .setFilter('band-x');
        await container.read(userSetlistsListDataProvider.future);

        expect(capturedBandIdFilters, contains('band-x'));
        expect(capturedMethods, everyElement('POST'));
      },
    );
  });
}
