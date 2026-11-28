import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

/// Downloads a pinned model into an atomic, checksum-verified cache entry.
/// Concurrent callers for the same destination share one download. An invalid
/// or interrupted download never replaces a previously installed model.
class VerifiedModelStore {
  static final _pending = <String, Future<File>>{};

  Future<File> ensure({
    required File destination,
    required Uri source,
    required String checksum,
    required int expectedBytes,
  }) {
    final key = destination.absolute.path;
    final pending = _pending[key];
    if (pending != null) return pending;
    final future = _ensure(
      destination: destination,
      source: source,
      checksum: checksum,
      expectedBytes: expectedBytes,
    );
    _pending[key] = future;
    // Use a handled continuation: a failed download must be retryable without
    // creating a second unhandled Future error during cleanup.
    unawaited(
      future.then<void>(
        (_) {
          _pending.remove(key);
        },
        onError: (Object _, StackTrace _) {
          _pending.remove(key);
        },
      ),
    );
    return future;
  }

  Future<File> _ensure({
    required File destination,
    required Uri source,
    required String checksum,
    required int expectedBytes,
  }) async {
    if (await _matches(destination, checksum, expectedBytes)) {
      return destination;
    }
    await destination.parent.create(recursive: true);
    final partial = File('${destination.path}.part');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final response = await (await client.getUrl(
        source,
      )).close().timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Model download failed (${response.statusCode})',
          uri: source,
        );
      }
      var receivedBytes = 0;
      final chunks = response.timeout(const Duration(seconds: 30)).map((chunk) {
        receivedBytes += chunk.length;
        if (receivedBytes > expectedBytes) {
          throw StateError('Whisper model exceeds its pinned size');
        }
        return chunk;
      });
      // pipe applies backpressure so downloading a 142 MB model never queues
      // the entire file in memory on a slower device.
      await chunks.pipe(partial.openWrite());
      if (!await _matches(partial, checksum, expectedBytes)) {
        throw StateError('Downloaded Whisper model checksum did not match');
      }
      await partial.rename(destination.path);
      return destination;
    } finally {
      client.close(force: true);
      if (await partial.exists()) await partial.delete();
    }
  }

  static Future<bool> _matches(File file, String expected, int bytes) async {
    final filePath = file.path;
    return Isolate.run(() async {
      final candidate = File(filePath);
      if (!await candidate.exists() || await candidate.length() != bytes) {
        return false;
      }
      return (await sha256.bind(candidate.openRead()).first).toString() ==
          expected;
    });
  }
}
