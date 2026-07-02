import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';

/// Subscription tier parsing + the hasAccess gate that isPremiumProvider leans
/// on. Pure enum logic.
void main() {
  group('fromString', () {
    test('maps known tiers', () {
      expect(SubscriptionType.fromString('student'), SubscriptionType.student);
      expect(SubscriptionType.fromString('premium'), SubscriptionType.premium);
      expect(SubscriptionType.fromString('free'), SubscriptionType.free);
    });

    test('null / unknown / empty fall back to free', () {
      expect(SubscriptionType.fromString(null), SubscriptionType.free);
      expect(SubscriptionType.fromString('gibberish'), SubscriptionType.free);
      expect(SubscriptionType.fromString(''), SubscriptionType.free);
    });
  });

  group('hasAccess', () {
    test('free has no access; student and premium do', () {
      expect(SubscriptionType.free.hasAccess, isFalse);
      expect(SubscriptionType.student.hasAccess, isTrue);
      expect(SubscriptionType.premium.hasAccess, isTrue);
    });
  });

  test('every tier has a display label', () {
    for (final t in SubscriptionType.values) {
      expect(t.displayLabel, isNotEmpty);
    }
  });
}
