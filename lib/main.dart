import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/database/database_service.dart';

void main() async {
  // Initialisation Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: Initialiser sqflite FFI pour Windows/Linux/macOS
  DatabaseService.initializeFfi();

  // Initialiser la base de données
  final db = DatabaseService();
  await db.database; // Force l'initialisation

  runApp(const VocabularyApp());
}

class VocabularyApp extends StatelessWidget {
  const VocabularyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocabApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
