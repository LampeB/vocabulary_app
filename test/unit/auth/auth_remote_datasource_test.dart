import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/remote/auth_remote_datasource.dart';

class _AuthStorage extends sb.GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  for (final scenario in [
    ('invalid_credentials', AuthFailureReason.invalidCredentials),
    ('email_exists', AuthFailureReason.emailTaken),
    ('user_already_exists', AuthFailureReason.emailTaken),
    ('email_not_confirmed', AuthFailureReason.emailNotConfirmed),
    ('over_request_rate_limit', AuthFailureReason.rateLimited),
  ]) {
    test(
      'maps Supabase ${scenario.$1} to a locale-independent reason',
      () async {
        final client = sb.SupabaseClient(
          'https://fixture.supabase.co',
          'fixture-anon-key',
          authOptions: sb.AuthClientOptions(pkceAsyncStorage: _AuthStorage()),
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({'code': scenario.$1, 'msg': 'Raw server message'}),
              400,
              request: request,
              headers: {
                'content-type': 'application/json',
                'x-supabase-api-version': '2024-01-01',
              },
            ),
          ),
        );
        addTearDown(client.dispose);
        final remote = AuthRemoteDataSource(client);
        final result = scenario.$2 == AuthFailureReason.emailTaken
            ? await remote.signUpWithEmail(
                'a@example.test',
                'password123',
                'user',
              )
            : await remote.signInWithEmail('a@example.test', 'password123');
        expect(
          result.exceptionOrNull,
          isA<AuthException>(),
          reason: result.exceptionOrNull?.message,
        );
        expect((result.exceptionOrNull as AuthException).reason, scenario.$2);
        expect(result.exceptionOrNull!.message, isNot(contains('Raw server')));
      },
    );
  }

  for (final date in [(2026, 3, 30), (2026, 10, 26)]) {
    test(
      'quiz streak API saves consecutive civil days across Paris DST $date',
      () async {
        final paris = tz.getLocation('Europe/Paris');
        final today = tz.TZDateTime(paris, date.$1, date.$2, date.$3);
        final last = tz.TZDateTime(paris, date.$1, date.$2, date.$3 - 1);
        Map<String, dynamic>? saved;
        final client = sb.SupabaseClient(
          'https://fixture.supabase.co',
          'fixture-anon-key',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/rest/v1/profiles');
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode([
                  {
                    'current_streak': 5,
                    'longest_streak': 5,
                    'last_study_date': last.toIso8601String().substring(0, 10),
                  },
                ]),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            expect(request.method, 'PATCH');
            saved = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('', 204, request: request);
          }),
        );
        addTearDown(client.dispose);
        final result = await AuthRemoteDataSource(
          client,
          now: () => today,
        ).updateStreak('u');
        expect(
          result.isSuccess,
          isTrue,
          reason: result.exceptionOrNull?.message,
        );
        expect(saved!['current_streak'], 6);
        expect(saved!['longest_streak'], 6);
        expect(saved!['updated_at'], today.toUtc().toIso8601String());
        expect(
          saved!['last_study_date'],
          today.toIso8601String().substring(0, 10),
        );
      },
    );
  }
}
