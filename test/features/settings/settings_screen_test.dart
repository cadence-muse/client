import 'package:cadence/features/settings/settings_screen.dart';
import 'package:cadence/generated/app_localizations.dart';
import 'package:cadence/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SettingsScreen` reads `AppLocalizations.of(context)`, which is resolved
/// from `MaterialApp.locale` — so the test harness must bind that to
/// `localeControllerProvider` the same way `CadenceApp` does, or a radio tap
/// changes the provider's state but never touches the rendered locale.
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);

    return locale.when(
      data: (selectedLocale) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru')],
        locale: selectedLocale,
        home: const SettingsScreen(),
      ),
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) =>
          MaterialApp(home: Scaffold(body: Text('Error: $error'))),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildApp() {
    return const ProviderScope(child: _TestApp());
  }

  testWidgets(
    'renders Theme and Language sections in English by default',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Русский updates AppBar title and section headers live, '
    'within the same pumped tree (no restart)',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();

      expect(find.text('Настройки'), findsOneWidget);
      expect(find.text('Тема'), findsOneWidget);
      expect(find.text('Язык'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Theme'), findsNothing);
      expect(find.text('Language'), findsNothing);
    },
  );

  testWidgets(
    'D-06 regression: English/Русский labels stay unchanged after switching '
    'language',
    (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Русский'));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
    },
  );
}
