import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:vocab_kr/core/errors/app_exception.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/core/utils/streak.dart';
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

Future<void> _setIdentity(sb.SupabaseClient client, String id) =>
    client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'fixture-token-for-$id',
        'token_type': 'bearer',
        'user': {
          'id': id,
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00.000Z',
        },
      }),
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  for (final offline in [false, true]) {
    test(
      'reset preserves ${offline ? 'network' : 'HTTP 429'} reason',
      () async {
        final client = sb.SupabaseClient(
          'https://fixture.supabase.co',
          'fixture-anon-key',
          authOptions: sb.AuthClientOptions(pkceAsyncStorage: _AuthStorage()),
          httpClient: MockClient((request) async {
            if (offline) throw http.ClientException('offline');
            return http.Response(
              jsonEncode({'msg': 'Too many requests'}),
              429,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final result = await AuthRemoteDataSource(
          client,
        ).sendPasswordReset('a@example.test');
        if (offline) {
          expect(result.exceptionOrNull, isA<NetworkException>());
        } else {
          expect(
            (result.exceptionOrNull as AuthException).reason,
            AuthFailureReason.rateLimited,
          );
        }
      },
    );
  }

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
        await _setIdentity(client, 'u');
        final result = await AuthRemoteDataSource(
          client,
          now: () => today,
        ).updateStreak(userId: 'u', studyDate: civilDate(today));
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

  for (final (label, lastStudyDate, switchAccount) in [
    ('keeps the completion day across midnight', '2026-11-26', false),
    ('preserves a newer study day', '2026-11-28', false),
    ('stops after an account switch', '2026-11-26', true),
  ]) {
    test('delayed streak profile GET $label', () async {
      final paris = tz.getLocation('Europe/Paris');
      var now = tz.TZDateTime(paris, 2026, 11, 27, 23, 59);
      final requested = Completer<void>();
      final release = Completer<void>();
      Map<String, dynamic>? saved;
      final client = sb.SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-anon-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/profiles');
          expect(request.url.queryParameters['id'], 'eq.u');
          expect(
            request.headers['authorization'],
            'Bearer fixture-token-for-u',
          );
          if (request.method == 'GET') {
            requested.complete();
            await release.future;
            return http.Response(
              jsonEncode([
                {
                  'current_streak': 5,
                  'longest_streak': 8,
                  'last_study_date': lastStudyDate,
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          expect(request.method, 'PATCH');
          expect(
            request.url.queryParameters['or'],
            '(last_study_date.is.null,last_study_date.lt.2026-11-27)',
          );
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 204, request: request);
        }),
      );
      addTearDown(client.dispose);
      await _setIdentity(client, 'u');
      final result = AuthRemoteDataSource(
        client,
        now: () => now,
      ).updateStreak(userId: 'u', studyDate: civilDate(now));

      await requested.future.timeout(const Duration(seconds: 2));
      now = tz.TZDateTime(paris, 2026, 11, 28, 0, 1);
      if (switchAccount) await _setIdentity(client, 'other');
      release.complete();
      expect((await result).isFailure, switchAccount);
      if (switchAccount || lastStudyDate == '2026-11-28') {
        expect(saved, isNull);
      } else {
        expect(saved, {
          'current_streak': 6,
          'longest_streak': 8,
          'last_study_date': '2026-11-27',
          'updated_at': now.toUtc().toIso8601String(),
        });
      }
    });
  }
}
