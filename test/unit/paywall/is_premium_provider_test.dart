import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:vocab_kr/domain/entities/app_user.dart';
import 'package:vocab_kr/domain/entities/subscription_type.dart';
import 'package:vocab_kr/presentation/providers/auth/auth_provider.dart';
import 'package:vocab_kr/presentation/providers/purchases/purchase_provider.dart';

/// The premium decision combines two sources: a RevenueCat entitlement OR a
/// Supabase-granted tier (student / manual premium). This pins the OR.

AppUser _user(SubscriptionType sub) => AppUser(
      id: 'u',
      email: 't@t.fr',
      username: 'thomas',
      subscriptionType: sub,
      createdAt: DateTime(2026),
    );

/// Minimal RevenueCat CustomerInfo built from JSON (the models are
/// json-constructible; no plugin needed).
CustomerInfo _customerInfo({required bool premiumActive}) {
  final entitlement = {
    'identifier': 'premium',
    'isActive': true,
    'willRenew': true,
    'periodType': 'NORMAL',
    'latestPurchaseDate': '2026-07-01T00:00:00Z',
    'latestPurchaseDateMillis': 0,
    'originalPurchaseDate': '2026-07-01T00:00:00Z',
    'originalPurchaseDateMillis': 0,
    'productIdentifier': 'premium_annual',
    'isSandbox': false,
    'ownershipType': 'PURCHASED',
    'store': 'APP_STORE',
    'verification': 'NOT_REQUESTED',
  };
  return CustomerInfo.fromJson({
    'entitlements': {
      'all': premiumActive ? {'premium': entitlement} : <String, dynamic>{},
      'active': premiumActive ? {'premium': entitlement} : <String, dynamic>{},
      'verification': 'NOT_REQUESTED',
    },
    'allPurchaseDates': <String, dynamic>{},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': <String>[],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-07-01T00:00:00Z',
    'originalAppUserId': 'u',
    'requestDate': '2026-07-01T00:00:00Z',
    'allExpirationDates': <String, dynamic>{},
    'originalApplicationVersion': null,
    'originalPurchaseDate': null,
    'managementURL': null,
    'latestExpirationDate': null,
  });
}

ProviderContainer _container({
  CustomerInfo? info,
  AppUser? user,
}) {
  final c = ProviderContainer(overrides: [
    customerInfoProvider.overrideWith(
        (ref) => info == null ? const Stream.empty() : Stream.value(info)),
    currentUserProvider.overrideWithValue(user),
  ]);
  addTearDown(c.dispose);
  // Providers are lazy: subscribe now so the stream has emitted by _settle().
  c.listen(customerInfoProvider, (_, __) {});
  return c;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('no RevenueCat info + free user → not premium', () async {
    final c = _container(user: _user(SubscriptionType.free));
    await _settle();
    expect(c.read(isPremiumProvider), isFalse);
  });

  test('no RevenueCat info + student tier → premium (Supabase-granted)',
      () async {
    final c = _container(user: _user(SubscriptionType.student));
    await _settle();
    expect(c.read(isPremiumProvider), isTrue);
  });

  test('active RevenueCat entitlement → premium even for a free-tier user',
      () async {
    final c = _container(
        info: _customerInfo(premiumActive: true),
        user: _user(SubscriptionType.free));
    await _settle();
    expect(c.read(isPremiumProvider), isTrue);
  });

  test('RevenueCat info without the entitlement falls back to the tier',
      () async {
    final c = _container(
        info: _customerInfo(premiumActive: false),
        user: _user(SubscriptionType.free));
    await _settle();
    expect(c.read(isPremiumProvider), isFalse);
  });

  test('signed out → not premium', () async {
    final c = _container();
    await _settle();
    expect(c.read(isPremiumProvider), isFalse);
  });
}
