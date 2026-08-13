import 'package:cadence/api/api_client.dart';
import 'package:cadence/api/auth_session.dart';
import 'package:cadence/api/public_api.dart';
import 'package:cadence/api/token_storage.dart';
import 'package:cadence/app.dart';
import 'package:cadence/theme/theme_controller.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeSecureStorage extends FlutterSecureStoragePlatform with MockPlatformInterfaceMixin {
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
  Future<String?> read({required String key, required Map<String, String> options}) async =>
      _values[key];

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _values.remove(key);
  }

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      _values.containsKey(key);

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async =>
      Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async => _values.clear();
}

void main() {
  testWidgets('bottom navigation switches between tabs', (WidgetTester tester) async {
    FlutterSecureStoragePlatform.instance = _FakeSecureStorage();

    final authSession = AuthSession(tokenStorage: TokenStorage());
    final apiClient = ApiClient(baseUrl: 'http://localhost', authSession: authSession);
    await authSession.signIn('test-token');

    await tester.pumpWidget(
      CadenceApp(
        themeController: ThemeController(),
        authSession: authSession,
        publicApi: PublicApi(apiClient),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);

    await tester.tap(find.text('Bands'));
    await tester.pumpAndSettle();

    expect(find.text('B.A.T.H.'), findsOneWidget);
  });
}
