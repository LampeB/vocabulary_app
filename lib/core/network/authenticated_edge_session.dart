import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart' show PermissionException;

/// Keeps the credentials and results of Edge Function work within the session
/// that started it. A benchmark can reuse the scope across several requests.
class AuthenticatedEdgeSession {
  AuthenticatedEdgeSession(this._client) {
    final initial = _client.auth.currentSession;
    _ownerId = initial?.user.id;
    _authEvents = _client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut ||
          state.session?.user.id != _ownerId ||
          (state.event == AuthChangeEvent.signedIn &&
              !identical(state.session, initial))) {
        _ended = true;
      }
    }, onError: (Object _, StackTrace _) {});
  }

  final SupabaseClient _client;
  late final String? _ownerId;
  late final StreamSubscription<AuthState> _authEvents;
  bool _ended = false;

  bool get isCurrent =>
      !_ended && _ownerId != null && _client.auth.currentUser?.id == _ownerId;

  void _requireCurrent() {
    if (!isCurrent) throw const PermissionException();
  }

  Future<FunctionResponse> invoke(
    String function, {
    required Object body,
  }) async {
    _requireCurrent();
    var session = _client.auth.currentSession!;
    if (session.isExpired) {
      await _client.auth.refreshSession();
      _requireCurrent();
      session = _client.auth.currentSession!;
    }
    // FunctionsClient encodes a map asynchronously before its HTTP client
    // looks up the current default bearer. Pin this call's credentials first.
    final response = await _client.functions.invoke(
      function,
      body: body,
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    _requireCurrent();
    return response;
  }

  Future<void> close() {
    _ended = true;
    return _authEvents.cancel();
  }
}

Future<FunctionResponse> invokeAuthenticatedEdgeFunction(
  SupabaseClient client,
  String function, {
  required Object body,
}) {
  final session = AuthenticatedEdgeSession(client);
  return session.invoke(function, body: body).whenComplete(session.close);
}
