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

// Forces the app's locale in E2E tests (e.g. 'fr') so emulators that default to
// English still render the language the tests expect. Empty in production →
// device locale is used.
const _kTestLocale = String.fromEnvironment('TEST_LOCALE');

// A pre-seeded Supabase session (Session JSON) injected under TEST_MODE. Each
// isolated E2E test runs in a fresh process with cleared storage
// (clearPackageData), so without this every test would do a slow, flaky network
// sign-in. Restoring a fresh (unexpired) session is local — no network, no
// refresh-token rotation — so all tests start signed in instantly. Empty in prod.
const _kTestSession = String.fromEnvironment('TEST_SESSION');

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

    // E2E: start already signed in from the injected session (see above).
    if (_kTestMode && _kTestSession.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.recoverSession(_kTestSession);
      } catch (_) {
        // Fall back to the UI sign-in path if the session can't be restored.
      }
    }

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
      startLocale: _kTestLocale.isEmpty ? null : Locale(_kTestLocale),
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
