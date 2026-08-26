import 'package:flutter/material.dart';

import '../generated/app_localizations.dart';

/// D-06: shared "offline with nothing ever cached" state, rendered by a
/// screen's `error:` branch when its provider throws
/// `OfflineNoCacheException`. Copy is identical across every screen this
/// phase touches (07-UI-SPEC.md's "Secondary State" section) — no
/// constructor parameters.
///
/// Deliberately has no Retry button: retrying does nothing while offline.
/// Recovery is automatic (D-07) — the moment `isOnlineProvider` flips back
/// to online, the owning provider's `build()` re-runs (it watches
/// `isOnlineProvider`) and refetches on its own, replacing this view with
/// real content with no user action required.
class OfflineNoCacheView extends StatelessWidget {
  const OfflineNoCacheView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.offlineNoCacheTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.offlineNoCacheDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
