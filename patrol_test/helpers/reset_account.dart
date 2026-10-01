import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_kr/core/config/app_config.dart';
import 'package:vocab_kr/data/datasources/local/app_database.dart';

/// Runs before app.main(), so no sync or provider can repopulate cleared data.
/// Only the server-side administrator allowlist authorizes the destructive RPC.
Future<void> resetTestAccount() async {
  const email = String.fromEnvironment('TEST_EMAIL');
  const password = String.fromEnvironment('TEST_PASSWORD');
  if (!const bool.fromEnvironment('TEST_MODE') ||
      const String.fromEnvironment('TEST_SESSION').isNotEmpty ||
      email.isEmpty ||
      password.isEmpty) {
    throw StateError(
        'E2E reset requires TEST_MODE, dedicated credentials and no shared TEST_SESSION.');
  }
  final client =
      SupabaseClient(AppConfig.supabaseUrl, AppConfig.supabaseAnonKey);
  try {
    final auth =
        await client.auth.signInWithPassword(email: email, password: password);
    if (auth.user == null ||
        auth.user!.email?.toLowerCase() != email.toLowerCase()) {
      throw StateError('E2E account identity mismatch.');
    }
    final result = await client.rpc('reset_e2e_account');
    if (result is! Map ||
        result['user_id'] != auth.user!.id ||
        result['baseline'] != 'empty-free-v1') {
      throw StateError('E2E server baseline was not confirmed.');
    }
  } finally {
    // Do not revoke other sessions: the app will sign in independently.
    await client.dispose();
  }

  final database = AppDatabase();
  try {
    await resetLocalDatabase(database);
  } finally {
    await database.close();
  }
  final prefs = await SharedPreferences.getInstance();
  if (!await prefs.clear()) throw StateError('E2E preference reset failed.');
  await prefs.reload();
  if (prefs.getKeys().isNotEmpty) throw StateError('E2E preferences remain.');
}

/// Separate seam for verifying FK ordering and rollback against real SQLite.
Future<void> resetLocalDatabase(AppDatabase database) async {
  await database.transaction(() async {
    // Child tables precede vocabulary parents; includes local-only history.
    for (final table in database.allTables.toList().reversed) {
      await database.delete(table).go();
    }
    for (final table in database.allTables) {
      if ((await database.select(table).get()).isNotEmpty) {
        throw StateError('E2E local database reset failed.');
      }
    }
  });
}
