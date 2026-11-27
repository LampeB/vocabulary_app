import 'package:easy_localization/easy_localization.dart';

/// Both lesson entry points display user names before catalog translations.
String grammarPrerequisiteLabel(
  String token,
  Map<String, String> names,
  Map<String, String> catalogKeys,
) => names[token] ?? (catalogKeys[token] ?? 'list_detail.appbar_fallback').tr();
