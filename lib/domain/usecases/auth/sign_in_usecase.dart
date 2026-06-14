import '../../repositories/auth_repository.dart';
import '../../entities/app_user.dart';
import '../../../core/errors/failure.dart';

class SignInUseCase {
  const SignInUseCase(this._repo);
  final AuthRepository _repo;

  Future<Result<AppUser>> call({
    required String email,
    required String password,
  }) =>
      _repo.signInWithEmail(email: email, password: password);
}
