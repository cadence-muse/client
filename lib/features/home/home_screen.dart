import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/homepage_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/offline_no_cache_exception.dart';
import '../../widgets/offline_no_cache_view.dart';
import '../bands/bands_screen.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
        data: (data) => _buildContent(context, data),
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

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final username = data['username'] as String;
    final bandsCount = data['bandsCount'] as int;

    if (bandsCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No bands yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                "Create or join a band to get started. Tap the '+' icon to "
                'create one or ask a bandmate for an invite code.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BandsScreen()),
                ),
                child: const Text('Create Band'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome, $username',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text('Your bands', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              _formatBandsCount(bandsCount),
              style: Theme.of(context).textTheme.headlineSmall,
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
            Text(
              "Couldn't load home",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  String _formatBandsCount(int n) =>
      n == 1 ? '1 band' : '${_withThousandsSeparator(n)} bands';

  String _withThousandsSeparator(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
