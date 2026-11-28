import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

enum SttDiagnosticsFolder {
  corpus('stt_corpus'),
  logs('stt_logs');

  const SttDiagnosticsFolder(this.directoryName);
  final String directoryName;
}

/// Returns a directory safe for new diagnostic files. On iOS, Foundation
/// creates or verifies the directory and confirms its backup exclusion.
Future<Directory?> prepareSttDiagnosticsDirectory(
  Directory parent,
  SttDiagnosticsFolder folder,
) async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    const channel = MethodChannel('vocab_kr/stt_diagnostics_storage');
    try {
      final path = await channel.invokeMethod<Object?>(
        'prepare',
        folder.directoryName,
      );
      return path is String && path.isNotEmpty ? Directory(path) : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
  final directory = Directory(p.join(parent.path, folder.directoryName));
  return directory.create(recursive: true);
}
