import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/homepage_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../widgets/offline_no_cache_view.dart';
import '../bands/create_band_screen.dart';
import 'band_picker_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-01: this tab screen is kept alive by RootScaffold's IndexedStack, so
    // build() only runs once per app session by default — re-selecting the
    // Home tab must explicitly invalidate the provider to fetch fresh data
    // rather than silently showing whatever was last in state.
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == 0) ref.invalidate(homepageDataProvider);
    });

    final homeAsync = ref.watch(homepageDataProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeAppBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
            onPressed: () => ref.read(homepageDataProvider.notifier).refresh(),
          ),
        ],
        // D-08: a subtle in-flight indicator while a refetch is running with
        // data already present, instead of blanking the screen; D-09's
        // cold-start spinner is the `loading:` branch below, unaffected.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: homeAsync.isLoading && homeAsync.hasValue
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
      ),
      body: homeAsync.when(
        data: (data) => _buildContent(context, ref, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(homepageDataProvider),
          );
        },
      ),
    );
  }

  // Phase 9 (D-01/D-02/D-03/D-09/D-10): one unified layout for both the
  // zero-bands and populated states — a welcome card, a "Quick Actions"
  // header, and a 3-button row where "Add Track"/"Add Setlist" are disabled
  // until bandsCount > 0. Replaces the old bandsCount==0-only empty-state
  // block and the old populated-state band-count display text entirely.
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) {
    final username = data['username'] as String;
    final bandsCount = data['bandsCount'] as int;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // D-01: welcome card, room reserved in the Row for a future
            // avatar widget (not built this phase).
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l10n.homeWelcomeMessage(username),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // D-02: "Quick Actions" section header.
            Text(
              l10n.homeQuickActionsHeader,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            // D-10: all 3 buttons always render; only enabled/disabled
            // state of Add Track/Add Setlist changes with bandsCount.
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateBandScreen()),
                  ),
                  icon: const Icon(Icons.group_add),
                  label: Text(l10n.homeAddBandButton),
                ),
                ElevatedButton.icon(
                  onPressed: bandsCount > 0
                      ? () => showBandPickerSheet(context, ref, forTrack: true)
                      : null,
                  icon: const Icon(Icons.music_note),
                  label: Text(l10n.homeAddTrackButton),
                ),
                ElevatedButton.icon(
                  onPressed: bandsCount > 0
                      ? () => showBandPickerSheet(context, ref, forTrack: false)
                      : null,
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.homeAddSetlistButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.homeErrorTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.commonConnectionError, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
