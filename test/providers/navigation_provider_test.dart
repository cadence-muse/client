import 'package:cadence/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelectedTabIndex', () {
    test('build() defaults to 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedTabIndexProvider), 0);
    });

    test('setIndex() updates the provider state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTabIndexProvider.notifier).setIndex(2);

      expect(container.read(selectedTabIndexProvider), 2);
    });
  });
}
