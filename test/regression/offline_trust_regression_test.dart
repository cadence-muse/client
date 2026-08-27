import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OFFL-02/OFFL-03/OFFL-04/OFFL-05/OFFL-07/OFFL-08 cross-cutting regression
/// guard (05-05, rewritten 07-05).
///
/// Mirrors `test/providers/auth_provider_test.dart`'s OFFL-06 regression
/// guard's approach — a plain `dart:io` file-content scan, no widget pumping,
/// no Riverpod — but iterates explicit file lists rather than scanning all of
/// `lib/` recursively, since the property under test ("this specific file
/// contains this specific substring") is per-file, not tree-wide.
///
/// This guard exists to make the phase's aggregate claim independently
/// re-runnable and loud-failing, instead of resting on each entity plan's
/// own isolated test coverage. The first test below originally asserted
/// Phase 5's "every cached screen renders SyncStatusBadge" (OFFL-04) claim;
/// Phase 7 (07-01 through 07-04) removed `SyncStatusBadge` from all 10 call
/// sites and replaced per-screen staleness badges with the online-first
/// cache-behavior model (OFFL-07) plus a shared `OfflineNoCacheException`
/// offline-empty-state branch (OFFL-08), so that assertion is rewritten here
/// to match the phase's actual final state instead of the retired claim.
void main() {
  /// The same 10 screens Phase 5's staleness-badge guard covered — now
  /// asserted against Phase 7's OFFL-07/OFFL-08 aggregate claim: no
  /// lingering `SyncStatusBadge` reference, and every one wires the shared
  /// `OfflineNoCacheException` offline-no-cache branch (07-01 through
  /// 07-04).
  const cachedScreens = [
    'lib/features/profile/profile_screen.dart',
    'lib/features/home/home_screen.dart',
    'lib/features/bands/bands_screen.dart',
    'lib/features/bands/band_detail_screen.dart',
    'lib/features/tracks/tracks_screen.dart',
    'lib/features/tracks/track_list_screen.dart',
    'lib/features/tracks/track_detail_screen.dart',
    'lib/features/setlists/setlists_screen.dart',
    'lib/features/setlists/setlist_list_screen.dart',
    'lib/features/setlists/setlist_detail_screen.dart',
  ];

  /// Every mutation-control file that must reference `isOnlineProvider`
  /// (OFFL-03 source-blocked-at-source connectivity gating, wired per-entity
  /// in 05-02 through 05-04).
  const mutationControlsWithConnectivityGate = [
    'lib/features/bands/bands_screen.dart',
    'lib/features/bands/band_detail_screen.dart',
    'lib/features/bands/create_band_screen.dart',
    'lib/features/bands/join_band_dialog.dart',
    'lib/features/bands/edit_band_screen.dart',
    'lib/features/bands/confirm_delete_band_dialog.dart',
    'lib/features/bands/confirm_leave_band_dialog.dart',
    'lib/features/bands/confirm_remove_member_dialog.dart',
    'lib/features/tracks/track_list_screen.dart',
    'lib/features/tracks/track_detail_screen.dart',
    'lib/features/tracks/create_track_screen.dart',
    'lib/features/tracks/edit_track_screen.dart',
    'lib/features/tracks/confirm_delete_track_dialog.dart',
    'lib/features/setlists/setlist_list_screen.dart',
    'lib/features/setlists/setlist_detail_screen.dart',
    'lib/features/setlists/create_setlist_screen.dart',
    'lib/features/setlists/edit_setlist_screen.dart',
    'lib/features/setlists/confirm_delete_setlist_dialog.dart',
    'lib/features/setlists/add_setlist_tracks_dialog.dart',
  ];

  test(
    'every cached screen has removed SyncStatusBadge and wires '
    'OfflineNoCacheException (OFFL-07/OFFL-08 regression guard)',
    () {
      for (final path in cachedScreens) {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Expected screen file to exist: $path',
        );
        final contents = file.readAsStringSync();
        expect(
          contents.contains('SyncStatusBadge'),
          isFalse,
          reason:
              '$path still references SyncStatusBadge (OFFL-08 requires the '
              'badge system fully removed).',
        );
        expect(
          contents.contains('OfflineNoCacheException'),
          isTrue,
          reason:
              '$path is expected to wire the offline-no-cache error branch '
              '(OFFL-07/OFFL-08) but OfflineNoCacheException was not found.',
        );
      }
    },
  );

  test(
    'every mutation control references isOnlineProvider (OFFL-03 regression '
    'guard)',
    () {
      for (final path in mutationControlsWithConnectivityGate) {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Expected mutation-control file to exist: $path',
        );
        expect(
          file.readAsStringSync().contains('isOnlineProvider'),
          isTrue,
          reason:
              '$path is expected to gate its mutation entry point(s) on '
              'isOnlineProvider (OFFL-03) but the string was not found.',
        );
      }
    },
  );

  test(
    'RootScaffold renders the global OfflineBanner (OFFL-05 regression '
    'guard)',
    () {
      const path = 'lib/navigation/root_scaffold.dart';
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Expected file to exist: $path',
      );
      expect(
        file.readAsStringSync().contains('OfflineBanner'),
        isTrue,
        reason:
            '$path is expected to render OfflineBanner (OFFL-05 global '
            'offline banner) but the string was not found.',
      );
    },
  );
}
