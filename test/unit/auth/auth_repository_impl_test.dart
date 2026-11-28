import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/remote/auth_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/auth_repository_impl.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';

sb.User _user({
  String id = 'u1',
  String email = 'learner@example.com',
  Map<String, dynamic>? metadata,
}) => sb.User(
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
    this.profileResult = const Success(null),
    this.createResult,
    this.upsertResult,
    this.usernameExists = false,
    this.signsInOnSignUp = true,
  }) : signInResult = signInResult ?? const Failure(AuthException('bad login')),
       signUpResult =
           signUpResult ?? const Failure(AuthException('bad sign up'));

  @override
  sb.User? currentUser;
  Result<sb.User> signInResult;
  Result<sb.User> signUpResult;
  Result<Map<String, dynamic>?> profileResult;
  Future<Result<Map<String, dynamic>?>> Function(String)? readProfile;
  Result<Map<String, dynamic>?>? createResult;
  Result<Map<String, dynamic>>? upsertResult;
  bool usernameExists;
  bool signsInOnSignUp;
  final profileReads = <String>[];
  final profileCreates = <Map<String, dynamic>>[];
  final upserts = <Map<String, dynamic>>[];
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  int resetCalls = 0;
  final streakUpdates = <(String, DateTime)>[];

  @override
  Stream<sb.AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> checkUsernameExists(String username) async => usernameExists;

  @override
  Future<Result<Map<String, dynamic>?>> getProfile(String userId) async {
    profileReads.add(userId);
    final read = readProfile;
    return read == null ? profileResult : await read(userId);
  }

  @override
  Future<Result<Map<String, dynamic>?>> createProfileIfMissing(
    Map<String, dynamic> data,
  ) async {
    profileCreates.add(data);
    return createResult ?? Success(data);
  }

  @override
  Future<Result<sb.User>> signInWithEmail(String email, String password) async {
    signInCalls++;
    if (signInResult.valueOrNull case final user?) currentUser = user;
    return signInResult;
  }

  @override
  Future<Result<sb.User>> signUpWithEmail(
    String email,
    String password,
    String username,
  ) async {
    signUpCalls++;
    if (signsInOnSignUp && signUpResult.valueOrNull != null) {
      currentUser = signUpResult.valueOrNull;
    }
    return signUpResult;
  }

  @override
  Future<Result<void>> signOut() async {
    signOutCalls++;
    currentUser = null;
    return const Success(null);
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    resetCalls++;
    return const Success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> upsertProfile(
    Map<String, dynamic> data,
  ) async {
    upserts.add(data);
    return upsertResult ?? Success(data);
  }

  @override
  Future<Result<void>> updateStreak({
    required String userId,
    required DateTime studyDate,
  }) async {
    streakUpdates.add((userId, studyDate));
    return const Success(null);
  }
}

