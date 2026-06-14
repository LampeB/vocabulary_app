import '../../repositories/auth_repository.dart';
import '../../../core/errors/failure.dart';

class SignOutUseCase {
  const SignOutUseCase(this._repo);
  final AuthRepository _repo;

  Future<Result<void>> call() => _repo.signOut();
}
