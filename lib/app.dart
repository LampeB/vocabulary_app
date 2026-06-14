import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/onboarding/splash_screen.dart';
import 'presentation/screens/onboarding/welcome_screen.dart';
import 'presentation/screens/onboarding/auth_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/lists/lists_screen.dart';
import 'presentation/screens/lists/list_detail_screen.dart';
import 'presentation/screens/quiz/quiz_setup_screen.dart';
import 'presentation/screens/quiz/quiz_screen.dart';
import 'presentation/screens/social/social_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/paywall/paywall_screen.dart';
import 'presentation/screens/notifications/notification_settings_screen.dart';
import 'presentation/providers/quiz/quiz_provider.dart' show QuizArgs;
import 'presentation/widgets/app_shell.dart';

class VocabKrApp extends ConsumerStatefulWidget {
  const VocabKrApp({super.key});

  @override
  ConsumerState<VocabKrApp> createState() => _VocabKrAppState();
}

class _VocabKrAppState extends ConsumerState<VocabKrApp> {
  late final GoRouter _router;
  late final _AuthChangeNotifier _authNotifier;

  @override
  void initState() {
    super.initState();
    _authNotifier =
        _AuthChangeNotifier(Supabase.instance.client);
    _router = _buildRouter();
  }

  @override
  void dispose() {
    _authNotifier.dispose();
    _router.dispose();
    super.dispose();
  }

  GoRouter _buildRouter() => GoRouter(
        initialLocation: '/splash',
        refreshListenable: _authNotifier,
        redirect: (context, state) {
          final isSignedIn =
              Supabase.instance.client.auth.currentUser != null;
          final loc = state.matchedLocation;
          final onPublic =
              loc == '/splash' || loc == '/welcome' || loc == '/auth';

          if (!isSignedIn && !onPublic) return '/welcome';
          if (isSignedIn && (loc == '/welcome' || loc == '/auth')) {
            return '/home';
          }
          return null;
        },
        routes: [
          GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
          GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
          GoRoute(
            path: '/auth',
            builder: (_, state) {
              final mode = state.uri.queryParameters['mode'] ?? 'signin';
              return AuthScreen(initialMode: mode);
            },
          ),
          ShellRoute(
            builder: (_, __, child) => AppShell(child: child),
            routes: [
              GoRoute(
                  path: '/home', builder: (_, __) => const HomeScreen()),
              GoRoute(
                  path: '/lists', builder: (_, __) => const ListsScreen()),
              GoRoute(
                path: '/lists/:listId',
                builder: (_, state) => ListDetailScreen(
                    listId: state.pathParameters['listId']!),
              ),
              GoRoute(
                path: '/lists/:listId/quiz-setup',
                builder: (_, state) => QuizSetupScreen(
                    listId: state.pathParameters['listId']!),
              ),
              GoRoute(
                path: '/quiz',
                builder: (_, state) =>
                    QuizScreen(args: state.extra as QuizArgs),
              ),
              GoRoute(
                  path: '/social',
                  builder: (_, __) => const SocialScreen()),
              GoRoute(
                  path: '/profile',
                  builder: (_, __) => const ProfileScreen()),
              GoRoute(
                  path: '/paywall',
                  builder: (_, __) => const PaywallScreen()),
              GoRoute(
                  path: '/notifications',
                  builder: (_, __) =>
                      const NotificationSettingsScreen()),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VocabKR',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(SupabaseClient client) {
    _sub = client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
