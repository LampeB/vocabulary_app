import 'dart:convert';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/widget_keys.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/grammar/grammar_provider.dart';
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/screens/home/v3_home_screen.dart';

import '../../helpers/pump_screen.dart';

void main() {
  setUpAll(initTestLocalization);

  for (final locale in ['fr', 'en', 'ko']) {
    testWidgets('home actions remain reachable with large text in $locale',
        (tester) async {
      final raw = (await tester.runAsync(
          () => rootBundle.loadString('assets/translations/$locale.json')))!;
      final translations =
          Translations(jsonDecode(raw) as Map<String, dynamic>);
      Localization.load(Locale(locale),
          translations: translations, fallbackTranslations: translations);
      addTearDown(initTestLocalization);

      await pumpScreen(tester,
          settle: false,
          screen: Builder(
              builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: const V3HomeScreen())),
          overrides: [
            currentUserProvider.overrideWithValue(null),
            myListsProvider.overrideWith((ref) => Stream.value([])),
            dueCountForPairProvider
                .overrideWith((ref, pair) => Stream.value(0)),
            ruleStatusesProvider.overrideWith((ref, lang) async => []),
          ]);
      tester.view.physicalSize = const Size(960, 1704);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester
          .ensureVisible(find.byKey(const ValueKey(WidgetKeys.homeGrammar)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await unmountScreen(tester);
    });
  }
}
