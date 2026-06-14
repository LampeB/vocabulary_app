import '../../repositories/auth_repository.dart';
import '../../entities/app_user.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/app_exception.dart';

class SignUpUseCase {
  const SignUpUseCase(this._repo);
  final AuthRepository _repo;

  Future<Result<AppUser>> call({
    required String email,
    required String password,
    required String username,
  }) {
    if (username.trim().length < 3) {
      return Future.value(
        Failure(const ValidationException('Username must be at least 3 characters')),
      );
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return Future.value(
        Failure(const ValidationException('Username can only contain letters, numbers and underscores')),
      );
    }
    return _repo.signUpWithEmail(
      email: email,
      password: password,
      username: username.trim().toLowerCase(),
    );
  }
}
