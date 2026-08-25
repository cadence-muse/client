import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_gate.dart';
import 'generated/app_localizations.dart';
import 'navigation/root_scaffold.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

class CadenceApp extends ConsumerWidget {
  const CadenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return locale.when(
      data: (selectedLocale) => MaterialApp(
        title: 'Cadence',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        locale: selectedLocale,
        home: AuthGate(builder: (context) => const RootScaffold()),
      ),
      loading: () => MaterialApp(
        title: 'Cadence',
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => MaterialApp(
        title: 'Cadence',
        home: Scaffold(
          body: Center(child: Text('Error initializing app: $error')),
        ),
      ),
    );
  }
}
