import 'package:vocab_kr/core/utils/stt_diagnostics.dart';

void main() {
  if (!const bool.fromEnvironment('dart.vm.product') ||
      !const bool.fromEnvironment('STT_DIAGNOSTICS')) {
    throw StateError('Compile this probe in product mode with STT opted in.');
  }
  if (sttDiagnosticsEnabled) {
    throw StateError('STT diagnostics were enabled in product mode.');
  }
}
