import 'package:connectivity_plus/connectivity_plus.dart';

/// True when there is no usable network transport — either the platform reported
/// no results at all, or every reported transport is [ConnectivityResult.none].
///
/// A mix such as `[none, wifi]` is treated as ONLINE: connectivity_plus can report
/// several transports at once, and a single non-none entry means we're connected.
bool isOffline(List<ConnectivityResult> results) =>
    results.isEmpty || results.every((r) => r == ConnectivityResult.none);
