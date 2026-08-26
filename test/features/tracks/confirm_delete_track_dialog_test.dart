import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/tracks/confirm_delete_track_dialog.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/providers/tracks_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../test_strings.dart';

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

  Widget wrap(
    ApiClient apiClient, {
    CacheService? cacheService,
    bool isOnline = true,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(
          cacheService ?? CacheService.inMemory(),
        ),
        isOnlineProvider.overrideWithValue(isOnline),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (detailContext) => Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => showDialog<void>(
                            context: detailContext,
                            builder: (_) => const ConfirmDeleteTrackDialog(
                              bandId: 'b1',
                              trackId: 't1',
                              trackTitle: 'My Song',
                            ),
                          ),
                          child: const Text('Open dialog'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open dialog'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel pops without calling deleteBandTrack', (tester) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openDialog(tester);
    await tester.tap(
      find.widgetWithText(TextButton, tester.strings.commonCancel),
    );
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(find.byType(ConfirmDeleteTrackDialog), findsNothing);
    expect(find.text('Detail'), findsOneWidget);
  });

  testWidgets(
    'Delete calls deleteBandTrack(bandId, trackId) and double-pops back to '
    'the list',
    (tester) async {
      String? requestPath;
      String? requestMethod;
      final apiClient = buildApiClient((request) async {
        requestPath = request.url.path;
        requestMethod = request.method;
        return http.Response('', 204);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonDelete),
      );
      await tester.pumpAndSettle();

      expect(requestMethod, 'DELETE');
      expect(requestPath, '/api/band/b1/track/t1');
      expect(find.text('Detail'), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, 'Open detail'),
        findsOneWidget,
      );
    },
  );

  testWidgets('CR-03: deleting a track invalidates the global Tracks tab so it '
      'refetches', (tester) async {
    var trackListCallCount = 0;
    final apiClient = buildApiClient((request) async {
      if (request.method == 'DELETE') {
        return http.Response('', 204);
      }
      if (request.url.path == '/api/track/list') {
        trackListCallCount++;
      }
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    });
    final cacheService = CacheService.inMemory();
    await cacheService.writeUserTracks(null, []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          cacheServiceProvider.overrideWithValue(cacheService),
          isOnlineProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ru')],
          home: Consumer(
            builder: (context, ref, _) {
              // Watching userTracksListDataProvider here (as the real
              // global Tracks tab would) is what makes
              // ref.exists(userTracksListDataProvider) true inside the
              // mutation flow below.
              ref.watch(userTracksListDataProvider);
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (detailContext) => Scaffold(
                          appBar: AppBar(title: const Text('Detail')),
                          body: Center(
                            child: ElevatedButton(
                              onPressed: () => showDialog<void>(
                                context: detailContext,
                                builder: (_) => const ConfirmDeleteTrackDialog(
                                  bandId: 'b1',
                                  trackId: 't1',
                                  trackTitle: 'My Song',
                                ),
                              ),
                              child: const Text('Open dialog'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Open detail'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final callCountBeforeMutation = trackListCallCount;

    await openDialog(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, tester.strings.commonDelete),
    );
    await tester.pumpAndSettle();

    expect(trackListCallCount, greaterThan(callCountBeforeMutation));
  });

  testWidgets('the Delete button is disabled while submitting', (tester) async {
    final apiClient = buildApiClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openDialog(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, tester.strings.commonDelete),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'an ApiException on delete shows an inline error inside the dialog and '
    'keeps it open',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Cannot delete track'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openDialog(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonDelete),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot delete track'), findsOneWidget);
      expect(find.byType(ConfirmDeleteTrackDialog), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('the Delete button is disabled while offline', (tester) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient, isOnline: false));
    await openDialog(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('the Delete button is enabled while online', (tester) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 204);
    });

    await tester.pumpWidget(wrap(apiClient, isOnline: true));
    await openDialog(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });
}
