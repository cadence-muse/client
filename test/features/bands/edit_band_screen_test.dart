import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/edit_band_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/bands_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:flutter/material.dart';
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

  // Defaults isOnlineProvider to true so pre-existing tests (which predate
  // OFFL-03's connectivity gating) keep exercising the "online" path unless a
  // test explicitly overrides it — real-app connectivity_plus resolves
  // AsyncLoading/AsyncError to `false` in this sandboxed test environment
  // with no platform-channel mock, which would otherwise disable the Save
  // button by default.
  Widget wrap(
    ApiClient apiClient, {
    CacheService? cacheService,
    String bandId = 'b1',
    String currentName = 'The Testers',
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
        home: EditBandScreen(bandId: bandId, currentName: currentName),
      ),
    );
  }

  /// Wraps [EditBandScreen] behind a "Home" route so a successful
  /// `Navigator.pop()` back to the caller can actually be observed.
  Widget wrapWithHomeRoute(
    ApiClient apiClient, {
    CacheService? cacheService,
    String bandId = 'b1',
    String currentName = 'The Testers',
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(
          cacheService ?? CacheService.inMemory(),
        ),
        isOnlineProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditBandScreen(
                      bandId: bandId,
                      currentName: currentName,
                    ),
                  ),
                ),
                child: const Text('Open Edit'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens with the name field pre-filled with currentName', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, currentName: 'The Testers'));

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, 'The Testers');
  });

  testWidgets('empty/whitespace-only name is rejected without an API call', (
    tester,
  ) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(callCount, 0);
    expect(find.text('Enter a band name'), findsOneWidget);
  });

  testWidgets('submitting a valid new name calls updateBand and pops back', (
    tester,
  ) async {
    String? requestMethod;
    String? requestPath;
    String? requestBody;
    final apiClient = buildApiClient((request) async {
      requestMethod = request.method;
      requestPath = request.url.path;
      requestBody = request.body;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrapWithHomeRoute(apiClient));
    await tester.tap(find.widgetWithText(FilledButton, 'Open Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(EditBandScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'New Name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(requestMethod, 'PUT');
    expect(requestPath, '/api/band/b1');
    expect(requestBody, jsonEncode({'name': 'New Name'}));
    expect(find.byType(EditBandScreen), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Open Edit'), findsOneWidget);
  });

  testWidgets(
    'an updateBand() failure renders an inline error and re-enables the '
    'Save button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Name is taken'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is taken'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Save button is disabled and reads "Requires connection" while '
    'offline; enabled with a valid form while online',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient, isOnline: false));
      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.pump();

      final offlineButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(offlineButton.onPressed, isNull);
      expect(find.text('Requires connection'), findsOneWidget);

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.pump();

      final onlineButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(onlineButton.onPressed, isNotNull);
      expect(find.text('Save'), findsOneWidget);
    },
  );

  testWidgets(
    'a long/multi-byte-script band name is accepted by the field without a '
    'layout exception',
    (tester) async {
      const longName = 'Группа Very Long Название 乐队名称超过三十个字符长度测试';
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), longName);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
    },
  );

  testWidgets(
    'submitting the same unchanged name still calls updateBand() exactly '
    'once per tap and pops successfully',
    (tester) async {
      var callCount = 0;
      final apiClient = buildApiClient((request) async {
        callCount++;
        return http.Response('', 200);
      });

      await tester.pumpWidget(
        wrapWithHomeRoute(apiClient, currentName: 'The Testers'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Open Edit'));
      await tester.pumpAndSettle();

      // No change to the pre-filled text — submit as-is.
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(find.byType(EditBandScreen), findsNothing);
    },
  );

  testWidgets(
    'a non-ApiException failure (e.g. offline) shows the generic fallback '
    'message and re-enables the Save button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        throw const SocketException('Network is unreachable');
      });

      await tester.pumpWidget(wrap(apiClient));
      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a successful save propagates the rename to bandsListDataProvider\'s '
    'cached list entry (WR-01)',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });
      final cacheService = CacheService.inMemory();
      await cacheService.writeBands([
        {'id': 'b1', 'name': 'The Testers'},
      ]);

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(apiClient),
          cacheServiceProvider.overrideWithValue(cacheService),
          isOnlineProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      // Establish bandsListDataProvider's cached state before the screen
      // mutates it, mirroring BandsScreen already being mounted in
      // RootScaffold's IndexedStack. bandsListDataProvider is autoDispose,
      // so a live listener is needed to keep it alive across the pump below
      // — otherwise it would be torn down and rebuilt from scratch once
      // read() completes and nothing is watching it.
      container.listen(bandsListDataProvider, (_, _) {});
      await container.read(bandsListDataProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EditBandScreen(bandId: 'b1', currentName: 'The Testers'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final bands = container.read(bandsListDataProvider).valueOrNull;
      expect(bands, [
        {'id': 'b1', 'name': 'New Name'},
      ]);
    },
  );
}
