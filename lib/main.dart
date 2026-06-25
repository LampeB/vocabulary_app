import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'services/notifications/notification_service.dart';
import 'services/purchases/purchase_service.dart';
import 'presentation/providers/notifications/notification_provider.dart';
import 'app.dart';

// Injected by test env files; false in production.
const _kTestMode = bool.fromEnvironment('TEST_MODE');

// Guards one-time init so repeated app.main() calls in E2E tests are safe.
bool _initialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

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

  runZonedGuarded(
    () => runApp(EasyLocalization(
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es'),
        Locale('de'),
        Locale('it'),
        Locale('ja'),
        Locale('ko'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      child: ProviderScope(
        overrides: [
          notificationServiceProvider
              .overrideWithValue(NotificationService.instance),
        ],
        child: const VocabKrApp(),
      ),
    )),
    (error, stack) => debugPrint('[ZoneError] $error\n$stack'),
  );
}
