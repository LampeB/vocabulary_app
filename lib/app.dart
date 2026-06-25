import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'presentation/screens/import/import_from_link_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/stats/stats_screen.dart';
import 'presentation/providers/quiz/quiz_provider.dart' show QuizArgs;
import 'presentation/providers/settings/settings_provider.dart';
import 'presentation/widgets/app_shell.dart';

// Set via --dart-define-from-file in integration tests to skip page-transition
// animations, which cause mid-layout semantics errors in the test framework.
const _kTestMode = bool.fromEnvironment('TEST_MODE');

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
          Animation<double> animation, Animation<double> secondaryAnimation,
          Widget child) =>
      child;
}

class VocabKrApp extends ConsumerStatefulWidget {
  const VocabKrApp({super.key});

  @override
  ConsumerState<VocabKrApp> createState() => _VocabKrAppState();
}


class _VocabKrAppState extends ConsumerState<VocabKrApp> {
  late final GoRouter _router;
  late final _AuthChangeNotifier _authNotifier;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _authNotifier = _AuthChangeNotifier(Supabase.instance.client);
    _router = _buildRouter();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    // Handle initial link (app was cold-started from a link).
    _appLinks.getInitialLink().then(_handleLink);
    // Handle links while app is already running.
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri? uri) {
    if (uri == null) return;
    // Supabase auth callback: vocabkr://auth/callback?...
    if (uri.scheme == 'vocabkr' && uri.host == 'auth') {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
      return;
    }
    // Shared list import: vocabkr://import?token=...
    if (uri.scheme == 'vocabkr' && uri.host == 'import') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        _router.push('/import?token=$token');
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
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
        errorBuilder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('Page not found: ${state.error}')),
        ),
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
              GoRoute(
                  path: '/settings',
                  builder: (_, __) => const SettingsScreen()),
              GoRoute(
                  path: '/stats',
                  builder: (_, __) => const StatsScreen()),
            ],
          ),
          GoRoute(
            path: '/import',
            builder: (_, state) {
              final token = state.uri.queryParameters['token'] ?? '';
              return ImportFromLinkScreen(token: token);
            },
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    const noTransitions = PageTransitionsTheme(builders: {
      TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
      TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
    });
    return MaterialApp.router(
      title: 'VocabKR',
      theme: _kTestMode
          ? AppTheme.light.copyWith(pageTransitionsTheme: noTransitions)
          : AppTheme.light,
      darkTheme: _kTestMode
          ? AppTheme.dark.copyWith(pageTransitionsTheme: noTransitions)
          : AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
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
