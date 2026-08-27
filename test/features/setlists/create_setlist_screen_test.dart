import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/setlists/create_setlist_screen.dart';
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
                    builder: (_) => const CreateSetlistScreen(bandId: 'b1'),
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

  Future<void> openCreateSetlistScreen(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Open'));
    await tester.pumpAndSettle();
  }

  Future<http.Response> defaultHandler(http.Request request) async {
    if (request.url.path == '/api/band/b1/track/list') {
      return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
    }
    return http.Response(jsonEncode({'id': 's1'}), 201);
  }

  testWidgets('empty name is rejected without an API call', (tester) async {
    var callCount = 0;
    final apiClient = buildApiClient((request) async {
      if (request.url.path == '/api/band/b1/track/list') {
        return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
      }
      callCount++;
      return http.Response(jsonEncode({'id': 's1'}), 201);
    });

    await tester.pumpWidget(wrap(apiClient));
    await openCreateSetlistScreen(tester);
    await tester.tap(find.widgetWithText(FilledButton, tester.strings.commonCreate));
    await tester.pump();

    expect(callCount, 0);
    expect(find.text(tester.strings.commonNameRequired), findsOneWidget);
  });

  testWidgets(
    'a createSetlist() ApiException failure renders an inline error and '
    're-enables Create',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        return http.Response(
          jsonEncode({'code': 'bad_request', 'message': 'Name is invalid'}),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.commonCreate));
      await tester.pumpAndSettle();

      expect(find.text('Name is invalid'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a createSetlist() ApiException with a known error code renders the '
    'localized generic message, not the raw server text',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        return http.Response(
          jsonEncode({
            'code': 'permission_denied',
            'message': 'raw server text',
          }),
          400,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.commonCreate));
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.commonErrorPermissionDenied),
        findsOneWidget,
      );
      expect(find.text('raw server text'), findsNothing);
    },
  );

  testWidgets(
    'a non-ApiException failure shows the Setlist-specific fallback message',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        throw const SocketException('Network is unreachable');
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.commonCreate));
      await tester.pumpAndSettle();

      expect(
        find.text(tester.strings.createSetlistFailedError),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'zero band tracks shows "No tracks in this band yet" with the heading '
    'still visible',
    (tester) async {
      final apiClient = buildApiClient(defaultHandler);

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.pump();

      expect(
        find.text(tester.strings.createSetlistAddTracksOptionalHeader),
        findsOneWidget,
      );
      expect(
        find.text(tester.strings.createSetlistNoTracksInBand),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'the Create button disables and shows a spinner while the request is in '
    'flight',
    (tester) async {
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist') {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return http.Response(jsonEncode({'id': 's1'}), 201);
        }
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'My Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.commonCreate));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'submitting with only a name filled in sends null eventLocation/'
    'eventDate/trackIds and pushReplacements to SetlistDetailScreen',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist') {
          requestBody = request.body;
          return http.Response(jsonEncode({'id': 's1'}), 201);
        }
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'My Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.commonCreate));
      await tester.pumpAndSettle();

      expect(requestBody, jsonEncode({'name': 'My Setlist'}));
      expect(
        find.text(tester.strings.createSetlistSuccessSnackbar('My Setlist')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the exact trackIds list sent matches the checked boxes',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 't1', 'title': 'Track One', 'artist': 'Artist One'},
                {'id': 't2', 'title': 'Track Two', 'artist': 'Artist Two'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist') {
          requestBody = request.body;
          return http.Response(jsonEncode({'id': 's1'}), 201);
        }
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'My Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.tap(find.text('Track One'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, tester.strings.commonCreate));
      await tester.pumpAndSettle();

      final decoded = jsonDecode(requestBody!) as Map<String, dynamic>;
      expect(decoded['name'], 'My Setlist');
      expect(decoded['trackIds'], ['t1']);
    },
  );

  testWidgets(
    'with isOnlineProvider false, the Create button is disabled with a '
    '"Requires connection" label',
    (tester) async {
      final apiClient = buildApiClient(defaultHandler);

      await tester.pumpWidget(wrap(apiClient, isOnline: false));
      await openCreateSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.pump();

      final offlineButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(offlineButton.onPressed, isNull);
      expect(
        find.text(tester.strings.commonRequiresConnection),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'with isOnlineProvider true and a valid form, the Create button is '
    'enabled',
    (tester) async {
      final apiClient = buildApiClient(defaultHandler);

      await tester.pumpWidget(wrap(apiClient, isOnline: true));
      await openCreateSetlistScreen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.pump();

      final onlineButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(onlineButton.onPressed, isNotNull);
    },
  );

  testWidgets('tapping the date field opens the native date picker dialog', (
    tester,
  ) async {
    final apiClient = buildApiClient(defaultHandler);

    await tester.pumpWidget(wrap(apiClient));
    await openCreateSetlistScreen(tester);
    await tester.tap(find.byType(TextFormField).at(2));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets(
    'confirming the picker with today unchanged sets the date field to '
    "today's ISO date",
    (tester) async {
      final apiClient = buildApiClient(defaultHandler);

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final dateField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(2),
      );
      expect(
        dateField.controller!.text,
        DateTime.now().toIso8601String().split('T')[0],
      );
    },
  );

  testWidgets(
    'after a date is set, the clear icon empties the field and the request '
    'sends no eventDate',
    (tester) async {
      String? requestBody;
      final apiClient = buildApiClient((request) async {
        if (request.url.path == '/api/band/b1/track/list') {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/band/b1/setlist') {
          requestBody = request.body;
          return http.Response(jsonEncode({'id': 's1'}), 201);
        }
        return http.Response(
          jsonEncode({
            'id': 's1',
            'name': 'My Setlist',
            'durationSeconds': 0,
            'tracks': <dynamic>[],
          }),
          200,
        );
      });

      await tester.pumpWidget(wrap(apiClient));
      await openCreateSetlistScreen(tester);
      await tester.tap(find.byType(TextFormField).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      final dateField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(2),
      );
      expect(dateField.controller!.text, '');

      await tester.enterText(find.byType(TextFormField).at(0), 'My Setlist');
      await tester.tap(
        find.widgetWithText(FilledButton, tester.strings.commonCreate),
      );
      await tester.pumpAndSettle();

      expect(requestBody, jsonEncode({'name': 'My Setlist'}));
    },
  );
}
