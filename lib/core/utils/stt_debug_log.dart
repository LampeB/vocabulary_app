import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'stt_diagnostics.dart';
import 'stt_diagnostics_directory.dart';

const _kTestMode = bool.fromEnvironment('TEST_MODE');

/// Persistent on-device log of the whole voice pipeline — what TTS spoke,
/// when the mic opened, every partial/final the recognizer produced (with
/// confidence and alternates), how the validator scored it, and every
/// retry/discard decision. Written so real-device STT bugs can be debugged
/// from evidence instead of reproduction guesses.
///
/// Android: `/sdcard/Android/data/<pkg>/files/stt_logs/stt_<start-time>.log`
/// — pullable over adb without root:
///   adb pull /sdcard/Android/data/com.vocabkr.vocab_kr/files/stt_logs
///
/// Debug-only and enabled explicitly by STT_DIAGNOSTICS. One file per app
/// launch, the 5 most recent kept. Persistence is a no-op in TEST_MODE
/// (E2E owns its own diagnostics; extra IO destabilizes the emulator).
class SttDebugLog {
  SttDebugLog._();
  static final SttDebugLog instance = SttDebugLog._();

  IOSink? _sink;
  bool _initStarted = false;
  bool _unavailable = false;
  final List<String> _pending = [];

  Future<void> _init() async {
    try {
      final dir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final sink = dir == null ? null : await openFile(dir);
      if (sink == null) {
        _unavailable = true;
        _pending.clear();
        return;
      }
      _sink = sink;
      sink.writeln('=== STT debug log — app started ${DateTime.now()} ===');
      for (final line in _pending) {
        sink.writeln(line);
      }
      _pending.clear();
    } catch (_) {
      _unavailable = true;
      _pending.clear();
    }
  }

  @visibleForTesting
  static Future<IOSink?> openFile(Directory parent) async {
    if (!sttDiagnosticsEnabled || _kTestMode) return null;
    final directory = await prepareSttDiagnosticsDirectory(
      parent,
      SttDiagnosticsFolder.logs,
    );
    if (directory == null) return null;
    // One file per app launch; keep only the 5 most recent.
    final existing = directory.listSync().whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final file in existing.skip(4)) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(
      '${directory.path}${Platform.pathSeparator}stt_$stamp.log',
    );
    return file.openWrite(mode: FileMode.append);
  }

  void log(String message) {
    // Raw speech is diagnostic data. Release builds never persist it or emit
    // it to logcat; debug recording requires an explicit launch-time opt-in.
    if (!sttDiagnosticsEnabled) return;
    final t = DateTime.now();
    final ts =
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
    final line = '$ts $message';
    debugPrint('[STTLOG] $line');
    if (_kTestMode || _unavailable) return;
    if (_sink == null) {
      _pending.add(line);
      if (!_initStarted) {
        _initStarted = true;
        unawaited(_init());
      }
      return;
    }
    _sink!.writeln(line);
  }
}

/// The pipeline-wide logging entry point.
void sttLog(String message) => SttDebugLog.instance.log(message);
