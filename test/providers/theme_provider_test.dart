import 'package:cadence/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThemeController', () {
    test('build() defaults to ThemeMode.system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeControllerProvider), ThemeMode.system);
    });

    test('setThemeMode() updates the provider state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(themeControllerProvider.notifier).setThemeMode(
        ThemeMode.dark,
      );

      expect(container.read(themeControllerProvider), ThemeMode.dark);
    });
  });
}
