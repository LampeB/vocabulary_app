import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  PurchaseService._();
  static final instance = PurchaseService._();

  static const _premiumEntitlement = 'premium';

  final _customerInfoController = StreamController<CustomerInfo>.broadcast();
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  Future<void> configure(String apiKey) async {
    await Purchases.configure(PurchasesConfiguration(apiKey));
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    if (!_customerInfoController.isClosed) {
      _customerInfoController.add(info);
    }
  }

  Future<void> logIn(String userId) async {
    try {
      final result = await Purchases.logIn(userId);
      _onCustomerInfoUpdated(result.customerInfo);
    } catch (_) {}
  }

  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {}
  }

  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  Future<Offerings> getOfferings() => Purchases.getOfferings();

  Future<CustomerInfo> purchasePackage(Package package) =>
      Purchases.purchasePackage(package);

  Future<CustomerInfo> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    _onCustomerInfoUpdated(info);
    return info;
  }

  static bool hasPremium(CustomerInfo info) =>
      info.entitlements.active.containsKey(_premiumEntitlement);
}
