/// Uses Flutter's debug-mode defines so the gate can also be checked in AOT.
const sttDiagnosticsEnabled = !bool.fromEnvironment('dart.vm.product') &&
    !bool.fromEnvironment('dart.vm.profile') &&
    bool.fromEnvironment('STT_DIAGNOSTICS');
