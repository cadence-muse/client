// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appBarSettingsTitle => 'Settings';

  @override
  String get sectionThemeTitle => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sectionLanguageTitle => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get appBarBandsTitle => 'Bands';

  @override
  String get bandsCreateMenuItem => 'Create band';

  @override
  String get bandsJoinMenuItem => 'Join with code';

  @override
  String get bandsEmptyTitle => 'No bands yet';

  @override
  String get bandsEmptyDescription =>
      'Create a band or ask a bandmate for an invite code to join one.';

  @override
  String get bandsCreateBandButton => 'Create Band';

  @override
  String get bandsErrorTitle => 'Couldn\'t load bands';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonConnectionError =>
      'Please check your connection and try again.';

  @override
  String get commonRequiresConnection => 'Requires connection';

  @override
  String get bandRoleOwner => 'Owner';

  @override
  String get bandRoleMember => 'Member';

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }
}
