import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OFFL-02/OFFL-03/OFFL-04/OFFL-05 cross-cutting regression guard (05-05).
///
/// Mirrors `test/providers/auth_provider_test.dart`'s OFFL-06 regression
/// guard's approach — a plain `dart:io` file-content scan, no widget pumping,
/// no Riverpod — but iterates explicit file lists rather than scanning all of
/// `lib/` recursively, since the property under test ("this specific file
/// contains this specific substring") is per-file, not tree-wide.
///
/// This guard exists to make the phase's aggregate claim ("every cached
/// screen has the staleness badge, every mutation control has the
/// connectivity gate") independently re-runnable and loud-failing, instead of
/// resting on each entity plan's (05-01 through 05-04) own isolated test
/// coverage.
void main() {
  /// Every cached screen that must render `SyncStatusBadge` (05-01 D-08/D-09
  /// staleness indicator, wired per-entity in 05-01 through 05-04).
  const screensWithBadge = [
    'lib/features/profile/profile_screen.dart',
    'lib/features/home/home_screen.dart',
    'lib/features/bands/bands_screen.dart',
    'lib/features/bands/band_detail_screen.dart',
    'lib/features/songs/tracks_screen.dart',
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

  /// The 10 `readXSyncedAt()` accessor names `cache_service.dart` must expose
  /// — one per cache key pair, established in 05-01 Task 2.
  const readSyncedAtMethodNames = [
    'readProfileSyncedAt',
    'readHomepageSyncedAt',
    'readBandsSyncedAt',
    'readBandDetailSyncedAt',
    'readBandTracksSyncedAt',
    'readBandTrackDetailSyncedAt',
    'readUserTracksSyncedAt',
    'readBandSetlistsSyncedAt',
    'readSetlistDetailSyncedAt',
    'readUserSetlistsSyncedAt',
  ];

  test(
    'every cached screen renders SyncStatusBadge (OFFL-04 regression guard)',
    () {
      for (final path in screensWithBadge) {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Expected screen file to exist: $path',
        );
        expect(
          file.readAsStringSync().contains('SyncStatusBadge'),
          isTrue,
          reason:
              '$path is expected to render SyncStatusBadge (OFFL-04 '
              'staleness indicator) but the string was not found.',
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

  test(
    'cache_service.dart exposes a readXSyncedAt() accessor for all 10 cache '
    'keys (OFFL-04 regression guard)',
    () {
      const path = 'lib/cache/cache_service.dart';
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Expected file to exist: $path',
      );
      final contents = file.readAsStringSync();
      for (final methodName in readSyncedAtMethodNames) {
        expect(
          contents.contains(methodName),
          isTrue,
          reason:
              '$path is expected to expose a $methodName() accessor but the '
              'string was not found.',
        );
      }
    },
  );
}
