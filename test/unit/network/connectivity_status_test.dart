import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/core/network/connectivity_status.dart';

/// Offline detection is the rule that drives the "you're offline" banner. It's
/// multi-transport aware (connectivity_plus reports a list), so the edge cases
/// below matter: any single non-none transport counts as online.
void main() {
  group('isOffline', () {
    test('empty list → offline', () {
      expect(isOffline([]), isTrue);
    });

    test('a single none → offline', () {
      expect(isOffline([ConnectivityResult.none]), isTrue);
    });

    test('all-none (multiple) → offline', () {
      expect(isOffline([ConnectivityResult.none, ConnectivityResult.none]),
          isTrue);
    });

    test('wifi → online', () {
      expect(isOffline([ConnectivityResult.wifi]), isFalse);
    });

    test('mobile → online', () {
      expect(isOffline([ConnectivityResult.mobile]), isFalse);
    });

    test('mix of none + wifi → online (any usable transport wins)', () {
      expect(isOffline([ConnectivityResult.none, ConnectivityResult.wifi]),
          isFalse);
    });
  });
}
