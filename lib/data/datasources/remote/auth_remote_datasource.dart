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
}
