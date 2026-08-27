import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/edit_setlist_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../test_strings.dart';

void main() {
  const currentSetlist = {
    'id': 's1',
    'name': 'Old Name',
    'eventLocation': 'Old Venue',
    'eventDate': '2026-09-01',
  };

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

  // Defaults isOnlineProvider to true — without an override, connectivity_plus
  // has no platform-channel mock in the test environment and resolves to the
  // fail-safe-offline default, which would break every pre-existing test
  // written before this plan's connectivity gating.
  Widget wrap(
    ApiClient apiClient, {
    CacheService? cacheService,
    Map<String, dynamic>? setlistOverride,
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
                    builder: (_) => EditSetlistScreen(
                      bandId: 'b1',
                      setlistId: 's1',
                      currentSetlist: setlistOverride ?? currentSetlist,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openEditSetlistScreen(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts pre-populated with currentSetlist\'s values', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditSetlistScreen(tester);

    final fields = find
        .byType(TextFormField)
        .evaluate()
        .map((e) => (e.widget as TextFormField).controller!.text)
        .toList();
    expect(fields, ['Old Name', 'Old Venue', '2026-09-01']);
  });

  testWidgets('empty name is rejected without an API call', (tester) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      callCount++;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditSetlistScreen(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(
      find.widgetWithText(FilledButton, tester.strings.commonSave),
    );
    await tester.pump();

    expect(callCount, 0);
    expect(find.text(tester.strings.commonNameRequired), findsOneWidget);
  });

  testWidgets(
    'submitting a changed name calls updateSetlist with the exact request '
    'body and pops back',
    (tester) async {
      String? requestPath;
      String? requestMethod;
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        requestPath = request.url.path;
        requestMethod = request.method;
        requestBody = request.body;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonSave),
      );
      await tester.pumpAndSettle();

      expect(requestMethod, 'PUT');
      expect(requestPath, '/api/band/b1/setlist/s1');
      expect(
        requestBody,
        jsonEncode({
          'name': 'New Name',
          'eventLocation': 'Old Venue',
          'eventDate': '2026-09-01',
        }),
      );
      expect(find.byType(EditSetlistScreen), findsNothing);
    },
  );

  testWidgets(
    'D-17: clearing the location field sends an explicit null instead of '
    'omitting the key',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        requestBody = request.body;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      // TextFormFields in order: Name(0), Location(1), Date(2).
      await tester.enterText(find.byType(TextFormField).at(1), '');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonSave),
      );
      await tester.pumpAndSettle();

      final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
      expect(decoded.containsKey('eventLocation'), isTrue);
      expect(decoded['eventLocation'], isNull);
      expect(decoded['eventDate'], '2026-09-01');
    },
  );

  testWidgets('clearing the date field also sends an explicit null instead of '
      'omitting the key', (tester) async {
    // Date field is readOnly (SETL-13, D-01) — clearing now happens via the
    // clear (X) suffixIcon rather than enterText, which cannot type into a
    // readOnly field.
    String? requestBody;
    final apiClient = buildApiClient((request) async {
      requestBody = request.body;
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditSetlistScreen(tester);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, tester.strings.commonSave),
    );
    await tester.pumpAndSettle();

    final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
    expect(decoded.containsKey('eventDate'), isTrue);
    expect(decoded['eventDate'], isNull);
  });

  testWidgets('Save button is disabled while submitting', (tester) async {
    final apiClient = buildApiClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openEditSetlistScreen(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, tester.strings.commonSave),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'an updateSetlist() failure renders an inline error and re-enables the '
    'Save button',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Name is required'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonSave),
      );
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
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
      await openEditSetlistScreen(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonSave),
      );
      await tester.pumpAndSettle();

      expect(find.text(tester.strings.editSetlistFailedError), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('with isOnlineProvider false, the Save button is disabled with a '
      '"Requires connection" label', (tester) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, isOnline: false));
    await openEditSetlistScreen(tester);

    final offlineButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(offlineButton.onPressed, isNull);
    expect(find.text(tester.strings.commonRequiresConnection), findsOneWidget);
  });

  testWidgets('with isOnlineProvider true, the Save button is enabled', (
    tester,
  ) async {
    final apiClient = buildApiClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(wrap(apiClient, isOnline: true));
    await openEditSetlistScreen(tester);

    final onlineButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(onlineButton.onPressed, isNotNull);
  });

  testWidgets(
    'confirming the picker with the existing date unchanged keeps the date '
    "field showing the setlist's eventDate",
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final dateField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(2),
      );
      expect(dateField.controller!.text, '2026-09-01');
    },
  );

  testWidgets(
    'a malformed persisted eventDate falls back to today as initialDate '
    'without throwing',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        return http.Response('', 200);
      });

      await tester.pumpWidget(
        wrap(
          apiClient,
          setlistOverride: const {
            'id': 's1',
            'name': 'Old Name',
            'eventLocation': 'Old Venue',
            'eventDate': 'not-a-date',
          },
        ),
      );
      await openEditSetlistScreen(tester);
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'with a pre-populated date, the clear icon empties the field and saving '
    'sends eventDate: null',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        requestBody = request.body;
        return http.Response('', 200);
      });

      await tester.pumpWidget(wrap(apiClient));
      await openEditSetlistScreen(tester);

      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      final dateField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(2),
      );
      expect(dateField.controller!.text, '');

      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonSave),
      );
      await tester.pumpAndSettle();

      final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
      expect(decoded.containsKey('eventDate'), isTrue);
      expect(decoded['eventDate'], isNull);
    },
  );
}
