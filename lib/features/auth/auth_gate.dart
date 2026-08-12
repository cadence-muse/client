import 'package:flutter/material.dart';

import '../../api/auth_session.dart';
import '../../api/public_api.dart';
import 'login_screen.dart';

/// Shows [LoginScreen] until [authSession] is authenticated, then shows
/// [builder]'s content. Also handles the initial "is there already a saved
/// token" check, and reacts to the session being cleared later (e.g. a 403
/// from [ApiClient]) by falling back to the login screen automatically.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authSession,
    required this.publicApi,
    required this.builder,
  });

  final AuthSession authSession;
  final PublicApi publicApi;
  final WidgetBuilder builder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    widget.authSession.restore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authSession,
      builder: (context, _) {
        switch (widget.authSession.status) {
          case AuthStatus.unknown:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.unauthenticated:
            return LoginScreen(publicApi: widget.publicApi);
          case AuthStatus.authenticated:
            return widget.builder(context);
        }
      },
    );
  }
}
