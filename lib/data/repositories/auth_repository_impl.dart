import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/app_exception.dart';
import '../datasources/remote/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  final AuthRemoteDataSource _remote;

  @override
  Stream<AppUser?> get authStateChanges => _remote.authStateChanges.map(
        (state) => state.session?.user != null
            ? _mapUser(state.session!.user)
            : null,
      );

  @override
  AppUser? get currentUser {
    final user = _remote.currentUser;
    return user != null ? _mapUser(user) : null;
  }

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _remote.signInWithEmail(email, password);
    return result.fold(
      onSuccess: (user) async {
        final profile = await _remote.getProfile(user.id);
        return profile.fold(
          onSuccess: (p) => Success(_mapUserWithProfile(user, p)),
          onFailure: (_) => Success(_mapUser(user)),
        );
      },
      onFailure: (e) => Failure(e),
    );
  }

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final result = await _remote.signUpWithEmail(email, password, username);
    return result.fold(
      onSuccess: (user) async {
        final profileData = {
          'id': user.id,
          'username': username,
          'display_name': username,
        };
        await _remote.upsertProfile(profileData);
        return Success(_mapUser(user));
      },
      onFailure: (e) => Failure(e),
    );
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    // OAuth handled by Supabase deep link; implement platform-specific flow
    return const Failure(UnknownException('Google sign-in not yet configured'));
  }

  @override
  Future<Result<AppUser>> signInWithApple() async {
    return const Failure(UnknownException('Apple sign-in not yet configured'));
  }

  @override
  Future<Result<void>> signOut() => _remote.signOut();

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) =>
      _remote.sendPasswordReset(email);

  @override
  Future<Result<AppUser>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final user = _remote.currentUser;
    if (user == null) return const Failure(AuthException('Not signed in'));
    final data = {
      'id': user.id,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final result = await _remote.upsertProfile(data);
    return result.fold(
      onSuccess: (p) => Success(_mapUserWithProfile(user, p)),
      onFailure: (e) => Failure(e),
    );
  }

  @override
  Future<Result<AppUser>> reloadProfile() async {
    final user = _remote.currentUser;
    if (user == null) return const Failure(AuthException('Not signed in'));
    final profile = await _remote.getProfile(user.id);
    return profile.fold(
      onSuccess: (p) => Success(_mapUserWithProfile(user, p)),
      onFailure: (e) => Failure(e),
    );
  }

  @override
  Future<Result<void>> updateStreak() async {
    final user = _remote.currentUser;
    if (user == null) return const Failure(AuthException('Not signed in'));
    return _remote.updateStreak(user.id);
  }

  @override
  Future<Result<void>> deleteAccount() async {
    // Requires Supabase admin call — implement via Edge Function
    return const Failure(UnknownException('Account deletion not yet implemented'));
  }

  AppUser _mapUser(sb.User user) => AppUser(
        id: user.id,
        email: user.email ?? '',
        username: user.userMetadata?['username'] as String? ?? '',
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );

  AppUser _mapUserWithProfile(sb.User user, Map<String, dynamic> profile) =>
      AppUser(
        id: user.id,
        email: user.email ?? '',
        username: profile['username'] as String? ?? '',
        displayName: profile['display_name'] as String?,
        avatarUrl: profile['avatar_url'] as String?,
        bio: profile['bio'] as String?,
        totalWordsMastered: profile['total_words_mastered'] as int? ?? 0,
        currentStreak: profile['current_streak'] as int? ?? 0,
        longestStreak: profile['longest_streak'] as int? ?? 0,
        isPremium: profile['is_premium'] as bool? ?? false,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );
}
