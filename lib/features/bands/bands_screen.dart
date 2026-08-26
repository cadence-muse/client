import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/bands_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import 'band_avatar.dart';
import 'band_detail_screen.dart';
import 'create_band_screen.dart';
import 'join_band_dialog.dart';

class BandsScreen extends ConsumerWidget {
  const BandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-01: this tab screen is kept alive by RootScaffold's IndexedStack, so
    // build() only runs once per app session by default — re-selecting the
    // Bands tab must explicitly invalidate the provider to fetch fresh data
    // rather than silently showing whatever was last in state.
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == 1) ref.invalidate(bandsListDataProvider);
    });

    final l10n = AppLocalizations.of(context)!;
    final bandsAsync = ref.watch(bandsListDataProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final profileAsync = ref.watch(profileDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appBarBandsTitle),
        // D-08: a subtle in-flight indicator while a refetch is running with
        // data already present, instead of blanking the screen; D-09's
        // cold-start spinner is the `loading:` branch below, unaffected.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: bandsAsync.isLoading && bandsAsync.hasValue
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
      ),
      body: bandsAsync.when(
        data: (bands) => _buildContent(context, bands, profileAsync),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(bandsListDataProvider),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isOnline ? () => _showCreateJoinMenu(context, ref) : null,
        tooltip: isOnline ? null : l10n.commonRequiresConnection,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateJoinMenu(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.bandsCreateMenuItem),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateBandScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: Text(l10n.bandsJoinMenuItem),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showJoinBandDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Map<String, dynamic>> bands,
    AsyncValue<Map<String, dynamic>> profileAsync,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (bands.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.bandsEmptyTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.bandsEmptyDescription, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateBandScreen()),
                ),
                child: Text(l10n.bandsCreateBandButton),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: bands.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final band = bands[index];
        final name = band['name'] as String;
        final ownerId = band['ownerId'] as String?;
        final membersCount = band['membersCount'] as int;
        final isOwner = ownerId == null
            ? null
            : BandDetailScreen.ownershipStatus(profileAsync, ownerId);
        return ListTile(
          leading: BandAvatar(bandName: name),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(
            isOwner == null
                ? l10n.memberCount(membersCount)
                : '${l10n.memberCount(membersCount)} • '
                      '${isOwner ? l10n.bandRoleOwner : l10n.bandRoleMember}',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BandDetailScreen(bandId: band['id'] as String),
            ),
          ),
        );
      },
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
              l10n.bandsErrorTitle,
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
