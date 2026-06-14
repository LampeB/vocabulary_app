import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'audio_service.dart';
import '../../core/config/app_config.dart';

class ElevenLabsService implements AudioService {
  ElevenLabsService({this.frVoiceId = 'Charlotte', this.koVoiceId = 'Elli'});

  final String frVoiceId;
  final String koVoiceId;

  final _cache = <String, String>{}; // hash → file path

  @override
  Future<void> speak(String text, String langCode, {String? voiceId}) async {
    final id = voiceId ?? (langCode == 'ko' ? koVoiceId : frVoiceId);
    final path = await _getOrGenerate(text, langCode, id);
    if (path == null) return;
    // Play via audioplayers — caller injects the player; here we return path only
    // AudioPlayerService wraps this and calls play(path)
  }

  Future<String?> generateAndCache(
      String text, String langCode, String voiceId) =>
      _getOrGenerate(text, langCode, voiceId);

  Future<String?> _getOrGenerate(
      String text, String langCode, String voiceId) async {
    final key = _cacheKey(text, langCode, voiceId);
    if (_cache.containsKey(key)) return _cache[key];

    final dir = await _cacheDir();
    final file = File('${dir.path}/$key.mp3');
    if (file.existsSync()) {
      _cache[key] = file.path;
      return file.path;
    }

    try {
      final res = await http.post(
        Uri.parse(AppConfig.elevenLabsEdgeFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'text': text,
          'voice_id': voiceId,
          'lang_code': langCode,
        }),
      );
      if (res.statusCode != 200) return null;
      await file.writeAsBytes(res.bodyBytes);
      _cache[key] = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  String _cacheKey(String text, String langCode, String voiceId) {
    final input = '$text|$langCode|$voiceId';
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/audio_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<int> cacheSize() async {
    final dir = await _cacheDir();
    if (!dir.existsSync()) return 0;
    return dir
        .listSync()
        .whereType<File>()
        .fold<int>(0, (sum, f) => sum + f.lengthSync());
  }

  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    _cache.clear();
  }

  @override
  Future<bool> isAvailable() async => AppConfig.enableElevenLabsTTS;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
