import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical locations for audio that is rendered once on the server.
///
/// Seed content is shared across every account: the text/language hash makes
/// its path immutable and lets the publishing tool avoid a second ElevenLabs
/// render. User content belongs to its owner and gets a new immutable object
/// whenever its spelling changes.
class AudioAssetPath {
  const AudioAssetPath._();

  static const bucket = 'vocab-audio';
  static const seedVersion = 'v1';

  static String seed({required String text, required String langCode}) {
    final hash = contentHash(text: text, langCode: langCode);
    return 'seed/$seedVersion/$langCode/$hash.mp3';
  }

  static String user({
    required String userId,
    required String variantId,
    required String text,
    required String langCode,
  }) {
    final hash = contentHash(text: text, langCode: langCode);
    return 'users/$userId/$variantId/$hash.mp3';
  }

  static String contentHash({required String text, required String langCode}) =>
      sha256.convert(utf8.encode('$seedVersion|$langCode|$text')).toString();
}
