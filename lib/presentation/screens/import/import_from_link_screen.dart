import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/lists/vocabulary_provider.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/failure.dart';

class ImportFromLinkScreen extends ConsumerStatefulWidget {
  const ImportFromLinkScreen({required this.token, super.key});
  final String token;

  @override
  ConsumerState<ImportFromLinkScreen> createState() => _ImportFromLinkScreenState();
}

class _ImportFromLinkScreenState extends ConsumerState<ImportFromLinkScreen> {
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
            ? 'This shared list could not be found.'
            : 'Failed to import list. Please try again.';
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(message)));
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
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Importing shared list…'),
          ],
        ),
      ),
    );
  }
}
