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
}
