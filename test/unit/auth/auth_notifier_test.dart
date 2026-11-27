import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';

/// The REAL AuthNotifier over a scripted AuthRepository: build restore,
/// sign-in success/failure state transitions, sign-out, profile reload, and
/// the currentUserProvider derivation. (PurchaseService calls inside are
/// try/caught, so the missing native plugin is harmless here.)

AppUser _user({String id = 'u', int streak = 0}) => AppUser(
  id: id,
  email: 't@t.fr',
  username: 'thomas',
  currentStreak: streak,
  subscriptionType: SubscriptionType.free,
  createdAt: DateTime(2026),
);

class _FakeAuthRepo implements AuthRepository {
  AppUser? current;
  AppUser? profile;
  bool failSignIn = false;
  bool signedOut = false;
  final authChanges = StreamController<AppUser?>.broadcast();
  Future<Result<AppUser>> Function()? loadProfile;
  Future<Result<AppUser>>? authenticationResult;

  @override
  Stream<AppUser?> get authStateChanges => authChanges.stream;

  @override
  AppUser? get currentUser => current;

  @override
  Future<Result<AppUser>> reloadProfile() async => loadProfile != null
      ? loadProfile!()
      : profile != null
      ? Success(profile!)
      : const Failure(NetworkException('no profile'));

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (failSignIn) return const Failure(AuthException('bad credentials'));
    current = _user();
    return authenticationResult ?? Success(current!);
  }

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    current = _user();
    return authenticationResult ?? Success(current!);
  }

  @override
  Future<Result<void>> signOut() async {
    signedOut = true;
    current = null;
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuthRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeAuthRepo();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    addTearDown(repo.authChanges.close);
  });

  test('build with no session → null user', () async {
    final user = await container.read(authStateProvider.future);
    expect(user, isNull);
    expect(container.read(currentUserProvider), isNull);
  });

  test('build with a session restores the full profile', () async {
    repo.current = _user();
    repo.profile = _user(streak: 7);

    final user = await container.read(authStateProvider.future);

    expect(user!.currentStreak, 7); // profile version, not the basic user
  });

  test(
    'signIn success → AsyncData(user) and currentUserProvider set',
    () async {
      await container.read(authStateProvider.future);

      final result = await container
          .read(authStateProvider.notifier)
          .signIn('t@t.fr', 'secret');

      expect(result.isSuccess, isTrue);
      expect(container.read(authStateProvider).valueOrNull?.id, 'u');
      expect(container.read(currentUserProvider)?.id, 'u');
    },
  );

  test('signIn failure → AsyncError and no current user', () async {
    await container.read(authStateProvider.future);
    repo.failSignIn = true;

    final result = await container
        .read(authStateProvider.notifier)
        .signIn('t@t.fr', 'nope');

    expect(result.isFailure, isTrue);
    expect(container.read(authStateProvider).hasError, isTrue);
    expect(container.read(currentUserProvider), isNull);
  });

  test('signOut clears the state and hits the repository', () async {
    repo.current = _user();
    repo.profile = _user();
    await container.read(authStateProvider.future);

    await container.read(authStateProvider.notifier).signOut();

    expect(repo.signedOut, isTrue);
    expect(container.read(authStateProvider).valueOrNull, isNull);
  });

  test(
    'reloadProfile updates the state on success and keeps it on failure',
    () async {
      repo.current = _user();
      repo.profile = _user(streak: 3);
      await container.read(authStateProvider.future);

      repo.profile = _user(streak: 9);
      await container.read(authStateProvider.notifier).reloadProfile();
      expect(container.read(authStateProvider).valueOrNull?.currentStreak, 9);

      repo.profile = null; // reload now fails → state unchanged
      await container.read(authStateProvider.notifier).reloadProfile();
      expect(container.read(authStateProvider).valueOrNull?.currentStreak, 9);
    },
  );

  test('an auth-state event with null signs the user out reactively', () async {
    repo.current = _user();
    repo.profile = _user();
    await container.read(authStateProvider.future);

    repo.current = null;
    repo.authChanges.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(authStateProvider).valueOrNull, isNull);
  });

  test(
    'late initial profile A cannot restore A after local fallback and B',
    () async {
      final pendingA = Completer<Result<AppUser>>();
      repo.current = _user(id: 'a');
      repo.loadProfile = () => pendingA.future;
      container.read(authStateProvider);
      final notifier = container.read(authStateProvider.notifier);
      expect(notifier.useLocalSession()?.id, 'a');
      await notifier.signOut();
      repo.current = _user(id: 'b');
      repo.loadProfile = () async => Success(_user(id: 'b', streak: 8));
      repo.authChanges.add(repo.current);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentUserProvider)?.id, 'b');
      pendingA.complete(Success(_user(id: 'a', streak: 99)));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentUserProvider)?.id, 'b');
      expect(container.read(currentUserProvider)?.currentStreak, 8);
    },
  );

  test(
    'late event and explicit profile loads cannot overwrite a new session',
    () async {
      repo.current = _user(id: 'a');
      repo.profile = repo.current;
      await container.read(authStateProvider.future);
      final pendingA = Completer<Result<AppUser>>();
      repo.loadProfile = () => pendingA.future;
      repo.authChanges.add(repo.current);
      await Future<void>.delayed(Duration.zero);
      final refresh = container
          .read(authStateProvider.notifier)
          .reloadProfile();
      await container.read(authStateProvider.notifier).signOut();
      repo.current = _user(id: 'b');
      repo.loadProfile = () async => Success(_user(id: 'b'));
      repo.authChanges.add(repo.current);
      await Future<void>.delayed(Duration.zero);
      pendingA.complete(Success(_user(id: 'a')));
      await refresh;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentUserProvider)?.id, 'b');
    },
  );

  test(
    'a new session replaces the old identity before its profile completes',
    () async {
      repo.current = _user(id: 'a');
      repo.profile = repo.current;
      await container.read(authStateProvider.future);
      final pendingB = Completer<Result<AppUser>>();
      repo.current = _user(id: 'b');
      repo.loadProfile = () => pendingB.future;
      repo.authChanges.add(repo.current);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentUserProvider)?.id, 'b');
      pendingB.complete(Success(_user(id: 'b', streak: 5)));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentUserProvider)?.currentStreak, 5);
    },
  );

  for (final registration in [false, true]) {
    test(
      'late authentication profile cannot replace B (signup=$registration)',
      () async {
        await container.read(authStateProvider.future);
        final pendingA = Completer<Result<AppUser>>();
        repo.authenticationResult = pendingA.future;
        final notifier = container.read(authStateProvider.notifier);
        final operation = registration
            ? notifier.signUp('a@example.test', 'secret', 'a')
            : notifier.signIn('a@example.test', 'secret');
        repo.current = _user(id: 'b');
        repo.profile = repo.current;
        repo.authChanges.add(repo.current);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(currentUserProvider)?.id, 'b');
        pendingA.complete(Success(_user()));
        await operation;
        expect(container.read(currentUserProvider)?.id, 'b');
      },
    );
  }

  test(
    'disposing cancels the auth subscription and ignores pending profiles',
    () async {
      repo.current = _user(id: 'a');
      final pending = Completer<Result<AppUser>>();
      repo.loadProfile = () => pending.future;
      final isolated = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      isolated.read(authStateProvider);
      expect(repo.authChanges.hasListener, isTrue);
      isolated.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(repo.authChanges.hasListener, isFalse);
      pending.complete(Success(_user(id: 'a')));
      await Future<void>.delayed(Duration.zero);
    },
  );
}
