import 'package:flutter/material.dart';

import 'navigation/root_scaffold.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class CadenceApp extends StatelessWidget {
  const CadenceApp({super.key, required this.themeController});

  final ThemeController themeController;

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
          home: RootScaffold(themeController: themeController),
        );
      },
    );
  }
}
