// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appBarSettingsTitle => 'Настройки';

  @override
  String get sectionThemeTitle => 'Тема';

  @override
  String get themeSystem => 'Система';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get sectionLanguageTitle => 'Язык';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Русский';

  @override
  String get appBarBandsTitle => 'Группы';

  @override
  String get bandsCreateMenuItem => 'Создать группу';

  @override
  String get bandsJoinMenuItem => 'Присоединиться по коду';

  @override
  String get bandsEmptyTitle => 'Пока нет групп';

  @override
  String get bandsEmptyDescription =>
      'Создайте группу или попросите код приглашения у участника, чтобы присоединиться.';

  @override
  String get bandsCreateBandButton => 'Создать группу';

  @override
  String get bandsErrorTitle => 'Не удалось загрузить группы';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonConnectionError =>
      'Проверьте подключение к интернету и попробуйте снова.';

  @override
  String get commonRequiresConnection => 'Требуется подключение';

  @override
  String get bandRoleOwner => 'Владелец';

  @override
  String get bandRoleMember => 'Участник';

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      many: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }
}
