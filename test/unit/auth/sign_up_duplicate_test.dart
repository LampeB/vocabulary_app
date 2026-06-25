import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/usecases/auth/sign_up_usecase.dart';

// ---------------------------------------------------------------------------
// Fake repo that always returns a pre-configured failure from signUpWithEmail.
// ---------------------------------------------------------------------------
class _FailingAuthRepo implements AuthRepository {
  _FailingAuthRepo(this._failure);
  final AppException _failure;

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async =>
      Failure(_failure);

  // ── unused stubs ──────────────────────────────────────────────────────────
  @override Stream<AppUser?> get authStateChanges => const Stream.empty();
  @override AppUser? get currentUser => null;
  @override Future<Result<AppUser>> signInWithEmail({required String email, required String password}) async => throw UnimplementedError();
  @override Future<Result<AppUser>> signInWithGoogle() async => throw UnimplementedError();
  @override Future<Result<AppUser>> signInWithApple() async => throw UnimplementedError();
  @override Future<Result<void>> signOut() async => throw UnimplementedError();
  @override Future<Result<void>> sendPasswordResetEmail(String email) async => throw UnimplementedError();
  @override Future<Result<AppUser>> updateProfile({String? displayName, String? avatarUrl, String? bio}) async => throw UnimplementedError();
  @override Future<Result<AppUser>> reloadProfile() async => throw UnimplementedError();
  @override Future<Result<void>> updateStreak() async => throw UnimplementedError();
  @override Future<Result<void>> deleteAccount() async => throw UnimplementedError();
}

void main() {
  group('duplicate username', () {
    late SignUpUseCase useCase;

    setUp(() {
      useCase = SignUpUseCase(_FailingAuthRepo(
        const ValidationException('Ce pseudo est déjà utilisé.'),
      ));
    });

    test('returns ValidationException with correct French message', () async {
      final result = await useCase.call(
        email: 'new@example.com',
        password: 'password123',
        username: 'takenuser',
      );

      expect(result, isA<Failure>());
      final exception = (result as Failure).exception;
      expect(exception, isA<ValidationException>());
      expect(exception.message, 'Ce pseudo est déjà utilisé.');
    });

    test('does not succeed', () async {
      final result = await useCase.call(
        email: 'new@example.com',
        password: 'password123',
        username: 'takenuser',
      );
      expect(result.isSuccess, isFalse);
    });
  });

  group('duplicate email', () {
    late SignUpUseCase useCase;

    setUp(() {
      useCase = SignUpUseCase(_FailingAuthRepo(
        const AuthException('Cette adresse e-mail est déjà utilisée.'),
      ));
    });

    test('returns AuthException with correct French message', () async {
      final result = await useCase.call(
        email: 'taken@example.com',
        password: 'password123',
        username: 'newuser',
      );

      expect(result, isA<Failure>());
      final exception = (result as Failure).exception;
      expect(exception, isA<AuthException>());
      expect(exception.message, 'Cette adresse e-mail est déjà utilisée.');
    });

    test('does not succeed', () async {
      final result = await useCase.call(
        email: 'taken@example.com',
        password: 'password123',
        username: 'newuser',
      );
      expect(result.isSuccess, isFalse);
    });
  });
}
