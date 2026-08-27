import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/tracks_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import '../setlists/add_setlist_tracks_dialog.dart' show trackMatchesSearchQuery;
import '../tracks/track_detail_screen.dart';
import '../tracks/track_formatting.dart';

/// The global, cross-band Tracks tab (TRACK-06): a flat list of every track
/// across every band the user belongs to, with a band-name badge per row and
/// a filter dropdown to narrow to one band. See `03-UI-SPEC.md`
/// "GlobalTracksScreen".
class TracksScreen extends ConsumerStatefulWidget {
  const TracksScreen({super.key});

  @override
  ConsumerState<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends ConsumerState<TracksScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  List<Map<String, dynamic>>? _serverSearchResults;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Drives the offline substring filter immediately (zero-delay, pure local
  // computation), and — only while online — arms a 300ms-debounced network
  // request sent directly via publicApiProvider (bypassing
  // userTracksListDataProvider/cacheServiceProvider entirely, mirroring
  // AddSetlistTracksDialog's D-02/D-03/D-04 pattern), so the shared on-disk
  // cache is never keyed by search variants. Unlike that dialog, the
  // response here IS displayed: on success it replaces the shown list; on
  // failure the previously-displayed list is left unchanged (no new error
  // UI).
  //
  // Accepted simplification: `_serverSearchResults` is not proactively
  // cleared when the band filter dropdown changes mid-search — it
  // self-corrects on the next debounced fetch.
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _debounceTimer?.cancel();
    if (!ref.read(isOnlineProvider)) return;
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        final results = await ref
            .read(publicApiProvider)
            .listUserTracks(
              bandIdFilter: ref.read(selectedBandIdFilterProvider),
              searchQuery: _searchQuery,
            );
        if (!mounted) return;
        setState(() => _serverSearchResults = results);
      } catch (_) {
        // Leave _serverSearchResults as-is — no new error UI, per the
        // behavior spec.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // D-01: this tab screen is kept alive by RootScaffold's IndexedStack, so
    // build() only runs once per app session by default — re-selecting the
    // Tracks tab (index 2) must explicitly invalidate the provider to fetch
    // fresh data. Registered before the bands.isEmpty early return below so
    // a tab-switch always re-triggers a fetch attempt regardless of that
    // state.
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == 2) ref.invalidate(userTracksListDataProvider);
    });

    final bands = ref.watch(bandsListDataProvider).valueOrNull ?? const [];
    final userTracksAsync = ref.watch(userTracksListDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navTracks),
        // D-08: a subtle in-flight indicator while a refetch is running
        // with data already present, instead of blanking the screen; D-09's
        // cold-start spinner is the `loading:` branch below, unaffected.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: userTracksAsync.isLoading && userTracksAsync.hasValue
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
      ),
      body: bands.isEmpty
          ? _buildEmptyState(context, ref, showViewBandsButton: true)
          : Column(
              children: [
                _buildFilterDropdown(context, ref, bands),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.addSetlistTracksSearchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildTracksBody(context, ref, userTracksAsync),
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
    final l10n = AppLocalizations.of(context)!;
    final selectedBandId = ref.watch(selectedBandIdFilterProvider);
    // CR-02: `selectedBandIdFilterProvider` is never cleared when the
    // filtered band disappears from `bands` (left/deleted/ownership
    // changed elsewhere). Fall back to `null` ("All bands") whenever the
    // persisted filter no longer matches an available band, so
    // `DropdownButton`'s "exactly one item with this value" assertion
    // never fires.
    final availableBandIds = {for (final band in bands) band['id'] as String};
    final effectiveBandId = availableBandIds.contains(selectedBandId)
        ? selectedBandId
        : null;
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
        onChanged: (value) =>
            ref.read(selectedBandIdFilterProvider.notifier).setFilter(value),
      ),
    );
  }

  Widget _buildTracksBody(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> tracksAsync,
  ) {
    final isOnline = ref.watch(isOnlineProvider);
    return tracksAsync.when(
      data: (tracks) {
        final List<Map<String, dynamic>> displayed;
        if (isOnline && _serverSearchResults != null) {
          displayed = _serverSearchResults!;
        } else if (!isOnline && _searchQuery.isNotEmpty) {
          displayed = [
            for (final track in tracks)
              if (trackMatchesSearchQuery(track, _searchQuery)) track,
          ];
        } else {
          displayed = tracks;
        }
        return _buildContent(context, ref, displayed);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        if (error is OfflineNoCacheException) {
          return const OfflineNoCacheView();
        }
        return _buildError(
          context,
          () => ref.invalidate(userTracksListDataProvider),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> tracks,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (tracks.isEmpty && _searchQuery.isNotEmpty) {
      return Center(child: Text(l10n.commonNoSearchResults));
    }
    if (tracks.isEmpty) {
      return _buildEmptyState(context, ref, showViewBandsButton: false);
    }

    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final title = track['title'] as String;
        final artist = track['artist'] as String;
        final bandName = track['bandName'] as String;
        final durationSeconds = track['durationSeconds'] as int?;
        return ListTile(
          leading: Chip(
            label: Text(bandName, overflow: TextOverflow.ellipsis),
            visualDensity: VisualDensity.compact,
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(durationSeconds?.asMinutesSeconds ?? '—'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TrackDetailScreen(
                bandId: track['bandId'] as String,
                trackId: track['id'] as String,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref, {
    required bool showViewBandsButton,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tracksTabEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.tracksTabEmptyDescription, textAlign: TextAlign.center),
            if (showViewBandsButton) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                // WR-01: switch to the Bands tab (index 1 per
                // root_scaffold.dart's destination order, D-21's
                // Home/Bands/Tracks/Setlists/Profile reorder) instead of
                // being a no-op.
                onPressed: () =>
                    ref.read(selectedTabIndexProvider.notifier).setIndex(1),
                child: Text(l10n.tracksTabViewBandsButton),
              ),
            ],
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
              l10n.commonCouldntLoadTracks,
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
