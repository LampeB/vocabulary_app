import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/stt_diagnostics.dart';
import 'presentation/screens/onboarding/splash_screen.dart';
import 'presentation/screens/onboarding/welcome_screen.dart';
import 'presentation/screens/onboarding/auth_screen.dart';
import 'presentation/screens/home/v3_home_screen.dart';
import 'presentation/screens/home/daily_path_screen.dart';
import 'presentation/screens/lists/lists_screen.dart';
import 'presentation/screens/lists/list_detail_screen.dart';
import 'presentation/screens/quiz/quiz_screen.dart';
import 'presentation/screens/quiz/start_session_screen.dart';
import 'presentation/screens/grammar/grammar_screen.dart';
import 'presentation/screens/grammar/grammar_lesson_screen.dart';
import 'presentation/screens/social/social_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/paywall/paywall_screen.dart';
import 'presentation/screens/notifications/notification_settings_screen.dart';
import 'presentation/screens/import/import_from_link_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/settings/near_miss_session_screen.dart';
import 'presentation/screens/settings/stt_lab_screen.dart';
import 'presentation/screens/stats/stats_screen.dart';
import 'presentation/providers/quiz/quiz_provider.dart' show QuizArgs;
import 'presentation/providers/settings/settings_provider.dart';
import 'presentation/navigation/dive_in_page.dart';
import 'presentation/navigation/auth_redirect.dart';
import 'presentation/widgets/app_shell.dart';
import 'presentation/widgets/session_bootstrap.dart';
import 'services/incoming_link_dispatcher.dart';

// Set via --dart-define-from-file in integration tests to skip page-transition
// animations, which cause mid-layout semantics errors in the test framework.
const _kTestMode = bool.fromEnvironment('TEST_MODE');

@visibleForTesting
List<GoRoute> get sttDiagnosticsRoutes => [
  if (sttDiagnosticsEnabled) ...[
    GoRoute(path: '/stt-lab', builder: (_, _) => const SttLabScreen()),
    GoRoute(
      path: '/stt-lab/near-miss',
      builder: (_, _) => const NearMissSessionScreen(),
    ),
  ],
];

class _NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimationPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class PonderinApp extends ConsumerStatefulWidget {
  const PonderinApp({super.key});

  @override
  ConsumerState<PonderinApp> createState() => _PonderinAppState();
}

class _PonderinAppState extends ConsumerState<PonderinApp> {
  late final GoRouter _router;
  late final _AuthChangeNotifier _authNotifier;
  late final AppLinks _appLinks;
  late final IncomingLinkDispatcher _linkDispatcher;

  @override
  void initState() {
    super.initState();
    _authNotifier = _AuthChangeNotifier(Supabase.instance.client);
    _router = _buildRouter();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkDispatcher = IncomingLinkDispatcher(
      getInitialLink: _appLinks.getInitialLink,
      links: _appLinks.uriLinkStream,
      onLink: (uri, coldStart) => _handleLink(uri, coldStart: coldStart),
    );
  }

  void _handleLink(Uri? uri, {bool coldStart = false}) {
    if (!mounted || uri == null) return;
    // Supabase auth callback: vocabkr://auth/callback?...
    if (uri.scheme == 'vocabkr' && uri.host == 'auth') {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
      return;
    }
    // Shared list import: vocabkr://import?token=...
    if (uri.scheme == 'vocabkr' && uri.host == 'import') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        final location = Uri(
          path: '/import',
          queryParameters: {'token': token},
        ).toString();
        // Replacing splash cancels its pending navigation when a cold link
        // arrives before the profile. Warm links retain the previous surface.
        if (coldStart) {
          _router.go(location);
        } else {
          _router.push(location);
        }
      }
    }
  }

  @override
  void dispose() {
    unawaited(_linkDispatcher.dispose());
    _authNotifier.dispose();
    _router.dispose();
    super.dispose();
  }

  GoRouter _buildRouter() => GoRouter(
    initialLocation: '/splash',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final isSignedIn = Supabase.instance.client.auth.currentUser != null;
      final loc = state.matchedLocation;
      return authRedirect(isSignedIn: isSignedIn, location: loc);
    },
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/auth',
        builder: (_, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'signin';
          return AuthScreen(initialMode: mode);
        },
      ),
      ShellRoute(
        builder: (_, _, child) =>
            QuizRouteVisibility(child: AppShell(child: child)),
        routes: [
          // The signed-in landing page is the learning path. Vocabulary
          // and lessons remain independent tabs, but the first-use flow
          // always has one visible next step here.
          GoRoute(path: '/home', builder: (_, _) => const V3HomeScreen()),
          GoRoute(
            path: '/daily-path',
            pageBuilder: (_, state) => DiveInPage<void>(
              key: state.pageKey,
              origin: Alignment.topCenter,
              disableAnimation: _kTestMode,
              child: const DailyPathScreen(),
            ),
          ),
          GoRoute(path: '/lists', builder: (_, _) => const ListsScreen()),
          GoRoute(
            path: '/lists/:listId',
            builder: (_, state) =>
                ListDetailScreen(listId: state.pathParameters['listId']!),
          ),
          GoRoute(
            path: '/quiz',
            builder: (_, state) => QuizScreen(args: state.extra as QuizArgs),
          ),
          GoRoute(
            path: '/start-session',
            builder: (_, _) => const StartSessionScreen(),
          ),
          // Grammar is a separate flow, never mixed into vocab setup.
          GoRoute(
            path: '/start-session-grammar',
            builder: (_, state) => StartSessionScreen(
              grammar: true,
              initialRuleId: state.uri.queryParameters['rule'],
              initialLangA: state.uri.queryParameters['langA'],
              initialLangB: state.uri.queryParameters['langB'],
            ),
          ),
          // Grammar hub: every lesson with unlock/mastery progress.
          GoRoute(path: '/grammar', builder: (_, _) => const GrammarScreen()),
          GoRoute(
            path: '/grammar/:ruleId',
            pageBuilder: (_, state) => DiveInPage<void>(
              key: state.pageKey,
              origin: Alignment.center,
              disableAnimation: _kTestMode,
              child: GrammarLessonScreen(
                ruleId: state.pathParameters['ruleId']!,
              ),
            ),
          ),
          GoRoute(path: '/social', builder: (_, _) => const SocialScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(path: '/paywall', builder: (_, _) => const PaywallScreen()),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationSettingsScreen(),
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          ...sttDiagnosticsRoutes,
          GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
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
    const noTransitions = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _NoAnimationPageTransitionsBuilder(),
        TargetPlatform.iOS: _NoAnimationPageTransitionsBuilder(),
      },
    );
    return SessionBootstrap(
      child: MaterialApp.router(
        title: 'Ponderin',
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
      ),
    );
  }
}

class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(SupabaseClient client) {
    _sub = client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
