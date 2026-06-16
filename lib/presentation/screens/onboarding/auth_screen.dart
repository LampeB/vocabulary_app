import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = 'signin'});
  final String initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _isSignIn;
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _obscure       = true;
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
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.ink, size: 20),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: Stack(
        children: [
          const DottedGround(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isSignIn ? 'Connexion' : 'Créer un compte',
                      style: AppTextStyles.grotesk(32, FontWeight.w700)
                          .copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignIn
                          ? 'Content de te revoir !'
                          : 'C\'est gratuit, sans carte bancaire.',
                      style: AppTextStyles.fig(14, FontWeight.w400)
                          .copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 32),
                    // ── Username (sign-up only) ──────────────────────────────
                    if (!_isSignIn) ...[
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom d\'utilisateur',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (v) => (v?.length ?? 0) < 3
                            ? 'Au moins 3 caractères'
                            : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // ── Email ────────────────────────────────────────────────
                    TextFormField(
                      key: const Key('email_field'),
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v?.contains('@') ?? false)
                          ? null
                          : 'Adresse e-mail invalide',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    // ── Password ─────────────────────────────────────────────
                    TextFormField(
                      key: const Key('password_field'),
                      controller: _passwordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      validator: (v) => (v?.length ?? 0) >= 6
                          ? null
                          : 'Au moins 6 caractères',
                    ),
                    // ── Error message ─────────────────────────────────────────
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorMsg!,
                          style: AppTextStyles.fig(13, FontWeight.w500)
                              .copyWith(color: AppColors.rose)),
                    ],
                    const SizedBox(height: 28),
                    // ── Submit ────────────────────────────────────────────────
                    GestureDetector(
                      onTap: isLoading ? null : _submit,
                      child: Container(
                        key: const Key('auth_submit_button'),
                        height: 56,
                        decoration: BoxDecoration(
                          color: isLoading
                              ? AppColors.clay.withValues(alpha: 0.55)
                              : AppColors.clay,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text(
                                  _isSignIn
                                      ? 'Se connecter'
                                      : 'Créer mon compte',
                                  style: AppTextStyles.fig(
                                          15, FontWeight.w700)
                                      .copyWith(color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ── Toggle mode ───────────────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _isSignIn = !_isSignIn),
                        child: Text(
                          _isSignIn
                              ? 'Pas encore de compte ? Inscription'
                              : 'Déjà un compte ? Connexion',
                          style: AppTextStyles.fig(13, FontWeight.w500)
                              .copyWith(color: AppColors.teal),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
