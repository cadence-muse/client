import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/bands_provider.dart';
import '../setlists/create_setlist_screen.dart';
import '../tracks/create_track_screen.dart';

/// Shows the shared band-picker bottom sheet for the "Add Song" and
/// "Add Setlist" Homepage quick actions (HOME-02, D-05/D-06/D-07/D-08).
///
/// Lists every band from [bandsListDataProvider] as a `ListTile` showing the
/// band's name only (no member count/role, D-05) — no separate fetch, no new
/// provider (D-06). The picker always opens, even when the user has exactly
/// one band (D-07); dismissing without a selection (tap outside / back)
/// simply closes the sheet with no error or snackbar (D-08).
///
/// Selecting a band pops the sheet with that band's id, then — from the
/// outer [context], never the sheet's own context, mirroring
/// `join_band_dialog.dart`'s post-dialog navigation pattern — pushes
/// [CreateTrackScreen] when [forTrack] is true, otherwise
/// [CreateSetlistScreen] (D-11).
Future<void> showBandPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool forTrack,
}) async {
  final bandId = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final bandsAsync = ref.watch(bandsListDataProvider);
          final l10n = AppLocalizations.of(context)!;
          return bandsAsync.when(
            data: (bands) => ListView(
              shrinkWrap: true,
              children: [
                for (final band in bands)
                  ListTile(
                    leading: const Icon(Icons.group),
                    title: Text(
                      band['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(band['id'] as String),
                  ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            // V7: a short, generic message only — never interpolate the raw
            // exception/stack trace into the displayed text.
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.bandPickerErrorMessage),
            ),
          );
        },
      ),
    ),
  );

  if (bandId == null || !context.mounted) return;

  if (forTrack) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateTrackScreen(bandId: bandId)),
    );
  } else {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CreateSetlistScreen(bandId: bandId)),
    );
  }
}
