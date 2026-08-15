class AppConfig {
  AppConfig._();

  /// Set at build/run time, e.g.
  /// `flutter run --dart-define=API_BASE_URL=https://cadence.app`
  /// or `flutter run --dart-define-from-file=env/config.json`.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
