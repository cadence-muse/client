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

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0';
  }

  @override
  String slotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count слотов',
      many: '$count слотов',
      few: '$count слота',
      one: '$count слот',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'Главная';

  @override
  String get navBands => 'Группы';

  @override
  String get navTracks => 'Треки';

  @override
  String get navSetlists => 'Сетлисты';

  @override
  String get navProfile => 'Профиль';

  @override
  String get offlineNoCacheTitle => 'Нет сохранённых данных';

  @override
  String get offlineNoCacheDescription =>
      'Подключитесь к интернету, чтобы загрузить данные';

  @override
  String get offlineBannerMessage =>
      'Показаны сохранённые данные — они могут быть устаревшими';

  @override
  String get loginAppTitle => 'Cadence';

  @override
  String get loginUsernameLabel => 'Имя пользователя';

  @override
  String get loginUsernameValidator => 'Введите имя пользователя';

  @override
  String get loginPasswordLabel => 'Пароль';

  @override
  String get loginSignUpButton => 'Зарегистрироваться';

  @override
  String get loginLogInButton => 'Войти';

  @override
  String get loginToggleToLogin => 'Уже есть аккаунт? Войти';

  @override
  String get loginToggleToSignUp => 'Нет аккаунта? Зарегистрироваться';

  @override
  String get loginUsernameTakenError => 'Это имя пользователя уже занято';

  @override
  String get loginInvalidCredentialsError => 'Неверные учётные данные';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonSomethingWentWrong =>
      'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get commonErrorInvalidInput => 'Некорректные данные.';

  @override
  String get commonErrorNotFound => 'Не найдено.';

  @override
  String get commonErrorPermissionDenied => 'Доступ запрещён.';

  @override
  String get commonErrorOperationRejected => 'Это действие сейчас недоступно.';

  @override
  String get commonErrorAlreadyExists => 'Уже существует.';

  @override
  String get commonCouldntLoadTracks => 'Не удалось загрузить треки';

  @override
  String get commonFailedToLoadSetlists =>
      'Не удалось загрузить сетлисты. Нажмите, чтобы повторить.';

  @override
  String get commonActionCannotBeUndone => 'Это действие нельзя отменить.';

  @override
  String get commonAddTracks => 'Добавить треки';

  @override
  String get commonAtLeast8Chars => 'Не менее 8 символов';

  @override
  String get commonFieldRequired => 'Это поле обязательно';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonEnterBandName => 'Введите название группы';

  @override
  String get commonNameRequired => 'Название обязательно';

  @override
  String get commonEnterTrackTitle => 'Введите название трека';

  @override
  String get commonEnterArtistName => 'Введите имя исполнителя';

  @override
  String get commonEnterWholeNumber => 'Введите целое число';

  @override
  String get commonDurationFormatHint =>
      'Введите длительность в формате мм:сс (например, 0:30)';

  @override
  String get commonDurationNegative =>
      'Длительность не может быть отрицательной';

  @override
  String get commonDurationSecondsRange =>
      'Секунды должны быть от 0 до 59 (например, 2:30, а не 2:75)';

  @override
  String get commonDurationHelperText =>
      'например, 2:30 — это 2 минуты 30 секунд';

  @override
  String get commonCreate => 'Создать';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonRotate => 'Сменить';

  @override
  String get commonLeave => 'Покинуть';

  @override
  String get commonRemove => 'Исключить';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonBandNameLabel => 'Название группы';

  @override
  String get commonNameLabel => 'Название';

  @override
  String get commonLocationLabel => 'Место проведения';

  @override
  String get commonDateLabel => 'Дата';

  @override
  String get commonTitleLabel => 'Название';

  @override
  String get commonArtistLabel => 'Исполнитель';

  @override
  String get commonDurationLabel => 'Длительность';

  @override
  String get commonTempoLabel => 'Темп (BPM)';

  @override
  String get commonKeyLabel => 'Тональность';

  @override
  String get commonNotesLabel => 'Заметки';

  @override
  String get commonAllBandsFilter => 'Все группы';

  @override
  String get bandDetailFallbackTitle => 'Группа';

  @override
  String get bandDetailMembersHeader => 'Участники';

  @override
  String get bandDetailNoMembers => 'Нет участников';

  @override
  String get bandDetailMakeOwnerAction => 'Сделать владельцем';

  @override
  String get bandDetailInviteCodeHeader => 'Код приглашения';

  @override
  String get bandDetailErrorTitle => 'Не удалось загрузить данные о группе';

  @override
  String get bandDetailCopiedSnackbar => 'Скопировано!';

  @override
  String get bandDetailCopyTooltip => 'Копировать';

  @override
  String confirmDeleteBandTitle(String bandName) {
    return 'Удалить «$bandName»?';
  }

  @override
  String get confirmDeleteBandBody =>
      'Введите название группы для подтверждения. Это действие нельзя отменить — группа будет удалена для всех участников.';

  @override
  String confirmLeaveBandTitle(String bandName) {
    return 'Покинуть «$bandName»?';
  }

  @override
  String get confirmLeaveBandBody =>
      'Вы больше не будете участником этой группы.';

  @override
  String confirmRemoveMemberTitle(String memberUsername, String bandName) {
    return 'Исключить $memberUsername из группы «$bandName»?';
  }

  @override
  String confirmRemoveMemberBody(String memberUsername) {
    return '$memberUsername больше не будет участником этой группы.';
  }

  @override
  String get confirmRotateInviteCodeTitle => 'Сменить код приглашения?';

  @override
  String get confirmRotateInviteCodeBody =>
      'Текущий код приглашения перестанет действовать немедленно. Участникам, которые ещё не присоединились, понадобится новый код.';

  @override
  String get confirmRotateInviteCodeSnackbar => 'Код приглашения изменён';

  @override
  String confirmTransferOwnershipTitle(String memberUsername) {
    return 'Передать права владельца $memberUsername?';
  }

  @override
  String confirmTransferOwnershipBody(String memberUsername, String bandName) {
    return '$memberUsername станет владельцем этой группы.\n\nВы больше не будете владельцем группы «$bandName».';
  }

  @override
  String get confirmTransferOwnershipButton => 'Передать';

  @override
  String get confirmTransferOwnershipSnackbar => 'Права владельца переданы';

  @override
  String get createBandAppBarTitle => 'Создать новую группу';

  @override
  String createBandSuccessSnackbar(String name) {
    return '«$name» создана!';
  }

  @override
  String get editBandAppBarTitle => 'Изменить группу';

  @override
  String get joinBandTitle => 'Присоединиться к группе';

  @override
  String get joinBandCodeLabel => 'Код приглашения';

  @override
  String get joinBandCodeHint => 'Вставьте код сюда';

  @override
  String get joinBandCodeValidator => 'Введите код приглашения';

  @override
  String get joinBandButton => 'Присоединиться';

  @override
  String get joinBandAmbiguousSnackbar => 'Вы присоединились к группе!';

  @override
  String joinBandSuccessSnackbar(String bandName) {
    return 'Вы присоединились к группе «$bandName»!';
  }

  @override
  String get homeAppBarTitle => 'Главная';

  @override
  String homeWelcomeMessage(String username) {
    return 'Добро пожаловать, $username';
  }

  @override
  String get homeQuickActionsHeader => 'Быстрые действия';

  @override
  String get homeAddBandButton => 'Добавить группу';

  @override
  String get homeAddTrackButton => 'Добавить трек';

  @override
  String get homeAddSetlistButton => 'Добавить сетлист';

  @override
  String get homeErrorTitle => 'Не удалось загрузить главную страницу';

  @override
  String get bandPickerErrorMessage =>
      'Не удалось загрузить группы. Попробуйте ещё раз.';

  @override
  String get profileAppBarTitle => 'Профиль';

  @override
  String get profileIdLabel => 'ID';

  @override
  String get profileSettingsLabel => 'Настройки';

  @override
  String get profileChangePasswordLabel => 'Сменить пароль';

  @override
  String get profileLogOutLabel => 'Выйти';

  @override
  String get profileErrorTitle => 'Не удалось загрузить профиль';

  @override
  String get changePasswordAppBarTitle => 'Смена пароля';

  @override
  String get changePasswordSuccessSnackbar => 'Пароль успешно изменён';

  @override
  String get changePasswordIncorrectCurrentError => 'Неверный текущий пароль';

  @override
  String get changePasswordCurrentLabel => 'Текущий пароль';

  @override
  String get changePasswordNewLabel => 'Новый пароль';

  @override
  String get changePasswordConfirmLabel => 'Подтвердите новый пароль';

  @override
  String get changePasswordMismatchError => 'Пароли не совпадают';

  @override
  String get changePasswordSubmitButton => 'Сменить пароль';

  @override
  String get setlistDetailFallbackTitle => 'Сетлист';

  @override
  String get setlistDetailEditTooltip => 'Изменить сетлист';

  @override
  String get setlistDetailDoneButton => 'Готово';

  @override
  String setlistDetailTracksHeader(int count) {
    return 'Треки ($count)';
  }

  @override
  String get setlistDetailNoTracks => 'В этом сетлисте нет треков';

  @override
  String get setlistDetailRemoveTrackTooltip => 'Удалить';

  @override
  String get setlistDetailRemoveTrackFailedSnackbar =>
      'Не удалось удалить трек. Попробуйте ещё раз.';

  @override
  String get setlistDetailReorderFailedSnackbar =>
      'Не удалось изменить порядок треков. Обновление...';

  @override
  String setlistDetailReorderTooManyTracks(String tracksPhrase) {
    return 'Невозможно изменить порядок — в этом сетлисте больше, чем $tracksPhrase.';
  }

  @override
  String setlistTracksLimit(String tracksPhrase) {
    return 'В сетлисте может быть не более $tracksPhrase.';
  }

  @override
  String get setlistsTabEmptyTitle => 'Сетлистов нет';

  @override
  String get setlistsTabEmptyDescription =>
      'Создавайте сетлисты в группе, чтобы они отображались здесь.';

  @override
  String get createSetlistAppBarTitle => 'Создать сетлист';

  @override
  String get createSetlistDateHint => 'ГГГГ-ММ-ДД';

  @override
  String get createSetlistAddTracksOptionalHeader =>
      'Добавить треки (необязательно)';

  @override
  String get createSetlistNoTracksInBand => 'В этой группе пока нет треков';

  @override
  String get createSetlistFailedError =>
      'Не удалось создать сетлист. Попробуйте ещё раз.';

  @override
  String createSetlistSuccessSnackbar(String name) {
    return '«$name» создан!';
  }

  @override
  String get addSetlistTracksSearchHint => 'Поиск по названию или исполнителю';

  @override
  String addSetlistTracksMaxReached(String tracksPhrase) {
    return 'В этом сетлисте уже максимум — $tracksPhrase.';
  }

  @override
  String get addSetlistTracksNoMatch => 'Нет треков, соответствующих поиску';

  @override
  String get addSetlistTracksNoneAvailable => 'Больше нет доступных треков';

  @override
  String addSetlistTracksRemainingMessage(
    String tracksPhrase,
    String slotsPhrase,
  ) {
    return 'В сетлисте может быть не более $tracksPhrase — осталось $slotsPhrase.';
  }

  @override
  String get addSetlistTracksSubmitButton => 'Добавить';

  @override
  String get addSetlistTracksSuccessSnackbar => 'Треки добавлены!';

  @override
  String get addSetlistTracksFailedError =>
      'Не удалось добавить треки. Попробуйте ещё раз.';

  @override
  String get editSetlistAppBarTitle => 'Изменить сетлист';

  @override
  String get editSetlistFailedError =>
      'Не удалось сохранить сетлист. Попробуйте ещё раз.';

  @override
  String get confirmDeleteSetlistTitle => 'Удалить сетлист?';

  @override
  String get confirmDeleteSetlistFailedError =>
      'Не удалось удалить. Попробуйте ещё раз.';

  @override
  String get setlistListAddButton => 'Добавить сетлист';

  @override
  String get setlistListEmptyTitle => 'Пока нет сетлистов';

  @override
  String get setlistListEmptyDescription =>
      'Создайте сетлист или попросите участника группы добавить его.';

  @override
  String get trackListAddButton => 'Добавить трек';

  @override
  String get trackListEmptyTitle => 'Пока нет треков';

  @override
  String get trackListEmptyDescription =>
      'Создайте трек или попросите участника группы добавить его.';

  @override
  String get trackDetailFallbackTitle => 'Трек';

  @override
  String get trackDetailEditTooltip => 'Изменить трек';

  @override
  String trackDetailTempoLine(int tempo) {
    return 'Темп: $tempo BPM';
  }

  @override
  String confirmDeleteTrackTitle(String trackTitle) {
    return 'Удалить «$trackTitle»?';
  }

  @override
  String get createTrackAppBarTitle => 'Добавить трек';

  @override
  String get createTrackSaveButton => 'Сохранить трек';

  @override
  String createTrackAddedSnackbar(String title) {
    return '«$title» добавлен!';
  }

  @override
  String get editTrackAppBarTitle => 'Изменить трек';

  @override
  String get tracksTabEmptyTitle => 'Треков нет';

  @override
  String get tracksTabEmptyDescription =>
      'Создавайте треки в группе, чтобы они отображались здесь.';

  @override
  String get tracksTabViewBandsButton => 'Перейти к группам';
}
