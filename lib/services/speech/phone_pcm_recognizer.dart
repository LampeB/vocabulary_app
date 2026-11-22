import 'package:flutter/services.dart';

/// The phone's own speech recognizer, run on audio WE captured (Android 13+
/// `EXTRA_AUDIO_SOURCE`, native side: PcmSpeechRecognizer.kt).
abstract interface class PhonePcmRecognizer {
  /// Android 13+ with a recognition service installed.
  Future<bool> isSupported();

  /// Transcribes 16kHz mono PCM16 in [locale] (BCP-47). Returns every
  /// alternative, best first; empty when nothing was understood. Throws a
  /// [PlatformException] on a recognizer failure.
  Future<List<String>> recognize(Uint8List pcm16, String locale);
}

class MethodChannelPhonePcmRecognizer implements PhonePcmRecognizer {
  const MethodChannelPhonePcmRecognizer();

  static const _channel = MethodChannel('vocab_kr/pcm_speech');

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false; // iOS / host tests: no native bridge
    }
  }

  @override
  Future<List<String>> recognize(Uint8List pcm16, String locale) async {
    final reply = await _channel.invokeMapMethod<String, dynamic>(
      'recognize',
      {'pcm': pcm16, 'locale': locale, 'sampleRate': 16000, 'timeoutMs': 6000},
    );
    final texts = reply?['texts'];
    return texts is List ? texts.whereType<String>().toList() : const [];
  }
}
