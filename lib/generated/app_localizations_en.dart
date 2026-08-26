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

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '$count track',
    );
    return '$_temp0';
  }

  @override
  String slotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slots',
      one: '$count slot',
    );
    return '$_temp0';
  }

  @override
  String get navHome => 'Home';

  @override
  String get navBands => 'Bands';

  @override
  String get navTracks => 'Tracks';

  @override
  String get navSetlists => 'Setlists';

  @override
  String get navProfile => 'Profile';

  @override
  String get offlineNoCacheTitle => 'No cached data';

  @override
  String get offlineNoCacheDescription =>
      'Connect to the internet to load this';

  @override
  String get offlineBannerMessage => 'Showing cached data — may be out of date';

  @override
  String get loginAppTitle => 'Cadence';

  @override
  String get loginUsernameLabel => 'Username';

  @override
  String get loginUsernameValidator => 'Enter a username';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginSignUpButton => 'Sign up';

  @override
  String get loginLogInButton => 'Log in';

  @override
  String get loginToggleToLogin => 'Already have an account? Log in';

  @override
  String get loginToggleToSignUp => 'Don\'t have an account? Sign up';

  @override
  String get loginUsernameTakenError => 'This username is already taken';

  @override
  String get loginInvalidCredentialsError => 'Invalid credentials';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSomethingWentWrong =>
      'Something went wrong. Please try again.';

  @override
  String get commonCouldntLoadTracks => 'Couldn\'t load tracks';

  @override
  String get commonFailedToLoadSetlists =>
      'Failed to load setlists. Tap to try again.';

  @override
  String get commonActionCannotBeUndone => 'This action cannot be undone.';

  @override
  String get commonAddTracks => 'Add tracks';

  @override
  String get commonAtLeast8Chars => 'At least 8 characters';

  @override
  String get commonFieldRequired => 'This field is required';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonEnterBandName => 'Enter a band name';

  @override
  String get commonNameRequired => 'Name is required';

  @override
  String get commonEnterTrackTitle => 'Enter a track title';

  @override
  String get commonEnterArtistName => 'Enter an artist name';

  @override
  String get commonEnterWholeNumber => 'Enter a whole number';

  @override
  String get commonDurationFormatHint =>
      'Enter duration in mm:ss format (e.g. 0:30)';

  @override
  String get commonDurationNegative => 'Duration cannot be negative';

  @override
  String get commonDurationSecondsRange =>
      'Seconds must be 0–59 (e.g. 2:30, not 2:75)';

  @override
  String get commonDurationHelperText => 'e.g. 2:30 for 2 minutes 30 seconds';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRotate => 'Rotate';

  @override
  String get commonLeave => 'Leave';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonSave => 'Save';

  @override
  String get commonBandNameLabel => 'Band name';

  @override
  String get commonNameLabel => 'Name';

  @override
  String get commonLocationLabel => 'Location';

  @override
  String get commonDateLabel => 'Date';

  @override
  String get commonTitleLabel => 'Title';

  @override
  String get commonArtistLabel => 'Artist';

  @override
  String get commonDurationLabel => 'Duration';

  @override
  String get commonTempoLabel => 'Tempo (BPM)';

  @override
  String get commonKeyLabel => 'Key';

  @override
  String get commonNotesLabel => 'Notes';

  @override
  String get commonAllBandsFilter => 'All bands';

  @override
  String get bandDetailFallbackTitle => 'Band';

  @override
  String get bandDetailMembersHeader => 'Members';

  @override
  String get bandDetailNoMembers => 'No members';

  @override
  String get bandDetailMakeOwnerAction => 'Make owner';

  @override
  String get bandDetailInviteCodeHeader => 'Invite code';

  @override
  String get bandDetailErrorTitle => 'Couldn\'t load band details';

  @override
  String get bandDetailCopiedSnackbar => 'Copied!';

  @override
  String get bandDetailCopyTooltip => 'Copy';

  @override
  String confirmDeleteBandTitle(String bandName) {
    return 'Delete $bandName?';
  }

  @override
  String get confirmDeleteBandBody =>
      'Type the band name to confirm. This action cannot be undone and will remove the band for all members.';

  @override
  String confirmLeaveBandTitle(String bandName) {
    return 'Leave $bandName?';
  }

  @override
  String get confirmLeaveBandBody =>
      'You will no longer be a member of this band.';

  @override
  String confirmRemoveMemberTitle(String memberUsername, String bandName) {
    return 'Remove $memberUsername from $bandName?';
  }

  @override
  String confirmRemoveMemberBody(String memberUsername) {
    return '$memberUsername will no longer be a member of this band.';
  }

  @override
  String get confirmRotateInviteCodeTitle => 'Rotate invite code?';

  @override
  String get confirmRotateInviteCodeBody =>
      'The current invite code will stop working immediately. Any member who hasn\'t joined yet will need the new code.';

  @override
  String get confirmRotateInviteCodeSnackbar => 'Invite code rotated';

  @override
  String confirmTransferOwnershipTitle(String memberUsername) {
    return 'Transfer ownership to $memberUsername?';
  }

  @override
  String confirmTransferOwnershipBody(String memberUsername, String bandName) {
    return '$memberUsername will become the owner of this band.\n\nYou will no longer be the owner of $bandName.';
  }

  @override
  String get confirmTransferOwnershipButton => 'Transfer';

  @override
  String get confirmTransferOwnershipSnackbar => 'Ownership transferred';

  @override
  String get createBandAppBarTitle => 'Create a new band';

  @override
  String createBandSuccessSnackbar(String name) {
    return '$name created!';
  }

  @override
  String get editBandAppBarTitle => 'Edit band';

  @override
  String get joinBandTitle => 'Join a band';

  @override
  String get joinBandCodeLabel => 'Invite code';

  @override
  String get joinBandCodeHint => 'Paste the code here';

  @override
  String get joinBandCodeValidator => 'Enter an invite code';

  @override
  String get joinBandButton => 'Join';

  @override
  String get joinBandAmbiguousSnackbar => 'Joined band!';

  @override
  String joinBandSuccessSnackbar(String bandName) {
    return 'You\'ve joined $bandName!';
  }

  @override
  String get homeAppBarTitle => 'Home';

  @override
  String homeWelcomeMessage(String username) {
    return 'Welcome, $username';
  }

  @override
  String get homeQuickActionsHeader => 'Quick Actions';

  @override
  String get homeAddBandButton => 'Add Band';

  @override
  String get homeAddSongButton => 'Add Song';

  @override
  String get homeAddSetlistButton => 'Add Setlist';

  @override
  String get homeErrorTitle => 'Couldn\'t load home';

  @override
  String get bandPickerErrorMessage =>
      'Could not load bands. Please try again.';

  @override
  String get profileAppBarTitle => 'Profile';

  @override
  String get profileIdLabel => 'ID';

  @override
  String get profileSettingsLabel => 'Settings';

  @override
  String get profileChangePasswordLabel => 'Change password';

  @override
  String get profileLogOutLabel => 'Log out';

  @override
  String get profileErrorTitle => 'Couldn\'t load profile';

  @override
  String get changePasswordAppBarTitle => 'Change password';

  @override
  String get changePasswordSuccessSnackbar => 'Password changed successfully';

  @override
  String get changePasswordIncorrectCurrentError =>
      'Current password is incorrect';

  @override
  String get changePasswordCurrentLabel => 'Current password';

  @override
  String get changePasswordNewLabel => 'New password';

  @override
  String get changePasswordConfirmLabel => 'Confirm new password';

  @override
  String get changePasswordMismatchError => 'Passwords don\'t match';

  @override
  String get changePasswordSubmitButton => 'Change password';

  @override
  String get setlistDetailFallbackTitle => 'Setlist';

  @override
  String get setlistDetailEditTooltip => 'Edit setlist';

  @override
  String get setlistDetailDoneButton => 'Done';

  @override
  String setlistDetailTracksHeader(int count) {
    return 'Tracks ($count)';
  }

  @override
  String get setlistDetailNoTracks => 'No tracks in this setlist';

  @override
  String get setlistDetailRemoveTrackTooltip => 'Remove';

  @override
  String get setlistDetailRemoveTrackFailedSnackbar =>
      'Failed to remove track. Try again.';

  @override
  String get setlistDetailReorderFailedSnackbar =>
      'Failed to reorder tracks. Refreshing...';

  @override
  String setlistDetailReorderTooManyTracks(String tracksPhrase) {
    return 'Can\'t reorder — this setlist has more than $tracksPhrase.';
  }

  @override
  String setlistTracksLimit(String tracksPhrase) {
    return 'Setlists can have at most $tracksPhrase.';
  }

  @override
  String get setlistsTabEmptyTitle => 'No setlists';

  @override
  String get setlistsTabEmptyDescription =>
      'Create setlists in a band to see them here.';

  @override
  String get createSetlistAppBarTitle => 'Create setlist';

  @override
  String get createSetlistDateHint => 'YYYY-MM-DD';

  @override
  String get createSetlistAddTracksOptionalHeader => 'Add tracks (optional)';

  @override
  String get createSetlistNoTracksInBand => 'No tracks in this band yet';

  @override
  String get createSetlistFailedError => 'Failed to create setlist. Try again.';

  @override
  String createSetlistSuccessSnackbar(String name) {
    return '$name created!';
  }

  @override
  String get addSetlistTracksSearchHint => 'Search by title or artist';

  @override
  String addSetlistTracksMaxReached(String tracksPhrase) {
    return 'This setlist already has the maximum of $tracksPhrase.';
  }

  @override
  String get addSetlistTracksNoMatch => 'No tracks match your search';

  @override
  String get addSetlistTracksNoneAvailable => 'No more tracks available';

  @override
  String addSetlistTracksRemainingMessage(
    String tracksPhrase,
    String slotsPhrase,
  ) {
    return 'Setlists can have at most $tracksPhrase — $slotsPhrase remaining.';
  }

  @override
  String get addSetlistTracksSubmitButton => 'Add';

  @override
  String get addSetlistTracksSuccessSnackbar => 'Tracks added!';

  @override
  String get addSetlistTracksFailedError => 'Failed to add tracks. Try again.';

  @override
  String get editSetlistAppBarTitle => 'Edit setlist';

  @override
  String get editSetlistFailedError => 'Failed to save setlist. Try again.';

  @override
  String get confirmDeleteSetlistTitle => 'Delete setlist?';

  @override
  String get confirmDeleteSetlistFailedError => 'Delete failed. Try again.';

  @override
  String get setlistListAddButton => 'Add setlist';

  @override
  String get setlistListEmptyTitle => 'No setlists yet';

  @override
  String get setlistListEmptyDescription =>
      'Create a setlist or ask a bandmate to add one.';

  @override
  String get trackListAddButton => 'Add track';

  @override
  String get trackListEmptyTitle => 'No tracks yet';

  @override
  String get trackListEmptyDescription =>
      'Create a track or ask a bandmate to add one.';

  @override
  String get trackDetailFallbackTitle => 'Track';

  @override
  String get trackDetailEditTooltip => 'Edit track';

  @override
  String trackDetailTempoLine(int tempo) {
    return 'Tempo: $tempo BPM';
  }

  @override
  String confirmDeleteTrackTitle(String trackTitle) {
    return 'Delete $trackTitle?';
  }

  @override
  String get createTrackAppBarTitle => 'Add track';

  @override
  String get createTrackSaveButton => 'Save track';

  @override
  String createTrackAddedSnackbar(String title) {
    return '$title added!';
  }

  @override
  String get editTrackAppBarTitle => 'Edit track';

  @override
  String get tracksTabEmptyTitle => 'No tracks';

  @override
  String get tracksTabEmptyDescription =>
      'Create tracks in a band to see them here.';

  @override
  String get tracksTabViewBandsButton => 'View bands';
}
