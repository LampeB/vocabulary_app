import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocab_kr/presentation/providers/settings/audio_settings_provider.dart';
import 'package:vocab_kr/presentation/providers/settings/settings_provider.dart';

/// Settings persistence & state. Pure host-side unit tests (SharedPreferences
/// mocked), so they're fast and immune to emulator flakiness.
void main() {
  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('themeModeProvider', () {
    test('defaults to system when nothing is saved', () {
      SharedPreferences.setMockInitialValues({});
      expect(makeContainer().read(themeModeProvider), ThemeMode.system);
    });

    test('set() updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final c = makeContainer();
      await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(c.read(themeModeProvider), ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_theme_mode'), 'dark');
    });

    test('every mode round-trips through persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final c = makeContainer();
      for (final m in ThemeMode.values) {
        await c.read(themeModeProvider.notifier).set(m);
        expect(c.read(themeModeProvider), m);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('settings_theme_mode'), m.name);
      }
    });

    test('loads the saved theme on build', () async {
      SharedPreferences.setMockInitialValues({'settings_theme_mode': 'light'});
      final c = makeContainer();
      c.read(themeModeProvider); // trigger build → async _load
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(themeModeProvider), ThemeMode.light);
    });

    test('falls back to system for an unknown saved value', () async {
      SharedPreferences.setMockInitialValues(
          {'settings_theme_mode': 'garbage'});
      final c = makeContainer();
      c.read(themeModeProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(c.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('audioSettingsProvider', () {
    test('defaults to 0.85 rate / 1.0 pitch', () {
      SharedPreferences.setMockInitialValues({});
      final s = makeContainer().read(audioSettingsProvider);
      expect(s.speechRate, 0.85);
      expect(s.pitch, 1.0);
    });

    test('setSpeechRate updates + persists and leaves pitch untouched',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = makeContainer();
      await c.read(audioSettingsProvider.notifier).setSpeechRate(1.1);
      expect(c.read(audioSettingsProvider).speechRate, 1.1);
      expect(c.read(audioSettingsProvider).pitch, 1.0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('audio_speech_rate'), 1.1);
    });

    test('setPitch updates + persists and leaves rate untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final c = makeContainer();
      await c.read(audioSettingsProvider.notifier).setPitch(1.15);
      expect(c.read(audioSettingsProvider).pitch, 1.15);
      expect(c.read(audioSettingsProvider).speechRate, 0.85);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('audio_pitch'), 1.15);
    });

    test('loads saved values on build', () async {
      SharedPreferences.setMockInitialValues(
          {'audio_speech_rate': 0.6, 'audio_pitch': 1.15});
      final c = makeContainer();
      c.read(audioSettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final s = c.read(audioSettingsProvider);
      expect(s.speechRate, 0.6);
      expect(s.pitch, 1.15);
    });

    group('listen window (user request 2026-10-02)', () {
      test('defaults to 7 seconds', () {
        SharedPreferences.setMockInitialValues({});
        expect(makeContainer().read(audioSettingsProvider).listenSeconds, 7);
      });

      test('set() persists the value', () async {
        SharedPreferences.setMockInitialValues({});
        final c = makeContainer();
        await c.read(audioSettingsProvider.notifier).setListenSeconds(10);
        expect(c.read(audioSettingsProvider).listenSeconds, 10);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('audio_listen_seconds'), 10);
      });

      test('values are clamped to 3–15 seconds', () async {
        SharedPreferences.setMockInitialValues({});
        final c = makeContainer();
        final n = c.read(audioSettingsProvider.notifier);
        await n.setListenSeconds(1);
        expect(c.read(audioSettingsProvider).listenSeconds, 3);
        await n.setListenSeconds(40);
        expect(c.read(audioSettingsProvider).listenSeconds, 15);
      });

      test('loads (and clamps) the saved value on build', () async {
        SharedPreferences.setMockInitialValues({'audio_listen_seconds': 99});
        final c = makeContainer();
        c.read(audioSettingsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(c.read(audioSettingsProvider).listenSeconds, 15);
      });
    });
  });
}
