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

  @override
  Stream<AppUser?> get authStateChanges => authChanges.stream;

  @override
  AppUser? get currentUser => current;

  @override
  Future<Result<AppUser>> reloadProfile() async => profile != null
      ? Success(profile!)
      : const Failure(NetworkException('no profile'));

  @override
  Future<Result<AppUser>> signInWithEmail(
      {required String email, required String password}) async {
    if (failSignIn) return const Failure(AuthException('bad credentials'));
    current = _user();
    return Success(current!);
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
    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ]);
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

  test('signIn success → AsyncData(user) and currentUserProvider set',
      () async {
    await container.read(authStateProvider.future);

    final result = await container
        .read(authStateProvider.notifier)
        .signIn('t@t.fr', 'secret');

    expect(result.isSuccess, isTrue);
    expect(container.read(authStateProvider).valueOrNull?.id, 'u');
    expect(container.read(currentUserProvider)?.id, 'u');
  });

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

  test('reloadProfile updates the state on success and keeps it on failure',
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
  });

  test('an auth-state event with null signs the user out reactively',
      () async {
    repo.current = _user();
    repo.profile = _user();
    await container.read(authStateProvider.future);

    repo.authChanges.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(authStateProvider).valueOrNull, isNull);
  });
}
