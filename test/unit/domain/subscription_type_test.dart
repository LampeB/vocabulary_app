import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';

void main() {
  group('SubscriptionType.hasAccess', () {
    test('free returns false', () {
      expect(SubscriptionType.free.hasAccess, isFalse);
    });

    test('student returns true', () {
      expect(SubscriptionType.student.hasAccess, isTrue);
    });

    test('premium returns true', () {
      expect(SubscriptionType.premium.hasAccess, isTrue);
    });
  });

  group('SubscriptionType.displayLabel', () {
    test('free displays Free plan', () {
      expect(SubscriptionType.free.displayLabel, 'Free plan');
    });

    test('student displays Student Access', () {
      expect(SubscriptionType.student.displayLabel, 'Student Access');
    });

    test('premium displays Premium', () {
      expect(SubscriptionType.premium.displayLabel, 'Premium');
    });
  });

  group('SubscriptionType.fromString', () {
    test('student string returns student', () {
      expect(SubscriptionType.fromString('student'), SubscriptionType.student);
    });

    test('premium string returns premium', () {
      expect(SubscriptionType.fromString('premium'), SubscriptionType.premium);
    });

    test('free string falls through to default and returns free', () {
      expect(SubscriptionType.fromString('free'), SubscriptionType.free);
    });

    test('null returns free', () {
      expect(SubscriptionType.fromString(null), SubscriptionType.free);
    });

    test('unknown string returns free', () {
      expect(SubscriptionType.fromString('vip'), SubscriptionType.free);
    });

    test('empty string returns free', () {
      expect(SubscriptionType.fromString(''), SubscriptionType.free);
    });
  });
}
