import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../services/purchases/purchase_service.dart';
import '../auth/auth_provider.dart';

final purchaseServiceProvider = Provider<PurchaseService>(
  (_) => PurchaseService.instance,
);

// Streams CustomerInfo: emits current state on first listen, then live updates.
final customerInfoProvider = StreamProvider<CustomerInfo>((ref) async* {
  final service = ref.watch(purchaseServiceProvider);
  try {
    yield await service.getCustomerInfo();
  } catch (_) {}
  yield* service.customerInfoStream;
});

// True if the user has premium access via RevenueCat (paid subscription)
// OR via a Supabase-granted subscription type (student / manual premium).
final isPremiumProvider = Provider<bool>((ref) {
  final info = ref.watch(customerInfoProvider).valueOrNull;
  if (info != null && PurchaseService.hasPremium(info)) return true;
  return ref.watch(currentUserProvider)?.subscriptionType.hasAccess ?? false;
});

// Loads available packages from RevenueCat (auto-dispose: only needed on paywall).
final offeringsProvider = FutureProvider.autoDispose<Offerings?>((ref) async {
  try {
    return await ref.watch(purchaseServiceProvider).getOfferings();
  } catch (_) {
    return null;
  }
});

final purchaseNotifierProvider =
    NotifierProvider.autoDispose<PurchaseNotifier, AsyncValue<void>>(
        PurchaseNotifier.new);

class PurchaseNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  // Returns true on success, false on cancel or error.
  Future<bool> purchase(Package package) async {
    state = const AsyncLoading();
    try {
      await ref.read(purchaseServiceProvider).purchasePackage(package);
      state = const AsyncData(null);
      return true;
    } on PlatformException catch (e) {
      // User tapped cancel — treat as non-error
      if (_isCancelled(e)) {
        state = const AsyncData(null);
        return false;
      }
      state = AsyncError(e.message ?? 'Purchase failed', StackTrace.current);
      return false;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  // Returns updated CustomerInfo on success (use hasPremium to check result), null on error.
  Future<CustomerInfo?> restore() async {
    state = const AsyncLoading();
    try {
      final info = await ref.read(purchaseServiceProvider).restorePurchases();
      state = const AsyncData(null);
      return info;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return null;
    }
  }

  bool _isCancelled(PlatformException e) {
    final details = e.details;
    if (details is Map) {
      final code = details['readable_error_code'] as String?;
      return code == 'PURCHASE_CANCELLED';
    }
    return false;
  }
}
