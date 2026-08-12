import 'package:flutter/material.dart';

import '../../api/api_exception.dart';
import '../../api/public_api.dart';

enum _AuthMode { login, signUp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.publicApi});

  final PublicApi publicApi;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == _AuthMode.signUp) {
        try {
          await widget.publicApi.register(username: username, password: password);
        } on ApiException catch (e) {
          if (e.statusCode == 400 && e.code == 'already_exists') {
            throw ApiException(
              statusCode: e.statusCode,
              code: e.code,
              message: 'This username is already taken',
            );
          }
          rethrow;
        }
      }
      try {
        await widget.publicApi.login(username: username, password: password);
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          throw ApiException(
            statusCode: e.statusCode,
            code: e.code,
            message: 'Invalid credentials',
          );
        }
        rethrow;
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
                  Image.asset('assets/images/logo.png', height: 128, width: 128),
                  const SizedBox(height: 8),
                  Text(
                    'Cadence',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter a username' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.length < 8) ? 'At least 8 characters' : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                        : Text(isSignUp ? 'Sign up' : 'Log in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSubmitting ? null : _toggleMode,
                    child: Text(
                      isSignUp
                          ? 'Already have an account? Log in'
                          : "Don't have an account? Sign up",
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
