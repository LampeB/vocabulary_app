import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

/// Shared production locale configuration, including fallback for partial UI copies.
class PonderinLocalization extends StatelessWidget {
  const PonderinLocalization({
    super.key,
    required this.child,
    this.startLocale,
  });
  final Widget child;
  final Locale? startLocale;

  @override
  Widget build(BuildContext context) => EasyLocalization(
    supportedLocales: const [
      Locale('fr'),
      Locale('en'),
      Locale('es'),
      Locale('de'),
      Locale('it'),
      Locale('ja'),
      Locale('ko'),
    ],
    path: 'assets/translations',
    fallbackLocale: const Locale('fr'),
    useFallbackTranslations: true,
    startLocale: startLocale,
    child: child,
  );
}
