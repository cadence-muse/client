import 'package:cadence/providers/connectivity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer buildContainer(Stream<ConnectivityStatus> stream) {
    final container = ProviderContainer(
      overrides: [connectivityProvider.overrideWith((ref) => stream)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('online connectivity stream resolves isOnlineProvider to true', () async {
    final container = buildContainer(
      Stream.value(ConnectivityStatus.online),
    );

    await container.read(connectivityProvider.future);

    expect(container.read(isOnlineProvider), isTrue);
  });

  test(
    'offline connectivity stream resolves isOnlineProvider to false',
    () async {
      final container = buildContainer(
        Stream.value(ConnectivityStatus.offline),
      );

      await container.read(connectivityProvider.future);

      expect(container.read(isOnlineProvider), isFalse);
    },
  );

  test(
    'a connectivity stream error resolves isOnlineProvider to false '
    '(fail-safe offline)',
    () async {
      final container = buildContainer(
        Stream<ConnectivityStatus>.error(Exception('platform channel error')),
      );

      await expectLater(
        container.read(connectivityProvider.future),
        throwsA(isA<Exception>()),
      );

      expect(container.read(isOnlineProvider), isFalse);
    },
  );
}
