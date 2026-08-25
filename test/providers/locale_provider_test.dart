import 'dart:async';

import 'package:cadence/providers/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleController', () {
    test(
      'build() defaults to Locale(en) on a fresh install (no app_locale key)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final locale = await container.read(localeControllerProvider.future);

        expect(locale, const Locale('en'));
      },
    );

    test(
      "build() resolves to Locale(ru) when SharedPreferences 'app_locale' "
      "== 'ru'",
      () async {
        SharedPreferences.setMockInitialValues({'app_locale': 'ru'});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final locale = await container.read(localeControllerProvider.future);

        expect(locale, const Locale('ru'));
      },
    );

    test(
      "build() resolves to Locale(en) when SharedPreferences 'app_locale' "
      "== 'en'",
      () async {
        SharedPreferences.setMockInitialValues({'app_locale': 'en'});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final locale = await container.read(localeControllerProvider.future);

        expect(locale, const Locale('en'));
      },
    );

    test(
      "build() falls back to Locale(en) when SharedPreferences 'app_locale' "
      "holds an unsupported code (e.g. 'fr')",
      () async {
        SharedPreferences.setMockInitialValues({'app_locale': 'fr'});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final locale = await container.read(localeControllerProvider.future);

        expect(locale, const Locale('en'));
      },
    );

    test(
      "setLocale(Locale('ru')) updates state to AsyncData(Locale('ru')) and "
      "persists 'ru' to SharedPreferences",
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(localeControllerProvider.future);

        await container
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('ru'));

        expect(container.read(localeControllerProvider).value, const Locale('ru'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_locale'), 'ru');
      },
    );

    test(
      "setLocale(Locale('en')) updates state to AsyncData(Locale('en')) and "
      "persists 'en' to SharedPreferences",
      () async {
        SharedPreferences.setMockInitialValues({'app_locale': 'ru'});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(localeControllerProvider.future);

        await container
            .read(localeControllerProvider.notifier)
            .setLocale(const Locale('en'));

        expect(container.read(localeControllerProvider).value, const Locale('en'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_locale'), 'en');
      },
    );

    test(
      'three back-to-back unawaited setLocale() calls (en -> ru -> en) '
      'resolve consistently to the last call (en), both in state and '
      'SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(localeControllerProvider.future);
        final notifier = container.read(localeControllerProvider.notifier);

        // Fire the first two without awaiting, only await the last.
        unawaited(notifier.setLocale(const Locale('en')));
        unawaited(notifier.setLocale(const Locale('ru')));
        await notifier.setLocale(const Locale('en'));

        expect(container.read(localeControllerProvider).value, const Locale('en'));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_locale'), 'en');
      },
    );
  });
}
