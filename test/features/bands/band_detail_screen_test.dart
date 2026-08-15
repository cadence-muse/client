import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_avatar.dart';
import 'package:cadence/features/bands/band_detail_screen.dart';
import 'package:cadence/features/bands/edit_band_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Widget wrap(
    ApiClient apiClient,
    CacheService cacheService, {
    String bandId = 'b1',
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: MaterialApp(home: BandDetailScreen(bandId: bandId)),
    );
  }

  /// Mounts a fake "Bands list" root screen with a button that pushes
  /// [BandDetailScreen] on top of it — mirrors the real app's navigation
  /// depth (list -> detail) so destructive-action tests can assert the
  /// double-pop (dialog -> detail -> list) actually lands back on the list,
  /// not just that the dialog closed.
  Widget wrapWithListRoot(
    ApiClient apiClient,
    CacheService cacheService, {
    required String bandId,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BandDetailScreen(bandId: bandId),
                  ),
                ),
                child: const Text('Bands list root'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Routes a mock handler by request method+path: `/api/me` gets
  /// [profile], `/api/band/{bandId}` (GET) gets [band], and anything else
  /// (DELETE mutations) is delegated to [onMutate].
  ApiClient buildRoutedApiClient({
    required Map<String, dynamic> Function() profile,
    required Map<String, dynamic> Function() band,
    Future<http.Response> Function(http.Request)? onMutate,
  }) {
    return buildApiClient((request) async {
      if (request.url.path == '/api/me') {
        return http.Response(jsonEncode(profile()), 200);
      }
      if (request.method == 'GET') {
        return http.Response(jsonEncode(band()), 200);
      }
      if (onMutate != null) return onMutate(request);
      return http.Response('', 204);
    });
  }

  Map<String, dynamic> band({
    String name = 'The Testers',
    List<Map<String, dynamic>> members = const [
      {'id': 'u1', 'username': 'alice'},
    ],
    String inviteCode = 'abc-123-def',
  }) => {
    'id': 'b1',
    'name': name,
    'ownerId': 'u1',
    'members': members,
    'inviteCode': inviteCode,
  };

  testWidgets(
    'populated screen renders name, BandAvatar, member username, and invite code with Copy',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band());

      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode(band()), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.text('The Testers'), findsWidgets);
      expect(find.byType(BandAvatar), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('abc-123-def'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Copy'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'tapping Copy places the trimmed invite code on the clipboard and shows a Copied! snackbar',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail(
        'b1',
        band(inviteCode: '  abc-123-def  '),
      );

      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode(band(inviteCode: '  abc-123-def  ')),
          200,
        );
      });

      final copiedTexts = <String>[];
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              copiedTexts.add(args['text'] as String);
            }
            return null;
          });
      addTearDown(() {
        TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      await tester.tap(find.widgetWithText(TextButton, 'Copy'));
      await tester.pump();

      expect(copiedTexts, ['abc-123-def']);
      expect(find.text('Copied!'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets('cached data present renders immediately with no spinner', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandDetail('b1', band(name: 'Cached Band'));

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode(band(name: 'Cached Band')), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Cached Band'), findsWidgets);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'background refresh silently replaces displayed data with no spinner',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Old Name'));

      final apiClient = buildApiClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonEncode(band(name: 'New Name')), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.text('Old Name'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('New Name'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('empty members array renders a graceful "No members" fallback', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandDetail('b1', band(members: const []));

    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode(band(members: const [])), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.text('No members'), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'no cache and network failure shows "Couldn\'t load band details" + Retry',
    (tester) async {
      final cacheService = CacheService.inMemory();
      final apiClient = buildApiClient((request) async {
        return http.Response(
          jsonEncode({'code': 'network_error', 'message': 'offline'}),
          500,
        );
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load band details"), findsOneWidget);
      expect(
        find.text('Please check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'band name longer than 30 characters truncates to a single line with ellipsis',
    (tester) async {
      const longName = 'A Band Name That Is Definitely Over Thirty Chars';
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: longName));

      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode(band(name: longName)), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      final headingFinder = find.descendant(
        of: find.byType(ListView),
        matching: find.text(longName),
      );
      final textWidget = tester.widget<Text>(headingFinder);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'tapping Edit, changing the name, and saving updates the name shown '
    'on return to BandDetailScreen (not the stale cached value)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'Old Name'));

      final apiClient = buildApiClient((request) async {
        if (request.method == 'PUT') {
          return http.Response('', 200);
        }
        return http.Response(jsonEncode(band(name: 'Old Name')), 200);
      });

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pump();

      expect(find.text('Old Name'), findsWidgets);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.byType(EditBandScreen), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, 'Old Name');

      await tester.enterText(find.byType(TextFormField), 'New Name');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(EditBandScreen), findsNothing);
      expect(find.byType(BandDetailScreen), findsOneWidget);
      expect(find.text('New Name'), findsWidgets);
      expect(find.text('Old Name'), findsNothing);
    },
  );

  testWidgets('owner sees a "Delete" action, non-owner does not (delete)', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandDetail('b1', band());

    // Owner: profile id matches band()'s ownerId ('u1').
    final ownerApiClient = buildRoutedApiClient(
      profile: () => {'id': 'u1', 'username': 'owner'},
      band: band,
    );

    await tester.pumpWidget(wrap(ownerApiClient, cacheService));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    // Non-owner: profile id doesn't match ownerId.
    final memberCacheService = CacheService.inMemory();
    await memberCacheService.writeBandDetail('b1', band());
    final memberApiClient = buildRoutedApiClient(
      profile: () => {'id': 'u2', 'username': 'member'},
      band: band,
    );

    await tester.pumpWidget(wrap(memberApiClient, memberCacheService));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsNothing);
  });

  testWidgets(
    "Delete button stays disabled until typed text exactly matches the "
    'band name (delete)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'The Band'));
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(name: 'The Band'),
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      FilledButton deleteButton() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete'));

      expect(deleteButton().onPressed, isNull);

      // Case-sensitive near-match must still be disabled.
      await tester.enterText(find.byType(TextField), 'the band');
      await tester.pump();
      expect(deleteButton().onPressed, isNull);

      // Exact match enables it.
      await tester.enterText(find.byType(TextField), 'The Band');
      await tester.pump();
      expect(deleteButton().onPressed, isNotNull);
    },
  );

  testWidgets(
    'confirming Delete calls deleteBand, invalidates the bands list, and '
    'returns to the Bands list (delete)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'The Band'));

      final deleteRequests = <http.Request>[];
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(name: 'The Band'),
        onMutate: (request) async {
          deleteRequests.add(request);
          return http.Response('', 204);
        },
      );

      await tester.pumpWidget(
        wrapWithListRoot(apiClient, cacheService, bandId: 'b1'),
      );
      await tester.tap(find.text('Bands list root'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'The Band');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteRequests, hasLength(1));
      expect(deleteRequests.single.method, 'DELETE');
      expect(deleteRequests.single.url.path, '/api/band/b1');
      expect(find.byType(BandDetailScreen), findsNothing);
      expect(find.text('Bands list root'), findsOneWidget);
    },
  );
}
