import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RadioGroup<ThemeMode>(
        groupValue: mode,
        onChanged: (mode) =>
            ref.read(themeControllerProvider.notifier).setThemeMode(mode!),
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const RadioListTile<ThemeMode>(
              title: Text('System'),
              value: ThemeMode.system,
            ),
            const RadioListTile<ThemeMode>(
              title: Text('Light'),
              value: ThemeMode.light,
            ),
            const RadioListTile<ThemeMode>(
              title: Text('Dark'),
              value: ThemeMode.dark,
            ),
          ],
        ),
      ),
    );
  }
}
