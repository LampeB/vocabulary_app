import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocab_kr/app.dart';

void main() {
  testWidgets('both diagnostic deep links require explicit debug opt-in', (
    tester,
  ) async {
    const optedIn = bool.fromEnvironment('STT_DIAGNOSTICS');
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => throw UnimplementedError()),
        ...sttDiagnosticsRoutes,
      ],
    );
    addTearDown(router.dispose);
    for (final path in ['/stt-lab', '/stt-lab/near-miss']) {
      final match = router.configuration.findMatch(Uri.parse(path));
      expect(match.isError, !optedIn, reason: path);
    }
  });
}
