import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'services/notifications/notification_service.dart';
import 'presentation/providers/notifications/notification_provider.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Initialise notification service before the widget tree builds so that
  // timezone data and plugin channels are ready when providers first run.
  await NotificationService.instance.init();

  runApp(ProviderScope(
    overrides: [
      notificationServiceProvider
          .overrideWithValue(NotificationService.instance),
    ],
    child: const VocabKrApp(),
  ));
}
