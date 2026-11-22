import 'dart:convert';

class ScenarioAccount {
  const ScenarioAccount(
      {required this.scenarioId,
      required this.userId,
      required this.email,
      required this.password,
      required this.username});
  final String scenarioId;
  final String userId;
  final String email;
  final String password;
  final String username;
}

/// Validate the whole map before selecting an account. No shared fallback.
Map<String, ScenarioAccount> parseScenarioAccounts(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    throw StateError(
        'TEST_ACCOUNTS_JSON must contain the scenario account map.');
  }
  if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
    throw StateError('Scenario account map is empty or invalid.');
  }
  final result = <String, ScenarioAccount>{};
  final users = <String>{};
  final emails = <String>{};
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value is! Map<String, dynamic> ||
        ['user_id', 'email', 'password', 'username'].any(
            (key) => value[key] is! String || (value[key] as String).isEmpty)) {
      throw StateError('Incomplete account for scenario ${entry.key}.');
    }
    final user = (value['user_id'] as String).toLowerCase();
    final email = (value['email'] as String).trim().toLowerCase();
    if (!users.add(user) || !emails.add(email)) {
      throw StateError('Each E2E scenario must have a distinct account.');
    }
    result[entry.key] = ScenarioAccount(
        scenarioId: entry.key,
        userId: user,
        email: email,
        password: value['password'],
        username: value['username']);
  }
  return result;
}

ScenarioAccount accountForScenario(String scenarioId, String source) {
  final account = parseScenarioAccounts(source)[scenarioId];
  if (account == null) {
    throw StateError('No account configured for $scenarioId.');
  }
  return account;
}
