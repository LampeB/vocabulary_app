import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../providers/auth/auth_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widget_keys.dart';
import '../../../domain/entities/vocabulary_list.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';

class ImportFromLinkScreen extends ConsumerStatefulWidget {
  const ImportFromLinkScreen({required this.token, super.key});
  final String token;

  @override
  ConsumerState<ImportFromLinkScreen> createState() =>
      _ImportFromLinkScreenState();
}

class _ImportFromLinkScreenState extends ConsumerState<ImportFromLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _import());
  }

  Future<void> _import() async {
    if (!mounted) return;
    // A restored Supabase session can precede its remote profile. Resolve the
    // local identity before constructing the account-scoped repository.
    final user = ref.read(authStateProvider.notifier).useLocalSession();
    if (user == null) {
      _finish(const Failure(AuthException('Not signed in')));
      return;
    }
    final result = await ref
        .read(listActionsProvider.notifier)
        .importFromLink(widget.token);

    _finish(result);
  }

  void _finish(Result<VocabularyList> result) {
    if (!mounted) return;
    result.fold(
      onSuccess: (list) {
        context.replace('/lists/${list.id}');
      },
      onFailure: (e) {
        final message = e is NotFoundException
            ? 'import.error_not_found'.tr()
            : 'import.error_generic'.tr();
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/lists');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final muted = isDark ? AppColors.onDarkMuted : AppColors.muted;

    return Scaffold(
      key: const ValueKey(WidgetKeys.screenImport),
      body: Stack(
        children: [
          const DottedGround(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 40,
                  child: VkWaveform(isAnimating: true, opacity: 1),
                ),
                const SizedBox(height: 24),
                Text(
                  'import.loading_title'.tr(),
                  style: AppTextStyles.grotesk(
                    18,
                    FontWeight.w600,
                  ).copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'import.loading_subtitle'.tr(),
                  style: AppTextStyles.caption.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
