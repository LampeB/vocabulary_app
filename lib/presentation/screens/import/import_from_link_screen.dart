import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/dotted_ground.dart';
import '../../widgets/vk_waveform.dart';

class ImportFromLinkScreen extends ConsumerStatefulWidget {
  const ImportFromLinkScreen({required this.token, super.key});
  final String token;

  @override
  ConsumerState<ImportFromLinkScreen> createState() =>
      _ImportFromLinkScreenState();
}

class _ImportFromLinkScreenState
    extends ConsumerState<ImportFromLinkScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _import());
  }

  Future<void> _import() async {
    final result = await ref
        .read(listActionsProvider.notifier)
        .importFromLink(widget.token);

    if (!mounted) return;

    result.fold(
      onSuccess: (list) {
        context.go('/lists/${list.id}');
      },
      onFailure: (e) {
        final message = e is NotFoundException
            ? 'Liste introuvable — le lien est peut-être expiré.'
            : 'Impossible d\'importer la liste. Réessaie.';
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating));
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
    return Scaffold(
      backgroundColor: AppColors.paper,
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
                Text('Importation en cours…',
                    style: AppTextStyles.grotesk(18, FontWeight.w600)
                        .copyWith(color: AppColors.ink)),
                const SizedBox(height: 8),
                Text('La liste partagée arrive.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
