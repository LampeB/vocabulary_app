import 'dart:async' show unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/datasources/remote/auth_remote_datasource.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../core/errors/failure.dart';
import '../../../services/purchases/purchase_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AppUser?> {
  late AuthRepository _repo;

  Stream<AppUser?> get stream => _repo.authStateChanges;

  @override
  Future<AppUser?> build() async {
    _repo = ref.watch(authRepositoryProvider);
    listenSelf((_, __) {});
    // Always reload the full profile on every auth state change so that
    // the basic _mapUser (auth-only) never overwrites _mapUserWithProfile.
    _repo.authStateChanges.listen((user) async {
      if (user == null) {
        state = const AsyncData(null);
        return;
      }
      unawaited(PurchaseService.instance.logIn(user.id));
      final result = await _repo.reloadProfile();
      state = AsyncData(result.valueOrNull ?? user);
    });
    final user = _repo.currentUser;
    if (user == null) return null;
    unawaited(PurchaseService.instance.logIn(user.id));
    final result = await _repo.reloadProfile();
    return result.valueOrNull ?? user;
  }

  Future<Result<AppUser>> signIn(String email, String password) async {
    state = const AsyncLoading();
    final result =
        await _repo.signInWithEmail(email: email, password: password);
    result.fold(
      onSuccess: (user) {
        state = AsyncData(user);
        unawaited(PurchaseService.instance.logIn(user.id));
      },
      onFailure: (e) => state = AsyncError(e, StackTrace.current),
    );
    return result;
  }

  Future<Result<AppUser>> signUp(
      String email, String password, String username) async {
    state = const AsyncLoading();
    final result = await _repo.signUpWithEmail(
        email: email, password: password, username: username);
    result.fold(
      onSuccess: (user) {
        state = AsyncData(user);
        unawaited(PurchaseService.instance.logIn(user.id));
      },
      onFailure: (e) => state = AsyncError(e, StackTrace.current),
    );
    return result;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    unawaited(PurchaseService.instance.logOut());
    state = const AsyncData(null);
  }

  Future<void> reloadProfile() async {
    final result = await _repo.reloadProfile();
    result.fold(
      onSuccess: (user) => state = AsyncData(user),
      onFailure: (_) {},
    );
  }

  Future<Result<void>> sendPasswordReset(String email) =>
      _repo.sendPasswordResetEmail(email);
}

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});
