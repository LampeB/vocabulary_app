import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vocabulary_app/main.dart' as app;

/// Integration test for VocabApp
/// Tests complete user flows from start to finish
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VocabApp Integration Tests', () {
    testWidgets('App launches and shows home screen', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify home screen elements
      expect(find.text('Listes de vocabulaire'), findsOneWidget);
    });

    testWidgets('Can create a new vocabulary list', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Find and tap the create list button
      final createButton = find.byIcon(Icons.add);
      expect(createButton, findsOneWidget);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify create list dialog appears
      expect(find.text('Nouvelle liste'), findsOneWidget);

      // Enter list details
      await tester.enterText(
        find.byType(TextField).at(0),
        'Test List',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Description for test list',
      );

      // Tap create button in dialog
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      // Verify list appears on home screen
      expect(find.text('Test List'), findsOneWidget);
    });

    testWidgets('Can navigate to list detail screen', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // If there are lists, tap on the first one
      final listTiles = find.byType(ListTile);
      if (listTiles.evaluate().isNotEmpty) {
        await tester.tap(listTiles.first);
        await tester.pumpAndSettle();

        // Verify we're on the detail screen
        // Should see floating action button for adding words
        expect(find.byType(FloatingActionButton), findsOneWidget);

        // Should see back button
        expect(find.byTooltip('Back'), findsOneWidget);
      }
    });

    testWidgets('App handles navigation correctly', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Create a list
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Nav Test List');
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      // Navigate to the list
      await tester.tap(find.text('Nav Test List'));
      await tester.pumpAndSettle();

      // Navigate back
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Verify we're back on home screen
      expect(find.text('Listes de vocabulaire'), findsOneWidget);
    });
  });

  group('Quiz Flow Integration Tests', () {
    testWidgets('Can start quiz when words exist', (tester) async {
      // Note: This test assumes there are words in at least one list
      // In a real scenario, you'd set up test data first

      app.main();
      await tester.pumpAndSettle();

      // Find a list and navigate to it
      final listTiles = find.byType(ListTile);
      if (listTiles.evaluate().isEmpty) {
        // Skip test if no lists
        return;
      }

      await tester.tap(listTiles.first);
      await tester.pumpAndSettle();

      // Look for quiz button
      final quizButtons = find.byIcon(Icons.quiz);
      if (quizButtons.evaluate().isNotEmpty) {
        await tester.tap(quizButtons.first);
        await tester.pumpAndSettle();

        // Verify quiz screen appears
        // Should see question and answer input
        expect(find.byType(TextField), findsWidgets);
      }
    });
  });

  group('Dark Mode Integration Test', () {
    testWidgets('App respects system theme', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Get the MaterialApp
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

      // Verify both themes are defined
      expect(materialApp.theme, isNotNull);
      expect(materialApp.darkTheme, isNotNull);
      expect(materialApp.themeMode, ThemeMode.system);
    });
  });
}
