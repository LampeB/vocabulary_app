import 'dart:async' show unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/datasources/remote/auth_remote_datasource.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../core/errors/failure.dart';
import '../../../services/purchases/purchase_service.dart';

// Test builds deliberately skip the RevenueCat bootstrap. Auth must skip its
// companion login/logout calls too, otherwise native purchase calls race the
// E2E runner with an unconfigured SDK.
const _kTestMode = bool.fromEnvironment('TEST_MODE');

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AppUser?> {
  late AuthRepository _repo;
  int _revision = 0;
  bool _active = false;

  bool _isCurrent(int revision, AuthRepository repo, String? userId) =>
      _active &&
      revision == _revision &&
      identical(repo, _repo) &&
      repo.currentUser?.id == userId;

  Stream<AppUser?> get stream => _repo.authStateChanges;

  @override
  Future<AppUser?> build() async {
    final repo = _repo = ref.watch(authRepositoryProvider);
    _active = true;
    final revision = ++_revision;
    // Always reload the full profile on every auth state change so that
    // the basic _mapUser (auth-only) never overwrites _mapUserWithProfile.
    final subscription = repo.authStateChanges.listen((user) async {
      if (!_active ||
          !identical(repo, _repo) ||
          repo.currentUser?.id != user?.id) {
        return;
      }
      final eventRevision = ++_revision;
      if (user == null) {
        state = const AsyncData(null);
        if (!_kTestMode) unawaited(PurchaseService.instance.logOut());
        return;
      }
      // Isolate local reads as soon as the session changes, even if fetching
      // the new account's profile is slow. Keep an enriched same-user profile.
      if (state.valueOrNull?.id != user.id) state = AsyncData(user);
      final result = await repo.reloadProfile();
      if (!_isCurrent(eventRevision, repo, user.id)) return;
      final profile = result.valueOrNull;
      state = AsyncData(profile?.id == user.id ? profile : user);
      if (!_kTestMode) unawaited(PurchaseService.instance.logIn(user.id));
    });
    ref.onDispose(() {
      unawaited(subscription.cancel());
      if (identical(repo, _repo)) {
        _active = false;
        ++_revision;
      }
    });
    final user = repo.currentUser;
    if (user == null) return null;
    final result = await repo.reloadProfile();
    if (!_isCurrent(revision, repo, user.id)) {
      // Riverpod also consumes build's returned future. Never return the old
      // identity after an intervening event/method already changed the state.
      if (!_active || !identical(repo, _repo)) return null;
      final current = repo.currentUser;
      final shown = state.valueOrNull;
      return shown?.id == current?.id ? shown : null;
    }
    if (!_kTestMode) unawaited(PurchaseService.instance.logIn(user.id));
    final profile = result.valueOrNull;
    return profile?.id == user.id ? profile : user;
  }

  Future<Result<AppUser>> signIn(String email, String password) async {
    final repo = _repo;
    final revision = ++_revision;
    state = const AsyncLoading();
    final result = await repo.signInWithEmail(email: email, password: password);
    if (!_active || revision != _revision || !identical(repo, _repo)) {
      return result;
    }
    result.fold(
      onSuccess: (user) {
        if (!_isCurrent(revision, repo, user.id)) return;
        state = AsyncData(user);
        if (!_kTestMode) unawaited(PurchaseService.instance.logIn(user.id));
      },
      onFailure: (e) => state = AsyncError(e, StackTrace.current),
    );
    return result;
  }

  Future<Result<AppUser>> signUp(
    String email,
    String password,
    String username,
  ) async {
    final repo = _repo;
    final revision = ++_revision;
    state = const AsyncLoading();
    final result = await repo.signUpWithEmail(
      email: email,
      password: password,
      username: username,
    );
    if (!_active || revision != _revision || !identical(repo, _repo)) {
      return result;
    }
    result.fold(
      onSuccess: (user) {
        if (!_isCurrent(revision, repo, user.id)) return;
        state = AsyncData(user);
        if (!_kTestMode) unawaited(PurchaseService.instance.logIn(user.id));
      },
      onFailure: (e) => state = AsyncError(e, StackTrace.current),
    );
    return result;
  }

  Future<void> signOut() async {
    final repo = _repo;
    final revision = ++_revision;
    state = const AsyncData(null);
    await repo.signOut();
    if (_isCurrent(revision, repo, null) && !_kTestMode) {
      unawaited(PurchaseService.instance.logOut());
    }
  }

  Future<void> reloadProfile() async {
    final repo = _repo;
    final userId = repo.currentUser?.id;
    final revision = ++_revision;
    if (userId == null) return;
    final result = await repo.reloadProfile();
    if (!_isCurrent(revision, repo, userId)) return;
    result.fold(
      onSuccess: (user) {
        if (user.id == userId) state = AsyncData(user);
      },
      onFailure: (_) {},
    );
  }

  /// A slow profile request must not hide an already restored local session.
  /// The pending request may still enrich this identity when it completes.
  AppUser? useLocalSession() {
    final user = ref.read(authRepositoryProvider).currentUser;
    state = AsyncData(user);
    return user;
  }

  Future<Result<void>> sendPasswordReset(String email) =>
      _repo.sendPasswordResetEmail(email);
}

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});
