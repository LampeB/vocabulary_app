import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/v3_colors.dart';
import '../../../core/widget_keys.dart';
import '../../widgets/v3_pond.dart';

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

  Future<void> _showForgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Title and content colors come from dialogTheme automatically.
        title: Text('auth.reset_dialog_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'auth.reset_dialog_body'.tr(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey(WidgetKeys.authResetEmail),
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'auth.field_email'.tr(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            key: const ValueKey(WidgetKeys.authResetSend),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              Navigator.pop(ctx);
              final result = await ref
                  .read(authStateProvider.notifier)
                  .sendPasswordReset(email);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  result.isSuccess
                      ? 'auth.reset_snackbar_success'.tr()
                      : 'auth.reset_snackbar_error'.tr(),
                  key: ValueKey(result.isSuccess
                      ? WidgetKeys.authResetSuccess
                      : WidgetKeys.authResetError),
                ),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: Text('auth.reset_send'.tr(),
                style: AppTextStyles.fig(14, FontWeight.w600)
                    .copyWith(color: AppColors.teal)),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
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
        if (!mounted) return;
        TextInput.finishAutofillContext(shouldSave: true);
        context.go('/home');
      },
      onFailure: (e) => setState(() => _errorMsg = e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;
    final baseTheme = Theme.of(context);
    final dark = baseTheme.brightness == Brightness.dark;
    final background = dark ? V3Colors.app : V3Colors.paper;
    final foreground = dark ? V3Colors.light : V3Colors.ink;
    final muted = dark ? V3Colors.light70 : V3Colors.ink60;
    final field = dark ? V3Colors.block : V3Colors.paper3;
    final fieldRule = dark ? V3Colors.ruleDark : V3Colors.edgeWarm2;
    final accent = dark ? V3Colors.amber : V3Colors.terra;
    final fieldTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.copyWith(
        bodyLarge: AppTextStyles.fig(16, FontWeight.w500, color: foreground),
        bodyMedium: AppTextStyles.fig(15, FontWeight.w400, color: foreground),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        labelStyle: AppTextStyles.fig(14, FontWeight.w400, color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: fieldRule)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: fieldRule)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: V3Colors.amber, width: 1.5)),
      ),
    );

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(child: V3Pond(animate: false)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Theme(
                data: fieldTheme,
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Material(
                            color: V3Colors.chip,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () => context.go('/welcome'),
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Icon(Icons.arrow_back_rounded,
                                      size: 18, color: foreground)),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Text(_isSignIn ? 'CONNEXION' : 'CRÉER UN COMPTE',
                              style: AppTextStyles.mono(12, FontWeight.w400,
                                  letterSpacing: 1.1, color: muted)),
                        ]),
                        const SizedBox(height: 34),
                        Text(
                          _isSignIn
                              ? 'auth.title_signin'.tr()
                              : 'auth.title_signup'.tr(),
                          style: AppTextStyles.serif(34, FontWeight.w400,
                              color: foreground),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignIn
                              ? 'auth.subtitle_signin'.tr()
                              : 'auth.subtitle_signup'.tr(),
                          style: AppTextStyles.fig(14, FontWeight.w400)
                              .copyWith(color: muted),
                        ),
                        const SizedBox(height: 32),
                        // ── Username (sign-up only) ──────────────────────────────
                        if (!_isSignIn) ...[
                          TextFormField(
                            key: const Key('username_field'),
                            controller: _usernameCtrl,
                            decoration: InputDecoration(
                              labelText: 'auth.field_username'.tr(),
                              prefixIcon: const Icon(Icons.alternate_email),
                            ),
                            autofillHints: const [AutofillHints.username],
                            validator: (v) => (v?.length ?? 0) < 3
                                ? 'auth.validator_username_short'.tr()
                                : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                        ],
                        // ── Email ────────────────────────────────────────────────
                        TextFormField(
                          key: const Key('email_field'),
                          controller: _emailCtrl,
                          decoration: InputDecoration(
                            labelText: 'auth.field_email'.tr(),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          validator: (v) => (v?.contains('@') ?? false)
                              ? null
                              : 'auth.validator_email_invalid'.tr(),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        // ── Password ─────────────────────────────────────────────
                        TextFormField(
                          key: const Key('password_field'),
                          controller: _passwordCtrl,
                          decoration: InputDecoration(
                            labelText: 'auth.field_password'.tr(),
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
                          autofillHints: _isSignIn
                              ? const [AutofillHints.password]
                              : const [AutofillHints.newPassword],
                          validator: (v) => (v?.length ?? 0) >= 6
                              ? null
                              : 'auth.validator_password_short'.tr(),
                        ),
                        // ── Forgot password (sign-in only) ───────────────────────
                        if (_isSignIn) ...[
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key:
                                  const ValueKey(WidgetKeys.authForgotPassword),
                              onPressed: () => _showForgotPassword(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'auth.forgot_password'.tr(),
                                style: AppTextStyles.fig(13, FontWeight.w500)
                                    .copyWith(color: accent),
                              ),
                            ),
                          ),
                        ],
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
                                  ? V3Colors.terra.withValues(alpha: 0.55)
                                  : V3Colors.terra,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _isSignIn
                                          ? 'auth.button_signin'.tr()
                                          : 'auth.button_signup'.tr(),
                                      style:
                                          AppTextStyles.fig(15, FontWeight.w700)
                                              .copyWith(color: V3Colors.paper),
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
                                  ? 'auth.toggle_to_signup'.tr()
                                  : 'auth.toggle_to_signin'.tr(),
                              style: AppTextStyles.fig(13, FontWeight.w500)
                                  .copyWith(color: accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
