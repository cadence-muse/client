// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$selectedTabIndexHash() => r'5161d7640348ed0510aae275b530b94a37870932';

/// The bottom-nav tab index currently selected in [RootScaffold]
/// (0=Home, 1=Bands, 2=Tracks, 3=Setlists, 4=Profile — matching
/// [RootScaffold]'s `NavigationDestination` order, D-21).
///
/// Lifting this into a provider (rather than [RootScaffold]'s own local
/// `setState`) lets other screens switch tabs without a direct reference to
/// `RootScaffold`'s state — e.g. `TracksScreen`'s "View bands" empty-state
/// CTA (WR-01) can call [setIndex] to jump to the Bands tab. Mirrors
/// [ThemeController]'s exact shape (default value + one public setter, no
/// other state).
///
/// Copied from [SelectedTabIndex].
@ProviderFor(SelectedTabIndex)
final selectedTabIndexProvider =
    AutoDisposeNotifierProvider<SelectedTabIndex, int>.internal(
      SelectedTabIndex.new,
      name: r'selectedTabIndexProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedTabIndexHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedTabIndex = AutoDisposeNotifier<int>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
