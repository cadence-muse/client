import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/offline_no_cache_view.dart';
import '../settings/settings_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // D-01: this tab screen is kept alive by RootScaffold's IndexedStack, so
    // build() only runs once per app session by default — re-selecting the
    // Profile tab must explicitly invalidate the provider to fetch fresh
    // data rather than silently showing whatever was last in state.
    ref.listen<int>(selectedTabIndexProvider, (previous, current) {
      if (current == 4) ref.invalidate(profileDataProvider);
    });

    final profileAsync = ref.watch(profileDataProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileAppBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
            onPressed: () => ref.read(profileDataProvider.notifier).refresh(),
          ),
        ],
        // D-08: a subtle in-flight indicator while a refetch is running with
        // data already present, instead of blanking the screen; D-09's
        // cold-start spinner is the `loading:` branch below, unaffected.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: profileAsync.isLoading && profileAsync.hasValue
              ? const LinearProgressIndicator()
              : const SizedBox.shrink(),
        ),
      ),
      body: profileAsync.when(
        data: (profile) => _buildContent(context, ref, profile),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          if (error is OfflineNoCacheException) {
            return const OfflineNoCacheView();
          }
          return _buildError(
            context,
            () => ref.invalidate(profileDataProvider),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> profile,
  ) {
    final username = profile['username'] as String? ?? '';
    final id = profile['id'] as String? ?? '';
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      children: [
        const SizedBox(height: 24),
        const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(height: 1),
        ListTile(title: Text(l10n.profileIdLabel), subtitle: Text(id)),
        ListTile(
          leading: const Icon(Icons.settings),
          title: Text(l10n.profileSettingsLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.profileChangePasswordLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ChangePasswordScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n.profileLogOutLabel),
          onTap: () => ref.read(authSessionProvider.notifier).signOut(),
        ),
      ],
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
              l10n.profileErrorTitle,
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
