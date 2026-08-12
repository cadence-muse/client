import 'package:flutter/material.dart';

import '../../api/public_api.dart';
import '../../theme/theme_controller.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.themeController, required this.publicApi});

  final ThemeController themeController;
  final PublicApi publicApi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(
            radius: 48,
            child: Icon(Icons.person, size: 48),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Username',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(themeController: themeController),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () async {
              try {
                await publicApi.logout();
              } catch (_) {
                // Local session is already cleared regardless of the
                // network result; AuthGate will fall back to the login
                // screen either way.
              }
            },
          ),
        ],
      ),
    );
  }
}
