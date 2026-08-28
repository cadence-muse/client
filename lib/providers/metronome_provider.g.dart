// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metronome_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$metronomeStateHash() => r'99f8027711726f636ebb8f243ea53a5af8c37158';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$MetronomeState
    extends BuildlessAutoDisposeNotifier<MetronomeData> {
  late final int initialBpm;

  MetronomeData build(int initialBpm);
}

/// Metronome beat-scheduling state, keyed as a Riverpod family by
/// [initialBpm] -- the Homepage's default 120 and a track's own tempo each
/// get an independent instance (PROHIBIT-STATE-BLEED notwithstanding, see
/// 18-01-PLAN.md's threat register).
///
/// D-08: always opens paused regardless of [initialBpm]. D-04/Pitfall 3:
/// `state.bpm` is read fresh on every tick check (never cached), so a
/// `setBpm()` call between two ticks changes what the very next check reads
/// -- tempo changes take effect immediately on the next tick, not the next
/// bar.
///
/// Copied from [MetronomeState].
@ProviderFor(MetronomeState)
const metronomeStateProvider = MetronomeStateFamily();

/// Metronome beat-scheduling state, keyed as a Riverpod family by
/// [initialBpm] -- the Homepage's default 120 and a track's own tempo each
/// get an independent instance (PROHIBIT-STATE-BLEED notwithstanding, see
/// 18-01-PLAN.md's threat register).
///
/// D-08: always opens paused regardless of [initialBpm]. D-04/Pitfall 3:
/// `state.bpm` is read fresh on every tick check (never cached), so a
/// `setBpm()` call between two ticks changes what the very next check reads
/// -- tempo changes take effect immediately on the next tick, not the next
/// bar.
///
/// Copied from [MetronomeState].
class MetronomeStateFamily extends Family<MetronomeData> {
  /// Metronome beat-scheduling state, keyed as a Riverpod family by
  /// [initialBpm] -- the Homepage's default 120 and a track's own tempo each
  /// get an independent instance (PROHIBIT-STATE-BLEED notwithstanding, see
  /// 18-01-PLAN.md's threat register).
  ///
  /// D-08: always opens paused regardless of [initialBpm]. D-04/Pitfall 3:
  /// `state.bpm` is read fresh on every tick check (never cached), so a
  /// `setBpm()` call between two ticks changes what the very next check reads
  /// -- tempo changes take effect immediately on the next tick, not the next
  /// bar.
  ///
  /// Copied from [MetronomeState].
  const MetronomeStateFamily();

  /// Metronome beat-scheduling state, keyed as a Riverpod family by
  /// [initialBpm] -- the Homepage's default 120 and a track's own tempo each
  /// get an independent instance (PROHIBIT-STATE-BLEED notwithstanding, see
  /// 18-01-PLAN.md's threat register).
  ///
  /// D-08: always opens paused regardless of [initialBpm]. D-04/Pitfall 3:
  /// `state.bpm` is read fresh on every tick check (never cached), so a
  /// `setBpm()` call between two ticks changes what the very next check reads
  /// -- tempo changes take effect immediately on the next tick, not the next
  /// bar.
  ///
  /// Copied from [MetronomeState].
  MetronomeStateProvider call(int initialBpm) {
    return MetronomeStateProvider(initialBpm);
  }

  @override
  MetronomeStateProvider getProviderOverride(
    covariant MetronomeStateProvider provider,
  ) {
    return call(provider.initialBpm);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'metronomeStateProvider';
}

/// Metronome beat-scheduling state, keyed as a Riverpod family by
/// [initialBpm] -- the Homepage's default 120 and a track's own tempo each
/// get an independent instance (PROHIBIT-STATE-BLEED notwithstanding, see
/// 18-01-PLAN.md's threat register).
///
/// D-08: always opens paused regardless of [initialBpm]. D-04/Pitfall 3:
/// `state.bpm` is read fresh on every tick check (never cached), so a
/// `setBpm()` call between two ticks changes what the very next check reads
/// -- tempo changes take effect immediately on the next tick, not the next
/// bar.
///
/// Copied from [MetronomeState].
class MetronomeStateProvider
    extends AutoDisposeNotifierProviderImpl<MetronomeState, MetronomeData> {
  /// Metronome beat-scheduling state, keyed as a Riverpod family by
  /// [initialBpm] -- the Homepage's default 120 and a track's own tempo each
  /// get an independent instance (PROHIBIT-STATE-BLEED notwithstanding, see
  /// 18-01-PLAN.md's threat register).
  ///
  /// D-08: always opens paused regardless of [initialBpm]. D-04/Pitfall 3:
  /// `state.bpm` is read fresh on every tick check (never cached), so a
  /// `setBpm()` call between two ticks changes what the very next check reads
  /// -- tempo changes take effect immediately on the next tick, not the next
  /// bar.
  ///
  /// Copied from [MetronomeState].
  MetronomeStateProvider(int initialBpm)
    : this._internal(
        () => MetronomeState()..initialBpm = initialBpm,
        from: metronomeStateProvider,
        name: r'metronomeStateProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$metronomeStateHash,
        dependencies: MetronomeStateFamily._dependencies,
        allTransitiveDependencies:
            MetronomeStateFamily._allTransitiveDependencies,
        initialBpm: initialBpm,
      );

  MetronomeStateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.initialBpm,
  }) : super.internal();

  final int initialBpm;

  @override
  MetronomeData runNotifierBuild(covariant MetronomeState notifier) {
    return notifier.build(initialBpm);
  }

  @override
  Override overrideWith(MetronomeState Function() create) {
    return ProviderOverride(
      origin: this,
      override: MetronomeStateProvider._internal(
        () => create()..initialBpm = initialBpm,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        initialBpm: initialBpm,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<MetronomeState, MetronomeData>
  createElement() {
    return _MetronomeStateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MetronomeStateProvider && other.initialBpm == initialBpm;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, initialBpm.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MetronomeStateRef on AutoDisposeNotifierProviderRef<MetronomeData> {
  /// The parameter `initialBpm` of this provider.
  int get initialBpm;
}

class _MetronomeStateProviderElement
    extends AutoDisposeNotifierProviderElement<MetronomeState, MetronomeData>
    with MetronomeStateRef {
  _MetronomeStateProviderElement(super.provider);

  @override
  int get initialBpm => (origin as MetronomeStateProvider).initialBpm;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
