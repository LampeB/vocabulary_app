import 'package:flutter_driver/driver_extension.dart';
import 'main.dart' as app;
import 'dart:developer' as developer;

/// Special entry point for Appium testing
/// Enables Flutter Driver extension so Appium can connect
void main() {
  // Debug logging to verify this entry point is used
  developer.log('=== APPIUM MAIN STARTED ===', name: 'appium.main');
  print('=== APPIUM MAIN STARTED ===');

  // Enable Flutter Driver extension
  enableFlutterDriverExtension();

  developer.log('=== FLUTTER DRIVER ENABLED ===', name: 'appium.main');
  print('=== FLUTTER DRIVER ENABLED ===');

  // Run the app
  app.main();
}
