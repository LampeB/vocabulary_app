import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = 'signin'});
  final String initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _isSignIn;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _isSignIn = widget.initialMode != 'signup';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _errorMsg = null);
    final notifier = ref.read(authStateProvider.notifier);
    final result = _isSignIn
        ? await notifier.signIn(_emailCtrl.text.trim(), _passwordCtrl.text)
        : await notifier.signUp(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            _usernameCtrl.text.trim(),
          );
    result.fold(
      onSuccess: (_) {
        if (mounted) context.go('/home');
      },
      onFailure: (e) => setState(() => _errorMsg = e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/welcome')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isSignIn ? 'Sign in' : 'Create account',
                  style: tt.headlineLarge,
                ),
                const SizedBox(height: 32),
                if (!_isSignIn) ...[
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (v) =>
                        (v?.length ?? 0) < 3 ? 'At least 3 characters' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('email_field'),
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v?.contains('@') ?? false) ? null : 'Enter a valid email',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('password_field'),
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) =>
                      (v?.length ?? 0) >= 6 ? null : 'At least 6 characters',
                ),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMsg!,
                      style: tt.bodyMedium
                          ?.copyWith(color: AppColors.secondary)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('auth_submit_button'),
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isSignIn ? 'Sign in' : 'Create account'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isSignIn = !_isSignIn),
                  child: Text(
                    _isSignIn
                        ? "Don't have an account? Sign up"
                        : 'Already have an account? Sign in',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
