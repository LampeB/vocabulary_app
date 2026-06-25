import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/repositories/auth_repository.dart';
import 'package:vocab_kr/domain/usecases/auth/sign_up_usecase.dart';

// ---------------------------------------------------------------------------
// Minimal fake — captures the username that was actually passed to signUp.
// ---------------------------------------------------------------------------
class _FakeAuthRepo implements AuthRepository {
  String? capturedUsername;

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    capturedUsername = username;
    return Success(AppUser(
      id: 'uid-1',
      email: email,
      username: username,
      createdAt: DateTime(2025),
    ));
  }

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
  late _FakeAuthRepo fakeRepo;
  late SignUpUseCase useCase;

  setUp(() {
    fakeRepo = _FakeAuthRepo();
    useCase = SignUpUseCase(fakeRepo);
  });

  group('username validation — failures (repo never called)', () {
    Future<void> expectValidationFailure(String username) async {
      final result = await useCase.call(
        email: 'a@b.com',
        password: 'pass',
        username: username,
      );
      expect(result, isA<Failure>(),
          reason: 'Expected Failure for username: "$username"');
      expect((result as Failure).exception, isA<ValidationException>());
      expect(fakeRepo.capturedUsername, isNull,
          reason: 'Repo must not be called for invalid username');
    }

    test('empty string is rejected', () => expectValidationFailure(''));
    test('2-char username is rejected', () => expectValidationFailure('ab'));
    test('whitespace-only is rejected', () => expectValidationFailure('   '));
    test('username with hyphen is rejected', () => expectValidationFailure('user-name'));
    test('username with at-sign is rejected', () => expectValidationFailure('user@name'));
    test('username with space inside is rejected', () => expectValidationFailure('user name'));
    test('username with accent is rejected', () => expectValidationFailure('héros'));
  });

  group('username validation — success (delegates to repo)', () {
    test('exactly 3 characters passes', () async {
      final result = await useCase.call(
          email: 'a@b.com', password: 'pass', username: 'abc');
      expect(result.isSuccess, isTrue);
    });

    test('alphanumeric + underscores passes', () async {
      final result = await useCase.call(
          email: 'a@b.com', password: 'pass', username: 'user_name_123');
      expect(result.isSuccess, isTrue);
    });
  });

  group('username normalisation', () {
    test('uppercased username is lowercased before sending to repo', () async {
      await useCase.call(
          email: 'a@b.com', password: 'pass', username: 'Alice');
      expect(fakeRepo.capturedUsername, 'alice');
    });

    test('mixed-case username is fully lowercased', () async {
      await useCase.call(
          email: 'a@b.com', password: 'pass', username: 'Bob_123');
      expect(fakeRepo.capturedUsername, 'bob_123');
    });
  });
}
