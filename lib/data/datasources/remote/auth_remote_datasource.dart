import 'dart:async' show TimeoutException;

import 'package:http/http.dart' as http;
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

  /// A successful null means the query returned no row.
  Future<Result<Map<String, dynamic>?>> getProfile(String userId);

  /// Returns the inserted row, or null when another row already has this ID.
  Future<Result<Map<String, dynamic>?>> createProfileIfMissing(
    Map<String, dynamic> data,
  );
  Future<Result<Map<String, dynamic>>> upsertProfile(Map<String, dynamic> data);
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  });
}

class AuthRemoteDataSource implements AuthRemote {
  AuthRemoteDataSource(this._client);
  final SupabaseClient _client;

  @override
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange.handleError(
        // GoTrue keeps the local session after a retryable fetch error.
        // Session loss is reported separately as a signedOut event.
        (Object _) {},
        test: (error) => error is AuthRetryableFetchException,
      );
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
    } on AuthException catch (e) {
      return Failure(_authFailure(e));
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
  Future<Result<Map<String, dynamic>?>> getProfile(String userId) async {
    try {
      final rows = await _client.from('profiles').select().eq('id', userId);
      return Success(rows.isEmpty ? null : rows.single);
    } catch (e) {
      return Failure(_postgrestFailure(e));
    }
  }

  @override
  Future<Result<Map<String, dynamic>?>> createProfileIfMissing(
    Map<String, dynamic> data,
  ) async {
    try {
      final rows = await _client
          .from('profiles')
          .upsert(data, onConflict: 'id', ignoreDuplicates: true)
          .select();
      return Success(rows.isEmpty ? null : rows.single);
    } catch (e) {
      return Failure(_postgrestFailure(e));
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
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  }) async {
    const inactiveAccount = Failure<void>(
      app_ex.AuthException('Study account is no longer active'),
    );
    if (currentUser?.id != userId) return inactiveAccount;
    final studyDay = civilDate(studyDate);
    try {
      await _client
          .rpc(
            'record_study_day',
            params: {
              'p_user_id': userId,
              'p_study_date': studyDay.toIso8601String().split('T').first,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (currentUser?.id != userId) return inactiveAccount;
      return const Success(null);
    } catch (e) {
      return Failure(_postgrestFailure(e));
    }
  }
}

app_ex.AppException _postgrestFailure(Object error) => switch (error) {
  http.ClientException() ||
  TimeoutException() ||
  AuthRetryableFetchException() ||
  PostgrestException(
    code: 'PGRST000' ||
        'PGRST001' ||
        'PGRST002' ||
        'PGRST003' ||
        '502' ||
        '503' ||
        '504',
  ) => const app_ex.NetworkException(),
  PostgrestException(code: '42501') => const app_ex.PermissionException(),
  _ => app_ex.UnknownException(error.toString()),
};

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
    _ when error.statusCode == '429' => app_ex.AuthFailureReason.rateLimited,
    _ when error.message.toLowerCase().contains('already registered') =>
      app_ex.AuthFailureReason.emailTaken,
    _ => app_ex.AuthFailureReason.unknown,
  };
  return app_ex.AuthException.forReason(reason);
}
