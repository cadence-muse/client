import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return locale.when(
      data: (currentLocale) => Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.appBarSettingsTitle),
        ),
        body: RadioGroup<ThemeMode>(
          groupValue: themeMode,
          onChanged: (mode) =>
              ref.read(themeControllerProvider.notifier).setThemeMode(mode!),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  AppLocalizations.of(context)!.sectionThemeTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              RadioListTile<ThemeMode>(
                title: Text(AppLocalizations.of(context)!.themeSystem),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text(AppLocalizations.of(context)!.themeLight),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text(AppLocalizations.of(context)!.themeDark),
                value: ThemeMode.dark,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  AppLocalizations.of(context)!.sectionLanguageTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              RadioGroup<Locale>(
                groupValue: currentLocale,
                onChanged: (value) => ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(value!),
                child: Column(
                  children: [
                    RadioListTile<Locale>(
                      title: const Text('English'),
                      value: const Locale('en'),
                    ),
                    RadioListTile<Locale>(
                      title: const Text('Русский'),
                      value: const Locale('ru'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}
