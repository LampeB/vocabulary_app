import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart' as app_ex;
import '../../../core/errors/failure.dart';
import '../../../core/utils/streak.dart';

abstract interface class AuthRemote {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  Future<Result<User>> signInWithEmail(String email, String password);
  Future<Result<User>> signUpWithEmail(
    String email,
    String password,
    String username,
  );
  Future<Result<void>> signOut();
  Future<Result<void>> sendPasswordReset(String email);
  Future<bool> checkUsernameExists(String username);
  Future<Result<Map<String, dynamic>>> getProfile(String userId);
  Future<Result<Map<String, dynamic>>> upsertProfile(Map<String, dynamic> data);
  Future<Result<void>> updateStreak(String userId);
}

class AuthRemoteDataSource implements AuthRemote {
  AuthRemoteDataSource(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final SupabaseClient _client;
  final DateTime Function() _now;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  @override
  User? get currentUser => _client.auth.currentUser;

  @override
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
      return Failure(_authFailure(e));
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  @override
  Future<Result<User>> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
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
      return Failure(_authFailure(e));
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Success(null);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return const Success(null);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  @override
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

  @override
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

  @override
  Future<Result<Map<String, dynamic>>> upsertProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _client
          .from('profiles')
          .upsert(data)
          .select()
          .single();
      return Success(result);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateStreak(String userId) async {
    try {
      final rows = List<Map<String, dynamic>>.from(
        (await _client
                .from('profiles')
                .select('current_streak, longest_streak, last_study_date')
                .eq('id', userId)
                .limit(1))
            as List,
      );
      if (rows.isEmpty) return const Success(null);
      final profile = rows.first;

      final today = _now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final lastRaw = profile['last_study_date'] as String?;

      final current = profile['current_streak'] as int? ?? 0;
      final longest = profile['longest_streak'] as int? ?? 0;
      final update = computeStreak(
        today: today,
        lastStudyDate: lastRaw == null ? null : DateTime.parse(lastRaw),
        currentStreak: current,
      );
      if (update.alreadyCountedToday) return const Success(null);
      final newStreak = update.streak;

      String p2(int n) => n.toString().padLeft(2, '0');
      await _client
          .from('profiles')
          .update({
            'current_streak': newStreak,
            'longest_streak': newStreak > longest ? newStreak : longest,
            'last_study_date':
                '${todayDate.year}-${p2(todayDate.month)}-${p2(todayDate.day)}',
            'updated_at': today.toUtc().toIso8601String(),
          })
          .eq('id', userId);

      return const Success(null);
    } catch (e) {
      return Failure(app_ex.UnknownException(e.toString()));
    }
  }
}

app_ex.AppException _authFailure(AuthException error) {
  if (error is AuthRetryableFetchException) {
    return const app_ex.NetworkException();
  }
  final reason = switch (error.code) {
    'invalid_credentials' => app_ex.AuthFailureReason.invalidCredentials,
    'email_exists' ||
    'user_already_exists' => app_ex.AuthFailureReason.emailTaken,
    'email_not_confirmed' => app_ex.AuthFailureReason.emailNotConfirmed,
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' ||
    'over_sms_send_rate_limit' => app_ex.AuthFailureReason.rateLimited,
    _ when error.message.toLowerCase().contains('already registered') =>
      app_ex.AuthFailureReason.emailTaken,
    _ => app_ex.AuthFailureReason.unknown,
  };
  return app_ex.AuthException.forReason(reason);
}