void main() {
  group('AuthRepositoryImpl', () {
    test(
      'sign-in maps the server profile onto the authenticated user',
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
      },
    );

    test('sign-in repairs a missing profile using a safe username', () async {
      final remote = _FakeAuthRemote(
        signInResult: Success(_user(email: 'ab@example.com')),
      );
      final result = await AuthRepositoryImpl(
        remote,
      ).signInWithEmail(email: 'ab@example.com', password: 'secret');

      expect(result.valueOrNull?.username, 'ab_');
      expect(remote.profileCreates, [
        {'id': 'u1', 'username': 'ab_', 'display_name': 'ab_'},
      ]);
      expect(remote.upserts, isEmpty);
    });

    test(
      'sign-up rejects an occupied username before contacting Supabase',
      () async {
        final remote = _FakeAuthRemote(usernameExists: true);
        final result = await AuthRepositoryImpl(remote).signUpWithEmail(
          email: 'a@b.com',
          password: 'secret',
          username: '  Taken  ',
        );

        expect(
          (result.exceptionOrNull as AuthException).reason,
          AuthFailureReason.usernameTaken,
        );
        expect(remote.signUpCalls, 0);
      },
    );

    test('sign-up normalizes the username and repairs the profile', () async {
      final remote = _FakeAuthRemote(signUpResult: Success(_user()));
      final result = await AuthRepositoryImpl(remote).signUpWithEmail(
        email: 'a@b.com',
        password: 'secret',
        username: '  Marie_KR  ',
      );

      expect(result.valueOrNull?.id, 'u1');
      expect(result.valueOrNull?.username, 'marie_kr');
      expect(remote.profileCreates.single['username'], 'marie_kr');
      expect(remote.profileCreates.single['display_name'], 'marie_kr');
      expect(remote.upserts, isEmpty);
    });

    test(
      'sign-up with a session keeps the profile created by the trigger',
      () async {
        final remote = _FakeAuthRemote(
          signUpResult: Success(_user()),
          profileResult: const Success({'username': 'existing'}),
        );
        final result = await AuthRepositoryImpl(remote).signUpWithEmail(
          email: 'a@b.com',
          password: 'secret',
          username: 'marie',
        );

        expect(result.valueOrNull?.username, 'existing');
        expect(remote.profileCreates, isEmpty);
        expect(remote.upserts, isEmpty);
      },
    );

    test(
      'sign-up pending email confirmation sends no profile request',
      () async {
        final remote = _FakeAuthRemote(
          signUpResult: Success(_user()),
          signsInOnSignUp: false,
        );
        final repository = AuthRepositoryImpl(remote);
        final result = await repository.signUpWithEmail(
          email: 'a@b.com',
          password: 'secret',
          username: 'marie',
        );

        expect(result.valueOrNull?.username, 'marie');
        expect(repository.currentUser, isNull);
        expect(remote.profileReads, isEmpty);
        expect(remote.profileCreates, isEmpty);
        expect(remote.upserts, isEmpty);
      },
    );

    test('preserves the locale-independent duplicate email reason', () async {
      final remote = _FakeAuthRemote(
        signUpResult: const Failure(
          AuthException.forReason(AuthFailureReason.emailTaken),
        ),
      );
      final result = await AuthRepositoryImpl(remote).signUpWithEmail(
        email: 'a@b.com',
        password: 'secret',
        username: 'marie',
      );

      expect(result.exceptionOrNull, isA<AuthException>());
      expect(
        (result.exceptionOrNull as AuthException).reason,
        AuthFailureReason.emailTaken,
      );
    });

    test('preserves ordinary sign-in and sign-up failures', () async {
      final signInRemote = _FakeAuthRemote(
        signInResult: const Failure(NetworkException('offline')),
      );
      final signIn = await AuthRepositoryImpl(
        signInRemote,
      ).signInWithEmail(email: 'a@b.com', password: 'secret');
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

    test(
      'requires an authenticated user for profile and streak mutations',
      () async {
        final remote = _FakeAuthRemote();
        final repository = AuthRepositoryImpl(remote);

        expect(
          (await repository.updateProfile(displayName: 'Marie')).isFailure,
          isTrue,
        );
        expect((await repository.reloadProfile()).isFailure, isTrue);
        final studyDate = DateTime.utc(2026, 11, 26);
        expect(
          (await repository.updateStreak(
            userId: 'u1',
            studyDate: studyDate,
          )).isFailure,
          isTrue,
        );

        remote.currentUser = _user(id: 'u2');
        expect(
          (await repository.updateStreak(
            userId: 'u1',
            studyDate: studyDate,
          )).isFailure,
          isTrue,
        );
        expect(remote.streakUpdates, isEmpty);
      },
    );

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

      final result = await AuthRepositoryImpl(
        remote,
      ).updateProfile(displayName: 'Marie');
      expect(result.exceptionOrNull, isA<NetworkException>());
    });

    test(
      'reload keeps the last profile on failure until a successful retry',
      () async {
        final remote = _FakeAuthRemote(
          profileResult: const Success({
            'username': 'marie',
            'display_name': 'Marie K.',
            'current_streak': 7,
            'subscription_type': 'premium',
          }),
        )..currentUser = _user(metadata: {'username': 'metadata_name'});
        final repository = AuthRepositoryImpl(remote);

        final original = (await repository.reloadProfile()).valueOrNull!;
        expect(original.username, 'marie');
        expect(original.displayName, 'Marie K.');
        expect(original.currentStreak, 7);
        expect(original.subscriptionType, SubscriptionType.premium);

        remote.profileResult = const Failure(NetworkException('offline'));
        expect(
          (await repository.reloadProfile()).exceptionOrNull,
          isA<NetworkException>(),
        );
        expect(repository.currentUser, original);
        expect(remote.profileCreates, isEmpty);
        expect(remote.upserts, isEmpty);

        remote.profileResult = const Success({
          'username': 'marie',
          'display_name': 'Marie K.',
          'current_streak': 8,
          'subscription_type': 'premium',
        });
        expect(
          (await repository.reloadProfile()).valueOrNull?.currentStreak,
          8,
        );
        expect(repository.currentUser?.currentStreak, 8);
      },
    );

    test(
      'sign-in succeeds with the local identity during a profile outage',
      () async {
        final user = _user(metadata: {'username': 'fallback'});
        final remote = _FakeAuthRemote(
          signInResult: Success(user),
          profileResult: const Failure(UnknownException('unavailable')),
        );
        final repository = AuthRepositoryImpl(remote);
        Future<Result<AppUser>> signIn() => repository.signInWithEmail(
          email: 'learner@example.com',
          password: 'secret',
        );

        final offline = (await signIn()).valueOrNull;
        expect(offline?.username, 'fallback');
        expect(repository.currentUser, offline);

        remote.profileResult = const Success({
          'username': 'chosen',
          'current_streak': 9,
        });
        final profile = (await repository.reloadProfile()).valueOrNull;
        remote.profileResult = const Failure(PermissionException());
        expect((await signIn()).valueOrNull, profile);
        expect(repository.currentUser?.username, 'chosen');
        expect(remote.profileCreates, isEmpty);
        expect(remote.upserts, isEmpty);
      },
    );

    test('a failed repair preserves the last enriched profile', () async {
      final remote = _FakeAuthRemote(
        profileResult: const Success({
          'username': 'chosen',
          'current_streak': 9,
        }),
        createResult: const Failure(PermissionException()),
      )..currentUser = _user();
      final repository = AuthRepositoryImpl(remote);
      final profile = (await repository.reloadProfile()).valueOrNull;
      remote.profileResult = const Success(null);

      expect(
        (await repository.reloadProfile()).exceptionOrNull,
        isA<PermissionException>(),
      );
      expect(remote.profileCreates, hasLength(1));
      expect(repository.currentUser, profile);
    });

    test('an account change blocks a pending missing-profile repair', () async {
      final remote = _FakeAuthRemote(
        profileResult: const Success({
          'username': 'chosen',
          'current_streak': 9,
        }),
      )..currentUser = _user(id: 'a');
      final repository = AuthRepositoryImpl(remote);
      await repository.reloadProfile();

      final reply = Completer<Result<Map<String, dynamic>?>>();
      remote.readProfile = (_) => reply.future;
      final operation = repository.reloadProfile();
      remote.currentUser = _user(id: 'b');
      reply.complete(const Success(null));

      expect((await operation).exceptionOrNull, isA<AuthException>());
      expect(remote.profileCreates, isEmpty);
      expect(remote.upserts, isEmpty);
      expect(repository.currentUser?.id, 'b');
      expect(repository.currentUser?.currentStreak, 0);
    });

    test(
      'sign-out invalidates in-flight profiles before signing into the same account',
      () async {
        final user = _user();
        final remote = _FakeAuthRemote()..currentUser = user;
        final repository = AuthRepositoryImpl(remote);
        final reply = Completer<Result<Map<String, dynamic>?>>();
        remote.readProfile = (_) => reply.future;
        final pending = repository.reloadProfile();
        await repository.signOut();
        expect(repository.currentUser, isNull);

        remote.currentUser = user;
        reply.complete(const Success({'username': 'old', 'current_streak': 9}));
        expect((await pending).exceptionOrNull, isA<AuthException>());
        expect(repository.currentUser?.id, 'u1');
        expect(repository.currentUser?.currentStreak, 0);
      },
    );

    test(
      'forwards sign-out, reset and streak actions to the remote boundary',
      () async {
        final remote = _FakeAuthRemote()..currentUser = _user();
        final repository = AuthRepositoryImpl(remote);

        expect(
          (await repository.sendPasswordResetEmail('a@b.com')).isSuccess,
          isTrue,
        );
        final studyDate = DateTime.utc(2026, 11, 26);
        expect(
          (await repository.updateStreak(
            userId: 'u1',
            studyDate: studyDate,
          )).isSuccess,
          isTrue,
        );
        expect((await repository.signOut()).isSuccess, isTrue);
        expect(remote.signOutCalls, 1);
        expect(remote.resetCalls, 1);
        expect(remote.streakUpdates, [('u1', studyDate)]);
      },
    );
  });
}
