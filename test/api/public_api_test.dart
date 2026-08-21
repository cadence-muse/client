import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/public_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Focused unit tests for [PublicApi], asserting the exact wire contract
/// (method/path/query/body) each method sends, per `lib/api/publicapi.yml`.
/// Provider/screen tests exercise [PublicApi] indirectly; this file proves
/// the HTTP-level contract directly, mirroring the `buildApiClient` pattern
/// used in `test/providers/tracks_provider_test.dart`.
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

  group('removeSetlistTrack', () {
    test(
      'sends DELETE to /api/band/{bandId}/setlist/{setlistId}/tracks with '
      'body {trackIds: [trackId]}',
      () async {
        String? capturedMethod;
        String? capturedPath;
        Map<String, dynamic>? capturedBody;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedMethod = request.method;
            capturedPath = request.url.path;
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('', 204);
          }),
        );

        await api.removeSetlistTrack(
          bandId: 'b1',
          setlistId: 's1',
          trackId: 't1',
        );

        expect(capturedMethod, 'DELETE');
        expect(capturedPath, '/api/band/b1/setlist/s1/tracks');
        expect(capturedBody, {
          'trackIds': ['t1'],
        });
      },
    );

    test('a 204 response resolves without throwing', () async {
      final api = PublicApi(
        buildApiClient((request) async => http.Response('', 204)),
      );

      await expectLater(
        api.removeSetlistTrack(
          bandId: 'b1',
          setlistId: 's1',
          trackId: 't1',
        ),
        completes,
      );
    });
  });

  group('rotateInviteCode', () {
    test(
      'sends POST to /api/band/{bandId}/rotate-invite-code with an empty '
      'body',
      () async {
        String? capturedMethod;
        String? capturedPath;
        String? capturedBody;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedMethod = request.method;
            capturedPath = request.url.path;
            capturedBody = request.body;
            return http.Response(
              jsonEncode({'newInviteCode': 'new-code-123'}),
              200,
            );
          }),
        );

        await api.rotateInviteCode('b1');

        expect(capturedMethod, 'POST');
        expect(capturedPath, '/api/band/b1/rotate-invite-code');
        expect(capturedBody, isEmpty);
      },
    );

    test(
      'a 200 response with {newInviteCode} resolves to that map without '
      'throwing',
      () async {
        final api = PublicApi(
          buildApiClient(
            (request) async => http.Response(
              jsonEncode({'newInviteCode': 'new-code-123'}),
              200,
            ),
          ),
        );

        final result = await api.rotateInviteCode('b1');

        expect(result, {'newInviteCode': 'new-code-123'});
      },
    );
  });

  group('transferOwnership', () {
    test(
      'sends POST to /api/band/{bandId}/transfer-ownership with body '
      '{userId: value}',
      () async {
        String? capturedMethod;
        String? capturedPath;
        Map<String, dynamic>? capturedBody;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedMethod = request.method;
            capturedPath = request.url.path;
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('', 200);
          }),
        );

        await api.transferOwnership(bandId: 'b1', userId: 'u2');

        expect(capturedMethod, 'POST');
        expect(capturedPath, '/api/band/b1/transfer-ownership');
        expect(capturedBody, {'userId': 'u2'});
      },
    );

    test('a 200 response resolves without throwing', () async {
      final api = PublicApi(
        buildApiClient((request) async => http.Response('', 200)),
      );

      await expectLater(
        api.transferOwnership(bandId: 'b1', userId: 'u2'),
        completes,
      );
    });
  });

  group('listUserTracks', () {
    test(
      'calling with bandIdFilter sends POST to /api/track/list with '
      'bandId as a query parameter',
      () async {
        String? capturedMethod;
        String? capturedPath;
        String? capturedBandId;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedMethod = request.method;
            capturedPath = request.url.path;
            capturedBandId = request.url.queryParameters['bandId'];
            return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
          }),
        );

        await api.listUserTracks(bandIdFilter: 'b1');

        expect(capturedMethod, 'POST');
        expect(capturedPath, '/api/track/list');
        expect(capturedBandId, 'b1');
      },
    );

    test(
      'calling with no bandIdFilter and no searchQuery sends POST with no '
      'bandId query parameter',
      () async {
        String? capturedMethod;
        var hasBandId = false;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedMethod = request.method;
            hasBandId = request.url.queryParameters.containsKey('bandId');
            return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
          }),
        );

        await api.listUserTracks();

        expect(capturedMethod, 'POST');
        expect(hasBandId, isFalse);
      },
    );

    test(
      'calling with searchQuery sends a JSON body {searchQuery: value}',
      () async {
        Map<String, dynamic>? capturedBody;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
          }),
        );

        await api.listUserTracks(searchQuery: 'wonderwall');

        expect(capturedBody, {'searchQuery': 'wonderwall'});
      },
    );
  });

  group('listUserSetlists', () {
    test(
      'calling with bandIdFilter sends POST to /api/setlist/list with '
      'bandId as a query parameter',
      () async {
        String? capturedMethod;
        String? capturedPath;
        String? capturedBandId;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedMethod = request.method;
            capturedPath = request.url.path;
            capturedBandId = request.url.queryParameters['bandId'];
            return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
          }),
        );

        await api.listUserSetlists(bandIdFilter: 'b1');

        expect(capturedMethod, 'POST');
        expect(capturedPath, '/api/setlist/list');
        expect(capturedBandId, 'b1');
      },
    );

    test(
      'calling with no bandIdFilter and no searchQuery sends POST with no '
      'bandId query parameter',
      () async {
        String? capturedMethod;
        var hasBandId = false;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedMethod = request.method;
            hasBandId = request.url.queryParameters.containsKey('bandId');
            return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
          }),
        );

        await api.listUserSetlists();

        expect(capturedMethod, 'POST');
        expect(hasBandId, isFalse);
      },
    );

    test(
      'calling with searchQuery sends a JSON body {searchQuery: value}',
      () async {
        Map<String, dynamic>? capturedBody;

        final api = PublicApi(
          buildApiClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
          }),
        );

        await api.listUserSetlists(searchQuery: 'wonderwall');

        expect(capturedBody, {'searchQuery': 'wonderwall'});
      },
    );
  });
}
