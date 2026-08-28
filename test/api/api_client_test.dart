import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient buildApiClient(
    Future<http.Response> Function(http.Request) handler, {
    required Future<void> Function() onUnauthorized,
  }) {
    return ApiClient(
      baseUrl: 'http://localhost',
      getToken: () => 'test-token',
      onUnauthorized: onUnauthorized,
      httpClient: MockClient(handler),
    );
  }

  test(
    'send() given a mocked 401 response calls onUnauthorized() exactly once '
    'and throws an ApiException with statusCode 401 (new behavior)',
    () async {
      var onUnauthorizedCallCount = 0;
      final client = buildApiClient(
        (request) async => http.Response('', 401),
        onUnauthorized: () async {
          onUnauthorizedCallCount++;
        },
      );

      await expectLater(
        () => client.send('GET', '/api/example'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(onUnauthorizedCallCount, 1);
    },
  );

  test(
    'send() given a mocked 403 response calls onUnauthorized() exactly once '
    'and throws an ApiException with statusCode 403 (regression guard)',
    () async {
      var onUnauthorizedCallCount = 0;
      final client = buildApiClient(
        (request) async => http.Response('', 403),
        onUnauthorized: () async {
          onUnauthorizedCallCount++;
        },
      );

      await expectLater(
        () => client.send('GET', '/api/example'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      expect(onUnauthorizedCallCount, 1);
    },
  );

  test(
    'send() given a mocked 400 response never calls onUnauthorized() and '
    'throws an ApiException with statusCode 400 (regression guard)',
    () async {
      var onUnauthorizedCallCount = 0;
      final client = buildApiClient(
        (request) async => http.Response('', 400),
        onUnauthorized: () async {
          onUnauthorizedCallCount++;
        },
      );

      await expectLater(
        () => client.send('GET', '/api/example'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
      expect(onUnauthorizedCallCount, 0);
    },
  );

  test(
    'send() given a mocked 200 response with a JSON body never calls '
    'onUnauthorized() and returns the decoded map (regression guard)',
    () async {
      var onUnauthorizedCallCount = 0;
      final client = buildApiClient(
        (request) async => http.Response('{"key":"value"}', 200),
        onUnauthorized: () async {
          onUnauthorizedCallCount++;
        },
      );

      final result = await client.send('GET', '/api/example');

      expect(result, {'key': 'value'});
      expect(onUnauthorizedCallCount, 0);
    },
  );
}
