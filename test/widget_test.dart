import 'dart:convert';

import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/token_storage.dart';
import 'package:cadence/app.dart';
import 'package:cadence/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeSecureStorage extends FlutterSecureStoragePlatform
    with MockPlatformInterfaceMixin {
  final Map<String, String> _values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    required Map<String, String> options,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _values.remove(key);
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();
}

void main() {
  testWidgets('bottom navigation switches between tabs', (
    WidgetTester tester,
  ) async {
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();
    await TokenStorage().write('test-token');

    // RootScaffold's IndexedStack mounts ProfileScreen (and therefore
    // profileDataProvider) even while the Bands tab is visible, so the real
    // apiClientProvider must not attempt a live network call.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(
              baseUrl: 'http://localhost',
              getToken: () => 'test-token',
              onUnauthorized: () async {},
              httpClient: MockClient(
                (request) async => http.Response(
                  jsonEncode({'id': 'u1', 'username': 'testuser'}),
                  200,
                ),
              ),
            ),
          ),
        ],
        child: const CadenceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Bands'));
    await tester.pumpAndSettle();

    expect(find.text('B.A.T.H.'), findsOneWidget);
  });
}
