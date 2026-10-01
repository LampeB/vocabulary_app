import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../../patrol_test/helpers/scenario_account.dart';

Map<String, String> account(String id, String email) => {
      'user_id': id,
      'email': email,
      'password': 'fixture-secret',
      'username': 'fixture',
    };

void main() {
  test('each scenario selects its own permanent credentials', () {
    final source = jsonEncode({
      'quiz.correct': account('a', 'a@example.invalid'),
      'quiz.wrong': account('b', 'b@example.invalid'),
    });
    expect(
        accountForScenario('quiz.correct', source).email, 'a@example.invalid');
    expect(accountForScenario('quiz.wrong', source).userId, 'b');
    expect(() => accountForScenario('quiz.missing', source), throwsStateError);
  });
  test('sharing a UUID or normalized email is rejected', () {
    for (final other in [
      account('A', 'b@example.invalid'),
      account('b', ' A@EXAMPLE.INVALID ')
    ]) {
      expect(
          () => parseScenarioAccounts(jsonEncode({
                'quiz.correct': account('a', 'a@example.invalid'),
                'quiz.wrong': other,
              })),
          throwsStateError);
    }
  });
  test('malformed, empty and incomplete maps have no fallback', () {
    for (final source in ['not-json', '[]', '{}', '{"quiz.correct":{}}']) {
      expect(() => parseScenarioAccounts(source), throwsStateError);
    }
  });
  test('parse errors do not expose credentials', () {
    try {
      parseScenarioAccounts('fixture-secret');
      fail('Expected failure');
    } on StateError catch (error) {
      expect(error.toString(), isNot(contains('fixture-secret')));
    }
  });
}
