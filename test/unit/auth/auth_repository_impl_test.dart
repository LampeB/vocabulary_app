import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/remote/auth_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/auth_repository_impl.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';

sb.User _user({
  String id = 'u1',
  String email = 'learner@example.com',
  Map<String, dynamic>? metadata,
}) =>
    sb.User(
      id: id,
      appMetadata: const {},
      userMetadata: metadata,
      aud: 'authenticated',
      email: email,
      createdAt: '2026-01-02T03:04:05.000Z',
    );

class _FakeAuthRemote implements AuthRemote {
  _FakeAuthRemote({
    Result<sb.User>? signInResult,
    Result<sb.User>? signUpResult,
    Result<Map<String, dynamic>>? profileResult,
    this.upsertResult,
    this.usernameExists = false,
  })  : signInResult =
            signInResult ?? const Failure(AuthException('bad login')),
        signUpResult =
            signUpResult ?? const Failure(AuthException('bad sign up')),
        profileResult =
            profileResult ?? const Failure(UnknownException('profile missing'));

  @override
  sb.User? currentUser;
  Result<sb.User> signInResult;
  Result<sb.User> signUpResult;
  Result<Map<String, dynamic>> profileResult;
  Result<Map<String, dynamic>>? upsertResult;
  bool usernameExists;
  final upserts = <Map<String, dynamic>>[];
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int resetCalls = 0;
  int streakCalls = 0;

  @override
  Stream<sb.AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> checkUsernameExists(String username) async => usernameExists;

  @override
  Future<Result<Map<String, dynamic>>> getProfile(String userId) async =>
      profileResult;

  @override
  Future<Result<sb.User>> signInWithEmail(String email, String password) async {
    signInCalls++;
    return signInResult;
  }

  @override
  Future<Result<sb.User>> signUpWithEmail(
      String email, String password, String username) async {
    signUpCalls++;
    return signUpResult;
  }

