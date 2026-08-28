import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../generated/app_localizations.dart';
import '../../providers/auth_provider.dart';

enum _AuthMode { login, signUp }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final sessionExpired = ref
        .read(authSessionProvider.notifier)
        .consumeSessionExpired();
    if (sessionExpired) {
      // A post-frame callback is required because initState() runs before
      // this widget's own Scaffold (built by build()) and its
      // MaterialApp-provided ScaffoldMessenger ancestor are attached to the
      // tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.loginSessionExpiredSnackbar)),
        );
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      final publicApi = ref.read(publicApiProvider);
      if (_mode == _AuthMode.signUp) {
        try {
          await publicApi.register(username: username, password: password);
        } on ApiException catch (e) {
          throw ApiException(
            statusCode: e.statusCode,
            code: e.code,
            message: e.localizedMessage(
              l10n,
              overrides: {'already_exists': l10n.loginUsernameTakenError},
            ),
          );
        }
      }
      try {
        final token = await publicApi.login(
          username: username,
          password: password,
        );
        await ref.read(authSessionProvider.notifier).signIn(token);
      } on ApiException catch (e) {
        throw ApiException(
          statusCode: e.statusCode,
          code: e.code,
          message: e.localizedMessage(
            l10n,
            overrides: {'invalid_input': l10n.loginInvalidCredentialsError},
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == _AuthMode.login ? _AuthMode.signUp : _AuthMode.login;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 128,
                    width: 128,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.loginAppTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.loginUsernameLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? l10n.loginUsernameValidator
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.loginPasswordLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (isSignUp && (value == null || value.length < 8)) {
                        return l10n.commonAtLeast8Chars;
                      }
                      if (value == null || value.isEmpty) {
                        return l10n.commonFieldRequired;
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isSignUp
                                ? l10n.loginSignUpButton
                                : l10n.loginLogInButton,
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSubmitting ? null : _toggleMode,
                    child: Text(
                      isSignUp
                          ? l10n.loginToggleToLogin
                          : l10n.loginToggleToSignUp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
