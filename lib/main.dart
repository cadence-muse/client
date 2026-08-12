import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/auth_session.dart';
import 'api/public_api.dart';
import 'api/token_storage.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'theme/theme_controller.dart';

void main() {
  final authSession = AuthSession(tokenStorage: TokenStorage());
  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl, authSession: authSession);
  final publicApi = PublicApi(apiClient);

  runApp(
    CadenceApp(
      themeController: ThemeController(),
      authSession: authSession,
      publicApi: publicApi,
    ),
  );
}
