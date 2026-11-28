import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/ponderin_localization.dart';
import 'services/notifications/notification_service.dart';
import 'services/purchases/purchase_service.dart';
import 'presentation/providers/notifications/notification_provider.dart';
import 'app.dart';

// Injected by test env files; false in production.
const _kTestMode = bool.fromEnvironment('TEST_MODE');

// Forces the app's locale in E2E tests (e.g. 'fr') so emulators that default to
// English still render the language the tests expect. Empty in production →
// device locale is used.
const _kTestLocale = String.fromEnvironment('TEST_LOCALE');

// Guards one-time init so repeated app.main() calls in E2E tests are safe.
bool _initialized = false;

Future<void> main() async {
  // `main()` is also called by Patrol after its binding is already created.
  // Do not create another Dart zone here: Flutter requires binding creation
  // and runApp to share one zone in both normal and integration-test launches.
  WidgetsFlutterBinding.ensureInitialized();

  // Patrol owns FlutterError.onError to report assertion failures. Replacing it
  // makes a genuine test error look like a runner crash instead.
  if (!_kTestMode) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };
  }

  if (!_initialized) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );

    await NotificationService.instance.init();

    // RevenueCat makes network requests that prevent pumpAndSettle() from
    // settling in tests — skip it entirely when TEST_MODE is set.
    if (!_kTestMode) {
      await PurchaseService.instance.configure(AppConfig.revenueCatApiKey);
    }

    _initialized = true;
  }

  await EasyLocalization.ensureInitialized();

  runApp(
    PonderinLocalization(
      startLocale: _kTestLocale.isEmpty ? null : Locale(_kTestLocale),
      child: ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            NotificationService.instance,
          ),
        ],
        child: const PonderinApp(),
      ),
    ),
  );
}