  @override
  Future<Result<void>> signOut() async {
    signOutCalls++;
    return const Success(null);
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    resetCalls++;
    return const Success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertProfile(
      Map<String, dynamic> data) async {
    upserts.add(data);
    return upsertResult ?? Success(data);
  }

  @override
  Future<Result<void>> updateStreak(String userId) async {
    streakCalls++;
    return const Success(null);
  }
}

void main() {
  group('AuthRepositoryImpl', () {
    test('sign-in maps the server profile onto the authenticated user',
        () async {
      final user = _user(metadata: {'username': 'fallback'});
      final remote = _FakeAuthRemote(
        signInResult: Success(user),
        profileResult: const Success({
          'username': 'marie',
          'display_name': 'Marie K.',
          'avatar_url': 'https://example.com/a.png',
          'bio': 'Bonjour',
          'total_words_mastered': 12,
          'current_streak': 4,
          'longest_streak': 9,
          'subscription_type': 'premium',
        }),
      );
      final repository = AuthRepositoryImpl(remote);

      final result = await repository.signInWithEmail(
        email: 'learner@example.com',
        password: 'secret',
      );
      final appUser = result.valueOrNull!;
      expect(appUser.id, 'u1');
      expect(appUser.username, 'marie');
      expect(appUser.displayName, 'Marie K.');
      expect(appUser.totalWordsMastered, 12);
      expect(appUser.currentStreak, 4);
      expect(appUser.subscriptionType, SubscriptionType.premium);
    });

    test('sign-in repairs a missing profile using a safe username', () async {
      final remote = _FakeAuthRemote(
        signInResult: Success(_user(email: 'ab@example.com')),
      );
      final result = await AuthRepositoryImpl(remote).signInWithEmail(
        email: 'ab@example.com',
        password: 'secret',
      );

      expect(result.valueOrNull?.username, '');
      expect(remote.upserts, [
        {'id': 'u1', 'username': 'ab_', 'display_name': 'ab_'}
      ]);
    });

    test('sign-up rejects an occupied username before contacting Supabase',
        () async {
      final remote = _FakeAuthRemote(usernameExists: true);
      final result = await AuthRepositoryImpl(remote).signUpWithEmail(
        email: 'a@b.com',
        password: 'secret',
        username: '  Taken  ',
      );

      expect(result.exceptionOrNull, isA<ValidationException>());
      expect(remote.signUpCalls, 0);
    });

    test('sign-up normalizes the username and repairs the profile', () async {
      final remote = _FakeAuthRemote(signUpResult: Success(_user()));
      final result = await AuthRepositoryImpl(remote).signUpWithEmail(
        email: 'a@b.com',
        password: 'secret',
        username: '  Marie_KR  ',
      );

      expect(result.valueOrNull?.id, 'u1');
      expect(remote.upserts.single['username'], 'marie_kr');
      expect(remote.upserts.single['display_name'], 'marie_kr');
    });

    test('localizes the already-registered Supabase error', () async {
      final remote = _FakeAuthRemote(
        signUpResult:
            const Failure(AuthException('User already registered with email')),
      );
      final result = await AuthRepositoryImpl(remote).signUpWithEmail(
        email: 'a@b.com',
        password: 'secret',
        username: 'marie',
      );

      expect(result.exceptionOrNull, isA<AuthException>());
      expect(result.exceptionOrNull?.message, contains('déjà utilisée'));
    });

    test('preserves ordinary sign-in and sign-up failures', () async {
      final signInRemote = _FakeAuthRemote(
        signInResult: const Failure(NetworkException('offline')),
      );
      final signIn = await AuthRepositoryImpl(signInRemote).signInWithEmail(
        email: 'a@b.com',
        password: 'secret',
      );
      expect(signIn.exceptionOrNull, isA<NetworkException>());

      final signUpRemote = _FakeAuthRemote(
        signUpResult: const Failure(AuthException('invalid password')),
      );
      final signUp = await AuthRepositoryImpl(signUpRemote).signUpWithEmail(
        email: 'a@b.com',
        password: 'secret',
        username: 'marie',
      );
      expect(signUp.exceptionOrNull?.message, 'invalid password');
    });

    test('requires an authenticated user for profile and streak mutations',
        () async {
      final remote = _FakeAuthRemote();
      final repository = AuthRepositoryImpl(remote);

      expect((await repository.updateProfile(displayName: 'Marie')).isFailure,
          isTrue);
      expect((await repository.reloadProfile()).isFailure, isTrue);
      expect((await repository.updateStreak()).isFailure, isTrue);
    });

    test('maps the current user and persists profile changes', () async {
      final remote = _FakeAuthRemote()..currentUser = _user();
      final repository = AuthRepositoryImpl(remote);

      expect(repository.currentUser?.email, 'learner@example.com');
      final result = await repository.updateProfile(
        displayName: 'Marie',
        avatarUrl: 'https://example.com/marie.png',
        bio: 'Prof',
      );

      expect(result.isSuccess, isTrue);
      expect(remote.upserts.single['id'], 'u1');
      expect(remote.upserts.single['display_name'], 'Marie');
      expect(remote.upserts.single['avatar_url'], contains('marie.png'));
      expect(remote.upserts.single['bio'], 'Prof');
      expect(remote.upserts.single['updated_at'], isA<String>());
    });

    test('keeps a remote profile update failure', () async {
      final remote = _FakeAuthRemote(
        upsertResult: const Failure(NetworkException('offline')),
      )..currentUser = _user();

      final result =
          await AuthRepositoryImpl(remote).updateProfile(displayName: 'Marie');
      expect(result.exceptionOrNull, isA<NetworkException>());
    });

    test('reloads an existing profile and creates a missing one', () async {
      final remote = _FakeAuthRemote(
        profileResult: const Success({
          'username': 'marie',
          'current_streak': 7,
        }),
      )..currentUser = _user(metadata: {'username': 'metadata_name'});
      final repository = AuthRepositoryImpl(remote);

      expect((await repository.reloadProfile()).valueOrNull?.currentStreak, 7);

      remote.profileResult = const Failure(UnknownException('gone'));
      expect((await repository.reloadProfile()).valueOrNull?.id, 'u1');
      expect(remote.upserts.last['username'], 'metadata_name');
    });

    test('forwards sign-out, reset and streak actions to the remote boundary',
        () async {
      final remote = _FakeAuthRemote()..currentUser = _user();
      final repository = AuthRepositoryImpl(remote);

      expect((await repository.signOut()).isSuccess, isTrue);
      expect((await repository.sendPasswordResetEmail('a@b.com')).isSuccess,
          isTrue);
      expect((await repository.updateStreak()).isSuccess, isTrue);
      expect(remote.signOutCalls, 1);
      expect(remote.resetCalls, 1);
      expect(remote.streakCalls, 1);
    });
  });
}
