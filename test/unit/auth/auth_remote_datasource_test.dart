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
import 'package:vocab_kr/data/datasources/remote/auth_remote_datasource.dart';
import 'package:vocab_kr/data/repositories/auth_repository_impl.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';

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

  for (final (status, body, exception) in [
    (200, '[]', null),
    (
      403,
      '{"code":"42501","message":"Permission denied"}',
      isA<PermissionException>(),
    ),
    (
      500,
      '{"code":"XX000","message":"Database unavailable"}',
      isA<UnknownException>(),
    ),
    (
      406,
      '{"code":"PGRST116","details":"The result contains 0 rows","message":"Unexpected error"}',
      isA<UnknownException>(),
    ),
  ]) {
    test(
      'profile read distinguishes HTTP $status from an empty result',
      () async {
        final client = sb.SupabaseClient(
          'https://fixture.supabase.co',
          'fixture-anon-key',
          httpClient: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/rest/v1/profiles');
            expect(request.url.queryParameters['id'], 'eq.u');
            return http.Response(
              body,
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        await _setIdentity(client, 'u');

        final result = await AuthRemoteDataSource(client).getProfile('u');

        if (exception == null) {
          expect(result.isSuccess, isTrue);
          expect(result.valueOrNull, isNull);
        } else {
          expect(result.exceptionOrNull, exception);
        }
      },
    );
  }

  test('profile transport errors never attempt a repair', () async {
    final client = sb.SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-anon-key',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        throw http.ClientException('offline');
      }),
    );
    addTearDown(client.dispose);
    await _setIdentity(client, 'u');

    final repository = AuthRepositoryImpl(AuthRemoteDataSource(client));
    final result = await repository.reloadProfile();
    expect(result.exceptionOrNull, isA<NetworkException>());
  });

  test(
    'missing-profile repair reads a concurrent winner without merging',
    () async {
      final requests = <String>[];
      final client = sb.SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-anon-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/profiles');
          requests.add(request.method);
          if (request.method == 'GET') {
            expect(request.url.queryParameters['id'], 'eq.u');
            return http.Response(
              requests.length == 1
                  ? '[]'
                  : jsonEncode([
                      {
                        'id': 'u',
                        'username': 'learner_choice',
                        'display_name': 'Chosen display name',
                        'current_streak': 19,
                        'subscription_type': 'premium',
                      },
                    ]),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }

          expect(request.method, 'POST');
          expect(request.url.queryParameters['on_conflict'], 'id');
          expect(
            request.headers['prefer'],
            contains('resolution=ignore-duplicates'),
          );
          expect(request.headers['prefer'], contains('return=representation'));
          expect(jsonDecode(request.body), {
            'id': 'u',
            'username': 'user',
            'display_name': 'user',
          });
          // PostgREST returns no inserted row when ON CONFLICT skips the write.
          return http.Response(
            '[]',
            201,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await _setIdentity(client, 'u');

      final repository = AuthRepositoryImpl(AuthRemoteDataSource(client));
      final profile = (await repository.reloadProfile()).valueOrNull!;
      expect(requests, ['GET', 'POST', 'GET']);
      expect(profile.username, 'learner_choice');
      expect(profile.displayName, 'Chosen display name');
      expect(profile.currentStreak, 19);
      expect(profile.subscriptionType, SubscriptionType.premium);
    },
  );

  test('a unique username conflict remains a failed repair', () async {
    final requests = <String>[];
    final client = sb.SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request.method);
        final read = request.method == 'GET';
        return http.Response(
          read ? '[]' : '{"code":"23505","message":"username already exists"}',
          read ? 200 : 409,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await _setIdentity(client, 'u');

    final repository = AuthRepositoryImpl(AuthRemoteDataSource(client));
    final result = await repository.reloadProfile();
    expect(result.exceptionOrNull, isA<UnknownException>());
    expect(requests, ['GET', 'POST']);
  });

  for (final reverse in [false, true]) {
    test(
      'study RPC keeps both dates when replies arrive ${reverse ? "newest" : "oldest"} first',
      () async {
        final requests = <String, Map<String, dynamic>>{};
        final arrived = Completer<void>();
        final releases = {
          '2026-11-25': Completer<void>(),
          '2026-11-26': Completer<void>(),
        };
        final completed = <String>[];
        final client = sb.SupabaseClient(
          'https://fixture.supabase.co',
          'fixture-anon-key',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/rest/v1/rpc/record_study_day');
            expect(request.method, 'POST');
            expect(
              request.headers['authorization'],
              'Bearer fixture-token-for-u',
            );
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final day = body['p_study_date'] as String;
            expect(body['p_user_id'], 'u');
            requests[day] = body;
            if (requests.length == 2) arrived.complete();
            await releases[day]!.future;
            completed.add(day);
            return http.Response('', 204, request: request);
          }),
        );
        addTearDown(client.dispose);
        await _setIdentity(client, 'u');
        final remote = AuthRemoteDataSource(client);
        final earlier = remote.updateStreak(
          userId: 'u',
          studyDate: DateTime.utc(2026, 11, 25),
        );
        final later = remote.updateStreak(
          userId: 'u',
          studyDate: DateTime.utc(2026, 11, 26),
        );
        await arrived.future.timeout(const Duration(seconds: 2));
        final first = reverse ? '2026-11-26' : '2026-11-25';
        final second = reverse ? '2026-11-25' : '2026-11-26';
        releases[first]!.complete();
        expect((await (reverse ? later : earlier)).isSuccess, isTrue);
        releases[second]!.complete();
        expect((await (reverse ? earlier : later)).isSuccess, isTrue);
        expect(completed, [first, second]);
        // SQL tests exercise the actual transactional aggregation in both orders.
        expect(requests.keys, unorderedEquals(releases.keys));
      },
    );
  }

  test('repeating a study day sends the same idempotency identity', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = sb.SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-anon-key',
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    await _setIdentity(client, 'u');
    final remote = AuthRemoteDataSource(client);
    for (var i = 0; i < 2; i++) {
      expect(
        (await remote.updateStreak(
          userId: 'u',
          studyDate: DateTime.utc(2026, 11, 25),
        )).isSuccess,
        isTrue,
      );
    }
    expect(bodies, [
      {'p_user_id': 'u', 'p_study_date': '2026-11-25'},
      {'p_user_id': 'u', 'p_study_date': '2026-11-25'},
    ]);
  });

  test('an inactive account does not send a study request', () async {
    var calls = 0;
    final client = sb.SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-anon-key',
      httpClient: MockClient((request) async {
        calls++;
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    await _setIdentity(client, 'other');
    expect(
      (await AuthRemoteDataSource(client).updateStreak(
        userId: 'u',
        studyDate: DateTime.utc(2026, 11, 25),
      )).isFailure,
      isTrue,
    );
    expect(calls, 0);
  });

  test('a refused server study request remains a failure', () async {
    final client = sb.SupabaseClient(
      'https://fixture.supabase.co',
      'fixture-anon-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'Study account mismatch'}),
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(client.dispose);
    await _setIdentity(client, 'u');
    expect(
      (await AuthRemoteDataSource(client).updateStreak(
        userId: 'u',
        studyDate: DateTime.utc(2026, 11, 25),
      )).isFailure,
      isTrue,
    );
  });

  for (final date in [(2026, 3, 30), (2026, 10, 26)]) {
    test('study RPC preserves the Paris civil date across DST $date', () async {
      final day = tz.TZDateTime(
        tz.getLocation('Europe/Paris'),
        date.$1,
        date.$2,
        date.$3,
      );
      Map<String, dynamic>? body;
      final client = sb.SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-anon-key',
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 204, request: request);
        }),
      );
      addTearDown(client.dispose);
      await _setIdentity(client, 'u');
      expect(
        (await AuthRemoteDataSource(
          client,
        ).updateStreak(userId: 'u', studyDate: day)).isSuccess,
        isTrue,
      );
      expect(body, {
        'p_user_id': 'u',
        'p_study_date': day.toIso8601String().substring(0, 10),
      });
    });
  }

  for (final switchAccount in [false, true]) {
    test(
      'pending study keeps completion identity across midnight, switch=$switchAccount',
      () async {
        final sent = Completer<void>();
        final release = Completer<void>();
        Map<String, dynamic>? body;
        final client = sb.SupabaseClient(
          'https://fixture.supabase.co',
          'fixture-anon-key',
          httpClient: MockClient((request) async {
            expect(
              request.headers['authorization'],
              'Bearer fixture-token-for-u',
            );
            body = jsonDecode(request.body) as Map<String, dynamic>;
            sent.complete();
            await release.future;
            return http.Response('', 204, request: request);
          }),
        );
        addTearDown(client.dispose);
        await _setIdentity(client, 'u');
        final completed = tz.TZDateTime(
          tz.getLocation('Europe/Paris'),
          2026,
          11,
          27,
          23,
          59,
        );
        final result = AuthRemoteDataSource(
          client,
        ).updateStreak(userId: 'u', studyDate: completed);
        await sent.future.timeout(const Duration(seconds: 2));
        if (switchAccount) await _setIdentity(client, 'other');
        release.complete();
        expect((await result).isFailure, switchAccount);
        expect(body, {'p_user_id': 'u', 'p_study_date': '2026-11-27'});
      },
    );
  }
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
}
