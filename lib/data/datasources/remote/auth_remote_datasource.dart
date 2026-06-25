import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart' as app_ex;
import '../../../core/errors/failure.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);
  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  Future<Result<User>> signInWithEmail(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) {
        return const Failure(app_ex.AuthException('Sign in failed'));
      }
      return Success(res.user!);
    } on AuthException catch (e) {
      return Failure(app_ex.AuthException(e.message));
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  Future<Result<User>> signUpWithEmail(
      String email, String password, String username) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      if (res.user == null) {
        return const Failure(app_ex.AuthException('Sign up failed'));
      }
      return Success(res.user!);
    } on AuthException catch (e) {
      return Failure(app_ex.AuthException(e.message));
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Success(null);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Success(null);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  Future<bool> checkUsernameExists(String username) async {
    try {
      final rows = await _client
          .from('profiles')
          .select('id')
          .ilike('username', username)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Result<Map<String, dynamic>>> getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return Success(data);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  Future<Result<Map<String, dynamic>>> upsertProfile(
      Map<String, dynamic> data) async {
    try {
      final result =
          await _client.from('profiles').upsert(data).select().single();
      return Success(result);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  Future<Result<void>> updateStreak(String userId) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
          (await _client
                  .from('profiles')
                  .select('current_streak, longest_streak, last_study_date')
                  .eq('id', userId)
                  .limit(1)) as List);
      if (rows.isEmpty) return const Success(null);
      final profile = rows.first;

      final today = DateTime.now().toLocal();
      final todayDate = DateTime(today.year, today.month, today.day);
      final lastRaw = profile['last_study_date'] as String?;

      if (lastRaw != null) {
        final last = DateTime.parse(lastRaw);
        if (DateTime(last.year, last.month, last.day) == todayDate) {
          return const Success(null);
        }
      }

      final current = profile['current_streak'] as int? ?? 0;
      final longest = profile['longest_streak'] as int? ?? 0;
      final yesterday = todayDate.subtract(const Duration(days: 1));

      int newStreak;
      if (lastRaw != null) {
        final last = DateTime.parse(lastRaw);
        final lastDay = DateTime(last.year, last.month, last.day);
        newStreak = lastDay == yesterday ? current + 1 : 1;
      } else {
        newStreak = 1;
      }

      String p2(int n) => n.toString().padLeft(2, '0');
      await _client.from('profiles').update({
        'current_streak': newStreak,
        'longest_streak': newStreak > longest ? newStreak : longest,
        'last_study_date':
            '${todayDate.year}-${p2(todayDate.month)}-${p2(todayDate.day)}',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return const Success(null);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }
}
