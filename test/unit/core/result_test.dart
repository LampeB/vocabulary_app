import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/errors/app_exception.dart';

void main() {
  const exception = ValidationException('bad input');

  group('isSuccess / isFailure', () {
    test('Success.isSuccess is true', () {
      expect(const Success(42).isSuccess, isTrue);
    });

    test('Success.isFailure is false', () {
      expect(const Success(42).isFailure, isFalse);
    });

    test('Failure.isSuccess is false', () {
      expect(const Failure<int>(exception).isSuccess, isFalse);
    });

    test('Failure.isFailure is true', () {
      expect(const Failure<int>(exception).isFailure, isTrue);
    });

    test('isSuccess and isFailure are always complementary', () {
      final results = <Result<int>>[
        const Success(1),
        const Failure(exception),
      ];
      for (final r in results) {
        expect(r.isSuccess, equals(!r.isFailure));
      }
    });
  });

  group('valueOrNull', () {
    test('Success returns the value', () {
      expect(const Success('hello').valueOrNull, 'hello');
    });

    test('Failure returns null', () {
      expect(const Failure<String>(exception).valueOrNull, isNull);
    });

    test('Success with null value returns null', () {
      expect(const Success<String?>(null).valueOrNull, isNull);
    });
  });

  group('exceptionOrNull', () {
    test('Success returns null', () {
      expect(const Success(1).exceptionOrNull, isNull);
    });

    test('Failure returns the exception instance', () {
      final result = const Failure<int>(exception);
      expect(result.exceptionOrNull, same(exception));
    });
  });

  group('fold', () {
    test('Success calls onSuccess with the value', () {
      final result = const Success(10).fold(
        onSuccess: (v) => 'got $v',
        onFailure: (_) => 'fail',
      );
      expect(result, 'got 10');
    });

    test('Failure calls onFailure with the exception', () {
      final result = const Failure<int>(exception).fold(
        onSuccess: (_) => 'ok',
        onFailure: (e) => 'error: ${e.message}',
      );
      expect(result, 'error: bad input');
    });

    test('Success never calls onFailure', () {
      var failureCalled = false;
      const Success(1).fold(
        onSuccess: (_) {},
        onFailure: (_) => failureCalled = true,
      );
      expect(failureCalled, isFalse);
    });

    test('Failure never calls onSuccess', () {
      var successCalled = false;
      const Failure<int>(exception).fold(
        onSuccess: (_) => successCalled = true,
        onFailure: (_) {},
      );
      expect(successCalled, isFalse);
    });

    test('return value is threaded correctly from the callback', () {
      final value = const Success(5).fold(
        onSuccess: (v) => v * 2,
        onFailure: (_) => -1,
      );
      expect(value, 10);
    });
  });
}
