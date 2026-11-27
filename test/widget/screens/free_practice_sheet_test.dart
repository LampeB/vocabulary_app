import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/core/languages.dart';
import 'package:vocab_kr/domain/entities/vocabulary_list.dart';
import 'package:vocab_kr/domain/usecases/quiz/get_due_cards_usecase.dart'
    show QuizSource;
import 'package:vocab_kr/presentation/providers/lists/vocabulary_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_provider.dart';
import 'package:vocab_kr/presentation/providers/quiz/quiz_availability_provider.dart';
import 'package:vocab_kr/domain/entities/concept.dart';
import 'package:vocab_kr/domain/entities/word_variant.dart';
import 'package:vocab_kr/presentation/widgets/free_practice_sheet.dart';
import '../../helpers/pump_screen.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets(
    'empty direction and a new account in-progress pool cannot start',
    (tester) async {
      await pumpScreen(
        tester,
        screen: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showFreePracticeSheet(context, pair: ('en', 'ko')),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([])),
          studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
          quizAvailabilityProvider.overrideWith(
            (ref, q) => Stream.value(
              q.source == QuizSource.allDue &&
                      q.direction != QuizDirectionChoice.frToKo
                  ? 3
                  : 0,
            ),
          ),
        ],
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('free-practice-start'));
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.tap(
        find.byKey(const ValueKey('free-practice-direction-frToKo')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      expect(
        find.text('Aucune carte n’est disponible pour cette sélection.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('free-practice-in-progress')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await unmountScreen(tester);
    },
  );

  testWidgets('a long preview title and its words share a signalled scroller', (
    tester,
  ) async {
    final now = DateTime(2026);
    final list = VocabularyList(
      id: 'long',
      ownerId: 'u',
      name: List.filled(10, 'Salutations utiles en voyage').join(' '),
      wordCount: 1,
      langA: 'en',
      langB: 'ko',
      createdAt: now,
      updatedAt: now,
    );
    await pumpScreen(
      tester,
      screen: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showFreePracticeSheet(context, pair: ('en', 'ko')),
            child: const Text('Open'),
          ),
        ),
      ),
      overrides: [
        myListsProvider.overrideWith((ref) => Stream.value([list])),
        studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
        quizAvailabilityProvider.overrideWith((ref, q) => Stream.value(0)),
        listDetailProvider.overrideWith(
          (ref, id) => Stream.value([
            Concept(id: 'c', listId: 'long', createdAt: now, updatedAt: now),
          ]),
        ),
        variantsProvider.overrideWith(
          (ref, id) => Stream.value([
            WordVariant(
              id: 'en',
              conceptId: 'c',
              word: 'hello',
              langCode: 'en',
              createdAt: now,
              updatedAt: now,
            ),
            WordVariant(
              id: 'ko',
              conceptId: 'c',
              word: '안녕',
              langCode: 'ko',
              createdAt: now,
              updatedAt: now,
            ),
          ]),
        ),
      ],
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final preview = find.byTooltip('Aperçu');
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.byType(CustomScrollView), findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    for (var i = 0; i < 3; i++) {
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    await tester.pumpAndSettle();
    expect(find.text('hello').hitTestable(), findsOneWidget);
    expect(find.text('안녕').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmountScreen(tester);
  });
  for (final pair in [('fr', 'ko'), ('en', 'ko'), ('ko', 'fr')]) {
    testWidgets('sheet launches both directions in $pair without full setup', (
      tester,
    ) async {
      QuizArgs? args;
      await pumpScreen(
        tester,
        screen: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFreePracticeSheet(context, pair: pair),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([])),
          studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
          quizAvailabilityProvider.overrideWith(
            (ref, q) => Stream.value(q.pair == pair ? 24 : 0),
          ),
          dueCountForPairProvider.overrideWith(
            (ref, p) => Stream.value(p == pair ? 24 : 0),
          ),
        ],
        routes: [
          GoRoute(
            path: '/quiz',
            builder: (_, state) {
              args = state.extra! as QuizArgs;
              return const Scaffold(body: Text('Quiz'));
            },
          ),
        ],
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '${Languages.displayName(pair.$1)} → ${Languages.displayName(pair.$2)}',
        ),
        findsWidgets,
      );
      final start = find.byKey(const ValueKey('free-practice-start'));
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(args!.source, QuizSource.allDue);
      expect(args!.direction, QuizDirectionChoice.both);
      expect((args!.langA, args!.langB), pair);
      expect(args!.cardLimit, 20);
    });
  }

  testWidgets(
    'an unstudied list is immediately playable with keyboard at double text',
    (tester) async {
      QuizArgs? args;
      final now = DateTime(2026);
      final list = VocabularyList(
        id: 'l',
        ownerId: 'u',
        name: 'Salutations',
        wordCount: 5,
        langA: 'en',
        langB: 'ko',
        createdAt: now,
        updatedAt: now,
      );
      await pumpScreen(
        tester,
        screen: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showFreePracticeSheet(context, pair: ('en', 'ko')),
              child: const Text('Open'),
            ),
          ),
        ),
        overrides: [
          myListsProvider.overrideWith((ref) => Stream.value([list])),
          studiedListIdsProvider.overrideWith((ref) => Stream.value({})),
          quizAvailabilityProvider.overrideWith(
            (ref, q) => Stream.value(q.source == QuizSource.list ? 5 : 0),
          ),
          dueCountForPairProvider.overrideWith((ref, p) => Stream.value(0)),
        ],
        routes: [
          GoRoute(
            path: '/quiz',
            builder: (_, state) {
              args = state.extra! as QuizArgs;
              return const Scaffold(body: Text('Quiz'));
            },
          ),
        ],
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final listChoice = find.byKey(const ValueKey('free-practice-list-l'));
      await tester.ensureVisible(listChoice);
      await tester.tap(listChoice);
      await tester.pumpAndSettle();
      final typing = find.byKey(const ValueKey('free-practice-mode-typing'));
      await tester.ensureVisible(typing);
      await tester.tap(typing);
      final start = find.byKey(const ValueKey('free-practice-start'));
      await tester.ensureVisible(start);
      Focus.of(
        tester.element(
          find.descendant(of: start, matching: find.byType(Text)).first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(args!.listId, 'l');
      expect(args!.mode, QuizMode.typing);
      expect(tester.takeException(), isNull);
    },
  );
}
