import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';

/// The bottom-nav tab index currently selected in [RootScaffold]
/// (0=Home, 1=Tracks, 2=Bands, 3=Profile — matching [RootScaffold]'s
/// `NavigationDestination` order).
///
/// Lifting this into a provider (rather than [RootScaffold]'s own local
/// `setState`) lets other screens switch tabs without a direct reference to
/// `RootScaffold`'s state — e.g. `TracksScreen`'s "View bands" empty-state
/// CTA (WR-01) can call [setIndex] to jump to the Bands tab. Mirrors
/// [ThemeController]'s exact shape (default value + one public setter, no
/// other state).
@riverpod
class SelectedTabIndex extends _$SelectedTabIndex {
  @override
  int build() => 0;

  /// Sets the selected tab index. A public method instead of the literal
  /// `notifier.state = value` instruction — the latter fails `flutter
  /// analyze` (`invalid_use_of_protected_member`) when called from outside
  /// the notifier itself, per the same pattern established by
  /// `SelectedBandIdFilter.setFilter()` (03-03).
  void setIndex(int index) => state = index;
}
