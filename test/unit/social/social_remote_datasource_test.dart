import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vocab_kr/core/errors/failure.dart';
import 'package:vocab_kr/data/datasources/remote/social_remote_datasource.dart';

void main() {
  test('sends friend decisions through the authenticated RPCs', () async {
    final calls = <http.Request>[];
    final client = SupabaseClient(
      'https://supabase.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        calls.add(request);
        return http.Response('', 204, request: request);
      }),
    );
    addTearDown(client.dispose);
    final remote = SocialRemoteDataSource(client, 'my-account');

    expect((await remote.sendFriendRequest('recipient')).isSuccess, isTrue);
    expect((await remote.acceptFriendRequest('request-a')).isSuccess, isTrue);
    expect((await remote.declineFriendRequest('request-b')).isSuccess, isTrue);
    expect(calls.map((call) => call.method), everyElement('POST'));
    expect(calls.map((call) => call.url.path), [
      '/rest/v1/rpc/send_friend_request',
      '/rest/v1/rpc/respond_friend_request',
      '/rest/v1/rpc/respond_friend_request',
    ]);
    expect(calls.map((call) => jsonDecode(call.body)), [
      {'p_to_user_id': 'recipient'},
      {'p_request_id': 'request-a', 'p_accept': true},
      {'p_request_id': 'request-b', 'p_accept': false},
    ]);
  });
}
