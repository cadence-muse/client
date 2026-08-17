import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bands_provider.dart';
import '../../providers/setlists_provider.dart';
import 'setlist_detail_screen.dart';
import 'setlist_formatting.dart';

/// The global, cross-band Setlists tab (SETL-10): a flat list of every
/// setlist across every band the user belongs to, with a band-name badge per
/// row and a filter dropdown to narrow to one band. Direct mirror of
/// `tracks_screen.dart`'s `TracksScreen` shape, see `04-UI-SPEC.md` "Global
/// Setlists Tab (SetlistsScreen)".
class SetlistsScreen extends ConsumerWidget {
  const SetlistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bands = ref.watch(bandsListDataProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Setlists')),
      // Per the Copywriting Contract's "Empty state button | Not shown", the
      // zero-bands case skips the filter dropdown entirely and shows the
      // empty state directly — no "View bands" affordance like Track's.
      body: bands.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                _buildFilterDropdown(context, ref, bands),
                Expanded(child: _buildSetlistsBody(context, ref)),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButton<String?>(
        isExpanded: true,
        value: selectedBandId,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('All bands'),
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

  Widget _buildSetlistsBody(BuildContext context, WidgetRef ref) {
    final setlistsAsync = ref.watch(userSetlistsListDataProvider);

    return setlistsAsync.when(
      data: (setlists) => _buildContent(context, setlists),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _buildError(
        context,
        () => ref.invalidate(userSetlistsListDataProvider),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> setlists,
  ) {
    if (setlists.isEmpty) {
      return _buildEmptyState(context);
    }

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
          trailing: Text(tracksAndDuration(tracksCount, durationSeconds)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No setlists',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create setlists in a band to see them here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Failed to load setlists. Tap to try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
