import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/cache/cache_service.dart';
import 'package:cadence/features/bands/band_avatar.dart';
import 'package:cadence/features/bands/band_detail_screen.dart';
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

}
