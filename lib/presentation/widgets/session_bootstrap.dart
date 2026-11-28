import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lists/vocabulary_provider.dart';
import '../providers/notifications/notification_provider.dart';

/// Keeps authenticated bootstrap alive across route changes and pair changes.
/// Navigation, including a cold import, stays usable while restoration retries.
class SessionBootstrap extends ConsumerWidget {
  const SessionBootstrap({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(seedStarterListsProvider);
    final locale = EasyLocalization.of(context)?.locale ?? const Locale('fr');
    ref.watch(authenticatedRemindersProvider(locale));
    return child;
  }
}
