import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import 'login_screen.dart';

/// Shows [LoginScreen] until [authSessionProvider] resolves to a token,
/// then shows [builder]'s content. `authSessionProvider.build()` performs
/// the initial "is there already a saved token" restore automatically, and
/// reacts to the session being cleared later (e.g. a 403 from [ApiClient])
/// by falling back to the login screen automatically.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authSessionProvider);

    return authAsync.when(
      data: (token) => token == null ? const LoginScreen() : builder(context),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('Auth error: $error'))),
    );
  }
}
