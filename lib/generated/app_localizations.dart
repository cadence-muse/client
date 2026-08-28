import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appBarSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appBarSettingsTitle;

  /// No description provided for @sectionThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get sectionThemeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @sectionLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguageTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @appBarBandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bands'**
  String get appBarBandsTitle;

  /// No description provided for @bandsCreateMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Create band'**
  String get bandsCreateMenuItem;

  /// No description provided for @bandsJoinMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Join with code'**
  String get bandsJoinMenuItem;

  /// No description provided for @bandsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bands yet'**
  String get bandsEmptyTitle;

  /// No description provided for @bandsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a band or ask a bandmate for an invite code to join one.'**
  String get bandsEmptyDescription;

  /// No description provided for @bandsCreateBandButton.
  ///
  /// In en, this message translates to:
  /// **'Create Band'**
  String get bandsCreateBandButton;

  /// No description provided for @bandsErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load bands'**
  String get bandsErrorTitle;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get commonConnectionError;

  /// No description provided for @commonRequiresConnection.
  ///
  /// In en, this message translates to:
  /// **'Requires connection'**
  String get commonRequiresConnection;

  /// No description provided for @bandRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get bandRoleOwner;

  /// No description provided for @bandRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get bandRoleMember;

  /// Pluralized band member count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String memberCount(int count);

  /// Pluralized track count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} track} other{{count} tracks}}'**
  String trackCount(int count);

  /// Pluralized remaining-slot count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} slot} other{{count} slots}}'**
  String slotCount(int count);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navBands.
  ///
  /// In en, this message translates to:
  /// **'Bands'**
  String get navBands;

  /// No description provided for @navTracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get navTracks;

  /// No description provided for @navSetlists.
  ///
  /// In en, this message translates to:
  /// **'Setlists'**
  String get navSetlists;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @offlineNoCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'No cached data'**
  String get offlineNoCacheTitle;

  /// No description provided for @offlineNoCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to load this'**
  String get offlineNoCacheDescription;

  /// No description provided for @offlineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'Showing cached data — may be out of date'**
  String get offlineBannerMessage;

  /// No description provided for @loginAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Cadence'**
  String get loginAppTitle;

  /// No description provided for @loginUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsernameLabel;

  /// No description provided for @loginUsernameValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a username'**
  String get loginUsernameValidator;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginSignUpButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginSignUpButton;

  /// No description provided for @loginLogInButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginLogInButton;

  /// No description provided for @loginToggleToLogin.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get loginToggleToLogin;

  /// No description provided for @loginToggleToSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get loginToggleToSignUp;

  /// No description provided for @loginUsernameTakenError.
  ///
  /// In en, this message translates to:
  /// **'This username is already taken'**
  String get loginUsernameTakenError;

  /// No description provided for @loginInvalidCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get loginInvalidCredentialsError;

  /// No description provided for @loginSessionExpiredSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get loginSessionExpiredSnackbar;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonSomethingWentWrong;

  /// No description provided for @commonErrorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid input.'**
  String get commonErrorInvalidInput;

  /// No description provided for @commonErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get commonErrorNotFound;

  /// No description provided for @commonErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied.'**
  String get commonErrorPermissionDenied;

  /// No description provided for @commonErrorOperationRejected.
  ///
  /// In en, this message translates to:
  /// **'This action isn\'t allowed right now.'**
  String get commonErrorOperationRejected;

  /// No description provided for @commonErrorAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This already exists.'**
  String get commonErrorAlreadyExists;

  /// No description provided for @commonCouldntLoadTracks.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load tracks'**
  String get commonCouldntLoadTracks;

  /// No description provided for @commonFailedToLoadSetlists.
  ///
  /// In en, this message translates to:
  /// **'Failed to load setlists. Tap to try again.'**
  String get commonFailedToLoadSetlists;

  /// No description provided for @commonActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get commonActionCannotBeUndone;

  /// No description provided for @commonAddTracks.
  ///
  /// In en, this message translates to:
  /// **'Add tracks'**
  String get commonAddTracks;

  /// No description provided for @commonNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No tracks found.'**
  String get commonNoSearchResults;

  /// No description provided for @commonNoSetlistSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No setlists found.'**
  String get commonNoSetlistSearchResults;

  /// No description provided for @commonAtLeast8Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get commonAtLeast8Chars;

  /// No description provided for @commonFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get commonFieldRequired;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonEnterBandName.
  ///
  /// In en, this message translates to:
  /// **'Enter a band name'**
  String get commonEnterBandName;

  /// No description provided for @commonNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get commonNameRequired;

  /// No description provided for @commonEnterTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a track title'**
  String get commonEnterTrackTitle;

  /// No description provided for @commonEnterArtistName.
  ///
  /// In en, this message translates to:
  /// **'Enter an artist name'**
  String get commonEnterArtistName;

  /// No description provided for @commonEnterWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get commonEnterWholeNumber;

  /// No description provided for @commonDurationFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Enter duration in mm:ss format (e.g. 0:30)'**
  String get commonDurationFormatHint;

  /// No description provided for @commonDurationNegative.
  ///
  /// In en, this message translates to:
  /// **'Duration cannot be negative'**
  String get commonDurationNegative;

  /// No description provided for @commonDurationSecondsRange.
  ///
  /// In en, this message translates to:
  /// **'Seconds must be 0–59 (e.g. 2:30, not 2:75)'**
  String get commonDurationSecondsRange;

  /// No description provided for @commonDurationHelperText.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2:30 for 2 minutes 30 seconds'**
  String get commonDurationHelperText;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get commonRotate;

  /// No description provided for @commonLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get commonLeave;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonBandNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Band name'**
  String get commonBandNameLabel;

  /// No description provided for @commonNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonNameLabel;

  /// No description provided for @commonLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get commonLocationLabel;

  /// No description provided for @commonDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDateLabel;

  /// No description provided for @commonTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get commonTitleLabel;

  /// No description provided for @commonArtistLabel.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get commonArtistLabel;

  /// No description provided for @commonDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get commonDurationLabel;

  /// No description provided for @commonTempoLabel.
  ///
  /// In en, this message translates to:
  /// **'Tempo (BPM)'**
  String get commonTempoLabel;

  /// No description provided for @commonKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get commonKeyLabel;

  /// No description provided for @commonNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotesLabel;

  /// No description provided for @commonAllBandsFilter.
  ///
  /// In en, this message translates to:
  /// **'All bands'**
  String get commonAllBandsFilter;

  /// No description provided for @bandDetailFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Band'**
  String get bandDetailFallbackTitle;

  /// No description provided for @bandDetailMembersHeader.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get bandDetailMembersHeader;

  /// No description provided for @bandDetailNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get bandDetailNoMembers;

  /// No description provided for @bandDetailMakeOwnerAction.
  ///
  /// In en, this message translates to:
  /// **'Make owner'**
  String get bandDetailMakeOwnerAction;

  /// No description provided for @bandDetailInviteCodeHeader.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get bandDetailInviteCodeHeader;

  /// No description provided for @bandDetailErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load band details'**
  String get bandDetailErrorTitle;

  /// No description provided for @bandDetailCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get bandDetailCopiedSnackbar;

  /// No description provided for @bandDetailCopyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get bandDetailCopyTooltip;

  /// No description provided for @confirmDeleteBandTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {bandName}?'**
  String confirmDeleteBandTitle(String bandName);

  /// No description provided for @confirmDeleteBandBody.
  ///
  /// In en, this message translates to:
  /// **'Type the band name to confirm. This action cannot be undone and will remove the band for all members.'**
  String get confirmDeleteBandBody;

  /// No description provided for @confirmLeaveBandTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {bandName}?'**
  String confirmLeaveBandTitle(String bandName);

  /// No description provided for @confirmLeaveBandBody.
  ///
  /// In en, this message translates to:
  /// **'You will no longer be a member of this band.'**
  String get confirmLeaveBandBody;

  /// No description provided for @confirmRemoveMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {memberUsername} from {bandName}?'**
  String confirmRemoveMemberTitle(String memberUsername, String bandName);

  /// No description provided for @confirmRemoveMemberBody.
  ///
  /// In en, this message translates to:
  /// **'{memberUsername} will no longer be a member of this band.'**
  String confirmRemoveMemberBody(String memberUsername);

  /// No description provided for @confirmRotateInviteCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Rotate invite code?'**
  String get confirmRotateInviteCodeTitle;

  /// No description provided for @confirmRotateInviteCodeBody.
  ///
  /// In en, this message translates to:
  /// **'The current invite code will stop working immediately. Any member who hasn\'t joined yet will need the new code.'**
  String get confirmRotateInviteCodeBody;

  /// No description provided for @confirmRotateInviteCodeSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Invite code rotated'**
  String get confirmRotateInviteCodeSnackbar;

  /// No description provided for @confirmTransferOwnershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership to {memberUsername}?'**
  String confirmTransferOwnershipTitle(String memberUsername);

  /// No description provided for @confirmTransferOwnershipBody.
  ///
  /// In en, this message translates to:
  /// **'{memberUsername} will become the owner of this band.\n\nYou will no longer be the owner of {bandName}.'**
  String confirmTransferOwnershipBody(String memberUsername, String bandName);

  /// No description provided for @confirmTransferOwnershipButton.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get confirmTransferOwnershipButton;

  /// No description provided for @confirmTransferOwnershipSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Ownership transferred'**
  String get confirmTransferOwnershipSnackbar;

  /// No description provided for @createBandAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new band'**
  String get createBandAppBarTitle;

  /// No description provided for @createBandSuccessSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{name} created!'**
  String createBandSuccessSnackbar(String name);

  /// No description provided for @editBandAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit band'**
  String get editBandAppBarTitle;

  /// No description provided for @joinBandTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a band'**
  String get joinBandTitle;

  /// No description provided for @joinBandCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get joinBandCodeLabel;

  /// No description provided for @joinBandCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the code here'**
  String get joinBandCodeHint;

  /// No description provided for @joinBandCodeValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code'**
  String get joinBandCodeValidator;

  /// No description provided for @joinBandButton.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinBandButton;

  /// No description provided for @joinBandAmbiguousSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Joined band!'**
  String get joinBandAmbiguousSnackbar;

  /// No description provided for @joinBandSuccessSnackbar.
  ///
  /// In en, this message translates to:
  /// **'You\'ve joined {bandName}!'**
  String joinBandSuccessSnackbar(String bandName);

  /// No description provided for @homeAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeAppBarTitle;

  /// No description provided for @homeWelcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {username}'**
  String homeWelcomeMessage(String username);

  /// No description provided for @homeQuickActionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get homeQuickActionsHeader;

  /// No description provided for @homeAddBandButton.
  ///
  /// In en, this message translates to:
  /// **'Add Band'**
  String get homeAddBandButton;

  /// No description provided for @homeAddTrackButton.
  ///
  /// In en, this message translates to:
  /// **'Add Track'**
  String get homeAddTrackButton;

  /// No description provided for @homeAddSetlistButton.
  ///
  /// In en, this message translates to:
  /// **'Add Setlist'**
  String get homeAddSetlistButton;

  /// No description provided for @homeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load home'**
  String get homeErrorTitle;

  /// No description provided for @bandPickerErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not load bands. Please try again.'**
  String get bandPickerErrorMessage;

  /// No description provided for @profileAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileAppBarTitle;

  /// No description provided for @profileIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get profileIdLabel;

  /// No description provided for @profileSettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsLabel;

  /// No description provided for @profileChangePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get profileChangePasswordLabel;

  /// No description provided for @profileLogOutLabel.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogOutLabel;

  /// No description provided for @profileErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load profile'**
  String get profileErrorTitle;

  /// No description provided for @changePasswordAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordAppBarTitle;

  /// No description provided for @changePasswordSuccessSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get changePasswordSuccessSnackbar;

  /// No description provided for @changePasswordIncorrectCurrentError.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get changePasswordIncorrectCurrentError;

  /// No description provided for @changePasswordCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get changePasswordCurrentLabel;

  /// No description provided for @changePasswordNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get changePasswordNewLabel;

  /// No description provided for @changePasswordConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get changePasswordConfirmLabel;

  /// No description provided for @changePasswordMismatchError.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get changePasswordMismatchError;

  /// No description provided for @changePasswordSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordSubmitButton;

  /// No description provided for @setlistDetailFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Setlist'**
  String get setlistDetailFallbackTitle;

  /// No description provided for @setlistDetailEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit setlist'**
  String get setlistDetailEditTooltip;

  /// No description provided for @setlistDetailDoneButton.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get setlistDetailDoneButton;

  /// No description provided for @setlistDetailTracksHeader.
  ///
  /// In en, this message translates to:
  /// **'Tracks ({count})'**
  String setlistDetailTracksHeader(int count);

  /// No description provided for @setlistDetailNoTracks.
  ///
  /// In en, this message translates to:
  /// **'No tracks in this setlist'**
  String get setlistDetailNoTracks;

  /// No description provided for @setlistDetailRemoveTrackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get setlistDetailRemoveTrackTooltip;

  /// No description provided for @setlistDetailRemoveTrackFailedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove track. Try again.'**
  String get setlistDetailRemoveTrackFailedSnackbar;

  /// No description provided for @setlistDetailReorderFailedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Failed to reorder tracks. Refreshing...'**
  String get setlistDetailReorderFailedSnackbar;

  /// No description provided for @setlistDetailReorderTooManyTracks.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reorder — this setlist has more than {tracksPhrase}.'**
  String setlistDetailReorderTooManyTracks(String tracksPhrase);

  /// No description provided for @setlistTracksLimit.
  ///
  /// In en, this message translates to:
  /// **'Setlists can have at most {tracksPhrase}.'**
  String setlistTracksLimit(String tracksPhrase);

  /// No description provided for @setlistsTabEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No setlists'**
  String get setlistsTabEmptyTitle;

  /// No description provided for @setlistsTabEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create setlists in a band to see them here.'**
  String get setlistsTabEmptyDescription;

  /// No description provided for @setlistsTabSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get setlistsTabSearchHint;

  /// No description provided for @createSetlistAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Create setlist'**
  String get createSetlistAppBarTitle;

  /// No description provided for @createSetlistDateHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get createSetlistDateHint;

  /// No description provided for @createSetlistAddTracksOptionalHeader.
  ///
  /// In en, this message translates to:
  /// **'Add tracks (optional)'**
  String get createSetlistAddTracksOptionalHeader;

  /// No description provided for @createSetlistNoTracksInBand.
  ///
  /// In en, this message translates to:
  /// **'No tracks in this band yet'**
  String get createSetlistNoTracksInBand;

  /// No description provided for @createSetlistFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to create setlist. Try again.'**
  String get createSetlistFailedError;

  /// No description provided for @createSetlistSuccessSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{name} created!'**
  String createSetlistSuccessSnackbar(String name);

  /// No description provided for @addSetlistTracksSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by title or artist'**
  String get addSetlistTracksSearchHint;

  /// No description provided for @addSetlistTracksMaxReached.
  ///
  /// In en, this message translates to:
  /// **'This setlist already has the maximum of {tracksPhrase}.'**
  String addSetlistTracksMaxReached(String tracksPhrase);

  /// No description provided for @addSetlistTracksNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No tracks match your search'**
  String get addSetlistTracksNoMatch;

  /// No description provided for @addSetlistTracksNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No more tracks available'**
  String get addSetlistTracksNoneAvailable;

  /// No description provided for @addSetlistTracksRemainingMessage.
  ///
  /// In en, this message translates to:
  /// **'Setlists can have at most {tracksPhrase} — {slotsPhrase} remaining.'**
  String addSetlistTracksRemainingMessage(
    String tracksPhrase,
    String slotsPhrase,
  );

  /// No description provided for @addSetlistTracksSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addSetlistTracksSubmitButton;

  /// No description provided for @addSetlistTracksSuccessSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Tracks added!'**
  String get addSetlistTracksSuccessSnackbar;

  /// No description provided for @addSetlistTracksFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to add tracks. Try again.'**
  String get addSetlistTracksFailedError;

  /// No description provided for @editSetlistAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit setlist'**
  String get editSetlistAppBarTitle;

  /// No description provided for @editSetlistFailedError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save setlist. Try again.'**
  String get editSetlistFailedError;

  /// No description provided for @confirmDeleteSetlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete setlist?'**
  String get confirmDeleteSetlistTitle;

  /// No description provided for @confirmDeleteSetlistFailedError.
  ///
  /// In en, this message translates to:
  /// **'Delete failed. Try again.'**
  String get confirmDeleteSetlistFailedError;

  /// No description provided for @setlistListAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add setlist'**
  String get setlistListAddButton;

  /// No description provided for @setlistListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No setlists yet'**
  String get setlistListEmptyTitle;

  /// No description provided for @setlistListEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a setlist or ask a bandmate to add one.'**
  String get setlistListEmptyDescription;

  /// No description provided for @trackListAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add track'**
  String get trackListAddButton;

  /// No description provided for @trackListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tracks yet'**
  String get trackListEmptyTitle;

  /// No description provided for @trackListEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create a track or ask a bandmate to add one.'**
  String get trackListEmptyDescription;

  /// No description provided for @trackDetailFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get trackDetailFallbackTitle;

  /// No description provided for @trackDetailEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit track'**
  String get trackDetailEditTooltip;

  /// No description provided for @trackDetailMetronomeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Practice with metronome'**
  String get trackDetailMetronomeTooltip;

  /// No description provided for @trackDetailTempoLine.
  ///
  /// In en, this message translates to:
  /// **'Tempo: {tempo} BPM'**
  String trackDetailTempoLine(int tempo);

  /// No description provided for @confirmDeleteTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {trackTitle}?'**
  String confirmDeleteTrackTitle(String trackTitle);

  /// No description provided for @createTrackAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Add track'**
  String get createTrackAppBarTitle;

  /// No description provided for @createTrackSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save track'**
  String get createTrackSaveButton;

  /// No description provided for @createTrackAddedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'{title} added!'**
  String createTrackAddedSnackbar(String title);

  /// No description provided for @editTrackAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit track'**
  String get editTrackAppBarTitle;

  /// No description provided for @tracksTabEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tracks'**
  String get tracksTabEmptyTitle;

  /// No description provided for @tracksTabEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create tracks in a band to see them here.'**
  String get tracksTabEmptyDescription;

  /// No description provided for @tracksTabViewBandsButton.
  ///
  /// In en, this message translates to:
  /// **'View bands'**
  String get tracksTabViewBandsButton;

  /// No description provided for @homeToolsHeader.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get homeToolsHeader;

  /// No description provided for @homeMetronomeButton.
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get homeMetronomeButton;

  /// No description provided for @metronomeAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get metronomeAppBarTitle;

  /// No description provided for @metronomeBpmUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get metronomeBpmUnitLabel;

  /// No description provided for @metronomeLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Initializing metronome...'**
  String get metronomeLoadingMessage;

  /// No description provided for @metronomeErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load metronome. Try again.'**
  String get metronomeErrorMessage;

  /// No description provided for @metronomeMinus5Tooltip.
  ///
  /// In en, this message translates to:
  /// **'–5 BPM'**
  String get metronomeMinus5Tooltip;

  /// No description provided for @metronomeMinus1Tooltip.
  ///
  /// In en, this message translates to:
  /// **'–1 BPM'**
  String get metronomeMinus1Tooltip;

  /// No description provided for @metronomePlus1Tooltip.
  ///
  /// In en, this message translates to:
  /// **'+1 BPM'**
  String get metronomePlus1Tooltip;

  /// No description provided for @metronomePlus5Tooltip.
  ///
  /// In en, this message translates to:
  /// **'+5 BPM'**
  String get metronomePlus5Tooltip;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
