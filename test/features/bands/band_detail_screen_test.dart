import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_avatar.dart';
import 'package:cadence/features/bands/band_detail_screen.dart';
import 'package:cadence/features/bands/edit_band_screen.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:cadence/providers/connectivity_provider.dart';
import 'package:cadence/widgets/sync_status_badge.dart';
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

  // Defaults isOnlineProvider to true so pre-existing tests (which predate
  // OFFL-03's connectivity gating) keep exercising the "online" path unless a
  // test explicitly overrides it — real-app connectivity_plus resolves
  // AsyncLoading/AsyncError to `false` in this sandboxed test environment
  // with no platform-channel mock, which would otherwise disable every
  // mutation entry point by default.
  Widget wrap(
    ApiClient apiClient,
    CacheService cacheService, {
    String bandId = 'b1',
    bool isOnline = true,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(isOnline),
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
    bool isOnline = true,
  }) {
    return ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(apiClient),
        cacheServiceProvider.overrideWithValue(cacheService),
        isOnlineProvider.overrideWithValue(isOnline),
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

  testWidgets('SyncStatusBadge is present once the band detail loads', (
    tester,
  ) async {
    final cacheService = CacheService.inMemory();
    await cacheService.writeBandDetail('b1', band());
    final apiClient = buildApiClient((request) async {
      return http.Response(jsonEncode(band()), 200);
    });

    await tester.pumpWidget(wrap(apiClient, cacheService));
    await tester.pump();

    expect(find.byType(SyncStatusBadge), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'Edit icon is disabled while offline and enabled while online',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band());
      final apiClient = buildApiClient((request) async {
        return http.Response(jsonEncode(band()), 200);
      });

      await tester.pumpWidget(
        wrap(apiClient, cacheService, isOnline: false),
      );
      await tester.pumpAndSettle();

      final offlineEditButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.edit),
      );
      expect(offlineEditButton.onPressed, isNull);

      final onlineCacheService = CacheService.inMemory();
      await onlineCacheService.writeBandDetail('b1', band());
      await tester.pumpWidget(wrap(apiClient, onlineCacheService));
      await tester.pumpAndSettle();

      final onlineEditButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.edit),
      );
      expect(onlineEditButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'Delete and Leave tiles are disabled while offline (owner sees Delete, '
    'member sees Leave)',
    (tester) async {
      final ownerCacheService = CacheService.inMemory();
      await ownerCacheService.writeBandDetail('b1', band());
      final ownerApiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: band,
      );

      await tester.pumpWidget(
        wrap(ownerApiClient, ownerCacheService, isOnline: false),
      );
      await tester.pumpAndSettle();

      final deleteTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Delete'),
      );
      expect(deleteTile.enabled, isFalse);
      expect(deleteTile.onTap, isNull);

      final memberCacheService = CacheService.inMemory();
      await memberCacheService.writeBandDetail('b1', band());
      final memberApiClient = buildRoutedApiClient(
        profile: () => {'id': 'u2', 'username': 'member'},
        band: band,
      );

      await tester.pumpWidget(
        wrap(memberApiClient, memberCacheService, isOnline: false),
      );
      await tester.pumpAndSettle();

      final leaveTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Leave'),
      );
      expect(leaveTile.enabled, isFalse);
      expect(leaveTile.onTap, isNull);
    },
  );

  testWidgets(
    'Remove icon on a member row is disabled while offline, enabled while '
    'online',
    (tester) async {
      final members = [
        {'id': 'u1', 'username': 'owner'},
        {'id': 'u2', 'username': 'member'},
      ];
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(members: members));
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(members: members),
      );

      await tester.pumpWidget(
        wrap(apiClient, cacheService, isOnline: false),
      );
      await tester.pumpAndSettle();

      final offlineRemoveButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.person_remove),
      );
      expect(offlineRemoveButton.onPressed, isNull);

      final onlineCacheService = CacheService.inMemory();
      await onlineCacheService.writeBandDetail('b1', band(members: members));
      await tester.pumpWidget(wrap(apiClient, onlineCacheService));
      await tester.pumpAndSettle();

      final onlineRemoveButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.person_remove),
      );
      expect(onlineRemoveButton.onPressed, isNotNull);
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
    'D-14: losing connectivity while ConfirmDeleteBandDialog is already '
    'open disables the Delete button live, even with a matching typed name',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'The Band'));
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(name: 'The Band'),
      );

      // Controls connectivityProvider directly (rather than a static
      // isOnlineProvider.overrideWithValue) so the dialog stays mounted
      // across the online -> offline transition, proving live reactivity
      // (D-14) rather than a fresh widget tree picking up a new default.
      final connectivityController = StreamController<ConnectivityStatus>();
      addTearDown(connectivityController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(apiClient),
            cacheServiceProvider.overrideWithValue(cacheService),
            connectivityProvider.overrideWith(
              (ref) => connectivityController.stream,
            ),
          ],
          child: const MaterialApp(home: BandDetailScreen(bandId: 'b1')),
        ),
      );
      connectivityController.add(ConnectivityStatus.online);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'The Band');
      await tester.pump();

      FilledButton deleteButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(deleteButton().onPressed, isNotNull);

      // Connectivity drops while the dialog is still open, name still
      // matching.
      connectivityController.add(ConnectivityStatus.offline);
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Requires connection'),
            )
            .onPressed,
        isNull,
      );
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

  testWidgets(
    'non-owner sees a "Leave" action, owner does not (leave)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band());

      // Non-owner: profile id doesn't match ownerId ('u1').
      final memberApiClient = buildRoutedApiClient(
        profile: () => {'id': 'u2', 'username': 'member'},
        band: band,
      );

      await tester.pumpWidget(wrap(memberApiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('Leave'), findsOneWidget);

      // Owner: profile id matches ownerId.
      final ownerCacheService = CacheService.inMemory();
      await ownerCacheService.writeBandDetail('b1', band());
      final ownerApiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: band,
      );

      await tester.pumpWidget(wrap(ownerApiClient, ownerCacheService));
      await tester.pumpAndSettle();

      expect(find.text('Leave'), findsNothing);
    },
  );

  testWidgets(
    'confirming Leave calls removeMember with the current user\'s own id, '
    'invalidates the bands list, and returns to the Bands list (leave)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band());

      final removeRequests = <http.Request>[];
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u2', 'username': 'member'},
        band: band,
        onMutate: (request) async {
          removeRequests.add(request);
          return http.Response('', 204);
        },
      );

      await tester.pumpWidget(
        wrapWithListRoot(apiClient, cacheService, bandId: 'b1'),
      );
      await tester.tap(find.text('Bands list root'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(removeRequests, hasLength(1));
      expect(removeRequests.single.method, 'DELETE');
      expect(
        removeRequests.single.url.path,
        '/api/band/b1/remove-member/u2',
      );
      expect(find.byType(BandDetailScreen), findsNothing);
      expect(find.text('Bands list root'), findsOneWidget);
    },
  );

  testWidgets(
    'owner sees a "Remove" icon on other members\' rows but never on their '
    'own row; non-owner never sees it (remove-member)',
    (tester) async {
      final members = [
        {'id': 'u1', 'username': 'owner'},
        {'id': 'u2', 'username': 'member'},
      ];
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(members: members));
      final ownerApiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(members: members),
      );

      await tester.pumpWidget(wrap(ownerApiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_remove), findsOneWidget);

      final memberCacheService = CacheService.inMemory();
      await memberCacheService.writeBandDetail('b1', band(members: members));
      final memberApiClient = buildRoutedApiClient(
        profile: () => {'id': 'u2', 'username': 'member'},
        band: () => band(members: members),
      );

      await tester.pumpWidget(wrap(memberApiClient, memberCacheService));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_remove), findsNothing);
    },
  );

  testWidgets(
    'confirming Remove calls removeMember with that member\'s id, '
    'invalidates the band detail, and the removed member disappears from '
    'the members list without leaving the detail screen (remove-member)',
    (tester) async {
      var members = [
        {'id': 'u1', 'username': 'owner'},
        {'id': 'u2', 'username': 'member'},
      ];
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(members: members));

      final removeRequests = <http.Request>[];
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(members: members),
        onMutate: (request) async {
          removeRequests.add(request);
          members = members.where((m) => m['id'] != 'u2').toList();
          return http.Response('', 204);
        },
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      expect(find.text('member'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_remove));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(removeRequests, hasLength(1));
      expect(
        removeRequests.single.url.path,
        '/api/band/b1/remove-member/u2',
      );
      expect(find.byType(BandDetailScreen), findsOneWidget);
      expect(find.text('member'), findsNothing);
      expect(find.text('owner'), findsOneWidget);
    },
  );

  testWidgets(
    'a Delete failure surfaces an inline error and re-enables the Delete '
    'button (remove-member error backstop)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'The Band'));
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(name: 'The Band'),
        onMutate: (request) async => http.Response(
          jsonEncode({'code': 'server_error', 'message': 'Delete failed'}),
          500,
        ),
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'The Band');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete failed'), findsOneWidget);
      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(deleteButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a Leave failure surfaces an inline error and re-enables the Leave '
    'button (remove-member error backstop)',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band());
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u2', 'username': 'member'},
        band: band,
        onMutate: (request) async => http.Response(
          jsonEncode({'code': 'server_error', 'message': 'Leave failed'}),
          500,
        ),
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Leave failed'), findsOneWidget);
      final leaveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Leave'),
      );
      expect(leaveButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a Remove failure surfaces an inline error and re-enables the Remove '
    'button (remove-member error backstop)',
    (tester) async {
      final members = [
        {'id': 'u1', 'username': 'owner'},
        {'id': 'u2', 'username': 'member'},
      ];
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(members: members));
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(members: members),
        onMutate: (request) async => http.Response(
          jsonEncode({'code': 'server_error', 'message': 'Remove failed'}),
          500,
        ),
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_remove));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Remove failed'), findsOneWidget);
      final removeButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Remove'),
      );
      expect(removeButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a Delete failure from a non-ApiException error (e.g. offline) shows '
    'the generic fallback message and re-enables the Delete button',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(name: 'The Band'));
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(name: 'The Band'),
        onMutate: (request) async {
          throw const SocketException('Network is unreachable');
        },
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'The Band');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(deleteButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a Leave failure from a non-ApiException error (e.g. offline) shows '
    'the generic fallback message and re-enables the Leave button',
    (tester) async {
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band());
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u2', 'username': 'member'},
        band: band,
        onMutate: (request) async {
          throw const SocketException('Network is unreachable');
        },
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      final leaveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Leave'),
      );
      expect(leaveButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a Remove failure from a non-ApiException error (e.g. offline) shows '
    'the generic fallback message and re-enables the Remove button',
    (tester) async {
      final members = [
        {'id': 'u1', 'username': 'owner'},
        {'id': 'u2', 'username': 'member'},
      ];
      final cacheService = CacheService.inMemory();
      await cacheService.writeBandDetail('b1', band(members: members));
      final apiClient = buildRoutedApiClient(
        profile: () => {'id': 'u1', 'username': 'owner'},
        band: () => band(members: members),
        onMutate: (request) async {
          throw const SocketException('Network is unreachable');
        },
      );

      await tester.pumpWidget(wrap(apiClient, cacheService));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_remove));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      final removeButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Remove'),
      );
      expect(removeButton.onPressed, isNotNull);
    },
  );
}
