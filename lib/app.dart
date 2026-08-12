import 'package:flutter/material.dart';

import 'api/auth_session.dart';
import 'api/public_api.dart';
import 'features/auth/auth_gate.dart';
import 'navigation/root_scaffold.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class CadenceApp extends StatelessWidget {
  const CadenceApp({
    super.key,
    required this.themeController,
    required this.authSession,
    required this.publicApi,
  });

  final ThemeController themeController;
  final AuthSession authSession;
  final PublicApi publicApi;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Cadence',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.value,
          home: AuthGate(
            authSession: authSession,
            publicApi: publicApi,
            builder: (context) => RootScaffold(
              themeController: themeController,
              authSession: authSession,
            ),
          ),
        );
      },
    );
  }
}
