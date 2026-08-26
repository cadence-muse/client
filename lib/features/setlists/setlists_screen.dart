import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cadence/features/tracks/track_formatting.dart';

import '../../generated/app_localizations.dart';
import '../../providers/bands_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/setlists_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import 'setlist_detail_screen.dart';

/// The global, cross-band Setlists tab (SETL-10): a flat list of every
/// setlist across every band the user belongs to, with a band-name badge per
/// row and a filter dropdown to narrow to one band. Direct mirror of
/// `tracks_screen.dart`'s `TracksScreen` shape, see `04-UI-SPEC.md` "Global
/// Setlists Tab (SetlistsScreen)".
class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-01: this tab screen is kept alive by RootScaffold's IndexedStack, so
    // build() only runs once per app session by default — re-selecting the
    // Setlists tab must explicitly invalidate the provider to fetch fresh
    // data rather than silently showing whatever was last in state.
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == 3) ref.invalidate(userSetlistsListDataProvider);
    });

    final bands = ref.watch(bandsListDataProvider).valueOrNull ?? const [];
    final setlistsAsync = ref.watch(userSetlistsListDataProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSetlists),
        // D-08: a subtle in-flight indicator while a refetch is running
        // with data already present, instead of blanking the screen; D-09's
        // cold-start spinner is the `loading:` branch below, unaffected.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: setlistsAsync.isLoading && setlistsAsync.hasValue
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
      ),
      // Per the Copywriting Contract's "Empty state button | Not shown", the
      // zero-bands case skips the filter dropdown entirely and shows the
      // empty state directly — no "View bands" affordance like Track's.
      body: bands.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                _buildFilterDropdown(context, ref, bands),
                Expanded(
                  child: _buildSetlistsBody(context, ref, setlistsAsync),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> bands,
  ) {
    final selectedBandId = ref.watch(selectedSetlistBandIdFilterProvider);
    // CR-02: `selectedSetlistBandIdFilterProvider` is never cleared when
    // the filtered band disappears from `bands` (left/deleted/ownership
    // changed elsewhere). Fall back to `null` ("All bands") whenever the
    // persisted filter no longer matches an available band, so
    // `DropdownButton`'s "exactly one item with this value" assertion
    // never fires.
    final availableBandIds = {
      for (final band in bands) band['id'] as String,
    };
    final effectiveBandId = availableBandIds.contains(selectedBandId)
        ? selectedBandId
        : null;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButton<String?>(
        isExpanded: true,
        value: effectiveBandId,
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(l10n.commonAllBandsFilter),
          ),
          for (final band in bands)
            DropdownMenuItem<String?>(
              value: band['id'] as String,
              child: Text(band['name'] as String),
            ),
        ],
        onChanged: (value) => ref
            .read(selectedSetlistBandIdFilterProvider.notifier)
            .setFilter(value),
      ),
    );
  }

  Widget _buildSetlistsBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> setlistsAsync,
  ) {
    return setlistsAsync.when(
      data: (setlists) => _buildContent(context, setlists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        if (error is OfflineNoCacheException) {
          return const OfflineNoCacheView();
        }
        return _buildError(
          context,
          () => ref.invalidate(userSetlistsListDataProvider),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> setlists,
  ) {
    if (setlists.isEmpty) {
      return _buildEmptyState(context);
    }

    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: setlists.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final setlist = setlists[index];
        final name = setlist['name'] as String;
        final bandName = setlist['bandName'] as String;
        final tracksCount = setlist['tracksCount'] as int;
        final durationSeconds = setlist['durationSeconds'] as int;
        return ListTile(
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            bandName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            '${l10n.trackCount(tracksCount)}, '
            '${durationSeconds.asMinutesSeconds}',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SetlistDetailScreen(
                bandId: setlist['bandId'] as String,
                setlistId: setlist['id'] as String,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.setlistsTabEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.setlistsTabEmptyDescription,
              textAlign: TextAlign.center,
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
              l10n.commonFailedToLoadSetlists,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
