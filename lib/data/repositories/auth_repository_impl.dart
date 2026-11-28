import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../domain/entities/app_user.dart';
import '../../domain/entities/subscription_type.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/app_exception.dart';
import '../datasources/remote/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  final AuthRemote _remote;

  String? _accountId;
  int _accountRevision = 0;
  AppUser? _lastProfile;

  static const _inactiveAccount = Failure<AppUser>(
    AuthException('Profile account is no longer active'),
  );

  sb.User? get _activeUser {
    final user = _remote.currentUser;
    if (user?.id != _accountId) {
      _accountId = user?.id;
      ++_accountRevision;
      _lastProfile = null;
    }
    return user;
  }

  bool _isActive(sb.User user, int revision) =>
      _activeUser?.id == user.id && _accountRevision == revision;

  @override
  Stream<AppUser?> get authStateChanges => _remote.authStateChanges.map(
    (state) =>
        state.session?.user != null ? _mapUser(state.session!.user) : null,
  );

  @override
  AppUser? get currentUser {
    final user = _activeUser;
    if (user == null) return null;
    final profile = _lastProfile;
    final email = user.email ?? '';
    if (profile == null) return _mapUser(user);
    return profile.email == email ? profile : profile.copyWith(email: email);
  }

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _remote.signInWithEmail(email, password);
    return result.fold(
      onSuccess: (user) async {
        if (_activeUser?.id != user.id) return _inactiveAccount;
        return _finishAuthentication(user);
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
    final normalized = username.trim().toLowerCase();

    if (await _remote.checkUsernameExists(normalized)) {
      return const Failure(
        AuthException.forReason(AuthFailureReason.usernameTaken),
      );
    }

    final result = await _remote.signUpWithEmail(email, password, normalized);
    return result.fold(
      onSuccess: (user) async {
        // With email confirmation enabled, signup can return a user without
        // a signed-in session. The database trigger creates its profile.
        final active = _activeUser;
        if (active == null) {
          return Success(_mapUser(user, fallbackUsername: normalized));
        }
        if (active.id != user.id) return _inactiveAccount;
        return _finishAuthentication(user, fallbackUsername: normalized);
      },
      onFailure: (e) => Failure(e),
    );
  }

  Future<Result<AppUser>> _finishAuthentication(
    sb.User user, {
    String? fallbackUsername,
  }) async {
    final revision = _accountRevision;
    final result = await _loadProfile(user, fallbackUsername: fallbackUsername);
    if (!_isActive(user, revision)) return _inactiveAccount;
    // Valid credentials establish a local session even if the profile is
    // temporarily unavailable. Prefer any profile already read for it.
    return Success(
      result.valueOrNull ??
          _lastProfile ??
          _mapUser(user, fallbackUsername: fallbackUsername),
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
  Future<Result<void>> signOut() {
    ++_accountRevision;
    _lastProfile = null;
    return _remote.signOut();
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) =>
      _remote.sendPasswordReset(email);

  @override
  Future<Result<AppUser>> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final user = _activeUser;
    if (user == null) return const Failure(AuthException('Not signed in'));
    final revision = _accountRevision;
    final data = {
      'id': user.id,
      'display_name': ?displayName,
      'avatar_url': ?avatarUrl,
      'bio': ?bio,
      'updated_at': DateTime.now().toIso8601String(),
    };
    final result = await _remote.upsertProfile(data);
    if (!_isActive(user, revision)) return _inactiveAccount;
    return result.fold(
      onSuccess: (p) => Success(_lastProfile = _mapUserWithProfile(user, p)),
      onFailure: (e) => Failure(e),
    );
  }

  @override
  Future<Result<AppUser>> reloadProfile() async {
    final user = _activeUser;
    if (user == null) return const Failure(AuthException('Not signed in'));
    return _loadProfile(user);
  }

  Future<Result<AppUser>> _loadProfile(
    sb.User user, {
    String? fallbackUsername,
  }) async {
    final revision = _accountRevision;
    final fetched = await _remote.getProfile(user.id);
    if (!_isActive(user, revision)) return _inactiveAccount;
    if (fetched.exceptionOrNull case final error?) return Failure(error);
    var profile = fetched.valueOrNull;
    if (profile == null) {
      final username = _safeUsername(
        user.userMetadata?['username'] as String? ?? fallbackUsername,
        user.email,
      );
      final created = await _remote.createProfileIfMissing({
        'id': user.id,
        'username': username,
        'display_name': username,
      });
      if (!_isActive(user, revision)) return _inactiveAccount;
      if (created.exceptionOrNull case final error?) return Failure(error);
      profile = created.valueOrNull;
      if (profile == null) {
        // A concurrent writer won the insert. Read its profile as-is.
        final winner = await _remote.getProfile(user.id);
        if (!_isActive(user, revision)) return _inactiveAccount;
        if (winner.exceptionOrNull case final error?) return Failure(error);
        profile = winner.valueOrNull;
      }
    }
    if (profile == null) return const Failure(NotFoundException());
    return Success(_lastProfile = _mapUserWithProfile(user, profile));
  }

  // Ensures username meets DB minimum length of 3 chars.
  static String _safeUsername(String? fromMeta, String? email) {
    final raw = fromMeta ?? email?.split('@').first ?? 'user';
    return raw.length >= 3 ? raw : raw.padRight(3, '_');
  }

  @override
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  }) async {
    if (_remote.currentUser?.id != userId) {
      return const Failure(AuthException('Study account is no longer active'));
    }
    return _remote.updateStreak(userId: userId, studyDate: studyDate);
  }

  @override
  Future<Result<void>> deleteAccount() async {
    // Requires Supabase admin call — implement via Edge Function
    return const Failure(
      UnknownException('Account deletion not yet implemented'),
    );
  }

  AppUser _mapUser(sb.User user, {String? fallbackUsername}) => AppUser(
    id: user.id,
    email: user.email ?? '',
    username:
        user.userMetadata?['username'] as String? ?? fallbackUsername ?? '',
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
        lastStudyDate: DateTime.tryParse(
          profile['last_study_date'] as String? ?? '',
        ),
        subscriptionType: SubscriptionType.fromString(
          profile['subscription_type'] as String?,
        ),
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );
}
