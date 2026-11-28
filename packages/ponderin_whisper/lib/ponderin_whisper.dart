import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'src/verified_model_store.dart';

enum PonderinWhisperModel {
  base(
    'ggml-base.bin',
    'https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin',
    '2f62d18b50c3f3feafbf990eec23a93d319660b1efbdd3fff55e52b7cde2e374',
  );

  const PonderinWhisperModel(this.fileName, this.downloadUrl, this.sha256);

  final String fileName;
  final String downloadUrl;
  final String sha256;
}

/// A small Flutter-facing boundary for Ponderin's native `whisper.cpp` bridge.
/// It deliberately exposes only the operations the app needs: an integrity
/// checked model download and a single WAV transcription.
class PonderinWhisper {
  PonderinWhisper({required this.model});

  final PonderinWhisperModel model;
  String? _modelPath;
  Future<void>? _preparing;

  static bool get isSupported => Platform.isAndroid;

  Future<void> ensureModel() {
    if (!isSupported) {
      return Future.error(
        UnsupportedError(
          'Ponderin Whisper currently ships an Android bridge only',
        ),
      );
    }
    if (_modelPath != null) return Future.value();
    return _preparing ??= _prepareModel().whenComplete(() => _preparing = null);
  }

  Future<void> _prepareModel() async {
    final directory = await getApplicationSupportDirectory();
    final destination = File(
      path.join(directory.path, 'ponderin-whisper', model.fileName),
    );
    await VerifiedModelStore().ensure(
      destination: destination,
      source: Uri.parse(model.downloadUrl),
      checksum: model.sha256,
      expectedBytes: 147951465,
    );
    _modelPath = destination.path;
  }

  Future<String> transcribe({
    required String audioPath,
    required String language,
    String initialPrompt = '',
  }) async {
    await ensureModel();
    // Capture strings only: neither the Flutter object nor FFI pointers may
    // cross isolates. The native context remains cached process-wide behind
    // its mutex, while model loading and inference cannot block the UI.
    final modelPath = _modelPath!;
    return Isolate.run(
      () => _PonderinWhisperBindings.open().transcribe(
        modelPath: modelPath,
        audioPath: audioPath,
        language: language,
        initialPrompt: initialPrompt,
      ),
    );
  }
}

class _PonderinWhisperBindings {
  _PonderinWhisperBindings._(this._transcribe, this._free, this._lastError);

  factory _PonderinWhisperBindings.open() {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Ponderin Whisper currently ships an Android bridge only',
      );
    }
    final library = DynamicLibrary.open('libponderin_whisper.so');
    return _PonderinWhisperBindings._(
      library.lookupFunction<
        Pointer<Utf8> Function(
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
        ),
        Pointer<Utf8> Function(
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
          Pointer<Utf8>,
        )
      >('ponderin_whisper_transcribe'),
      library.lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('ponderin_whisper_free'),
      library
          .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
            'ponderin_whisper_last_error',
          ),
    );
  }

  final Pointer<Utf8> Function(
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Utf8>,
  )
  _transcribe;
  final void Function(Pointer<Utf8>) _free;
  final Pointer<Utf8> Function() _lastError;

  String transcribe({
    required String modelPath,
    required String audioPath,
    required String language,
    required String initialPrompt,
  }) {
    final nativeModel = modelPath.toNativeUtf8();
    final nativeAudio = audioPath.toNativeUtf8();
    final nativeLanguage = language.toNativeUtf8();
    final nativePrompt = initialPrompt.toNativeUtf8();
    try {
      final result = _transcribe(
        nativeModel,
        nativeAudio,
        nativeLanguage,
        nativePrompt,
      );
      if (result == nullptr) {
        final error = _lastError().toDartString();
        throw StateError(
          error.isEmpty ? 'Whisper transcription failed' : error,
        );
      }
      try {
        return result.toDartString();
      } finally {
        _free(result);
      }
    } finally {
      malloc.free(nativeModel);
      malloc.free(nativeAudio);
      malloc.free(nativeLanguage);
      malloc.free(nativePrompt);
    }
  }
}
