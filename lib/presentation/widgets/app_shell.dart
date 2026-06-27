import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widget_keys.dart';

const _kTestMode = bool.fromEnvironment('TEST_MODE');

final _connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  if (_kTestMode) return Stream.value([ConnectivityResult.wifi]);
  return Connectivity().onConnectivityChanged;
});

bool _isOffline(List<ConnectivityResult> results) =>
    results.isEmpty || results.every((r) => r == ConnectivityResult.none);

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _routes = ['/home', '/lists', '/social', '/profile'];

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _routes.length; i++) {
      if (loc.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(_connectivityProvider);
    final offline = connectivityAsync.valueOrNull != null &&
        _isOffline(connectivityAsync.valueOrNull!);
    final selected = _selectedIndex(context);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          // Content — padded at bottom so nothing hides behind the frosted bar.
          Column(
            children: [
              if (offline)
                Material(
                  color: Colors.orange,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_off, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'shell.offline_banner'.tr(),
                              style:
                                  const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: _kBarHeight + safeBottom),
                  child: child,
                ),
              ),
            ],
          ),
          // Frosted bottom nav.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _VkBottomNav(
              selectedIndex: selected,
              onTap: (index) {
                const dests = ['/home', '/lists', '/social', '/profile'];
                context.go(dests[index]);
              },
              onStudy: () => context.push('/start-session'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Constants ──────────────────────────────────────────────────────────────────

const _kBarHeight = 72.0;

// ── Nav widget ─────────────────────────────────────────────────────────────────

class _VkBottomNav extends StatelessWidget {
  const _VkBottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.onStudy,
  });

  final int selectedIndex;
  final void Function(int index) onTap;
  final VoidCallback onStudy;

  static const _tabs = [
    _SlotDef(Icons.home_outlined,          Icons.home_rounded,         'shell.nav_home',    0),
    _SlotDef(Icons.bookmark_border,        Icons.bookmark,             'shell.nav_lists',   1),
    _SlotDef(Icons.emoji_events_outlined,  Icons.emoji_events_rounded, 'shell.nav_social',  2),
    _SlotDef(Icons.person_outline_rounded, Icons.person_rounded,       'shell.nav_profile', 3),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.paperDark.withValues(alpha: 0.96)
        : const Color(0xFAF6F1EA);
    final borderColor =
        isDark ? const Color(0x1AFFFFFF) : AppColors.line;

    return Container(
      height: _kBarHeight + safeBottom,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: safeBottom),
      child: Row(
        children: [
          // 2 tabs · raised "study" centre button · 2 tabs.
          Expanded(
            child: _NavTile(
                def: _tabs[0],
                active: 0 == selectedIndex,
                onTap: () => onTap(0)),
          ),
          Expanded(
            child: _NavTile(
                def: _tabs[1],
                active: 1 == selectedIndex,
                onTap: () => onTap(1)),
          ),
          _StudyButton(
              key: const ValueKey(WidgetKeys.navStudy), onTap: onStudy),
          Expanded(
            child: _NavTile(
                def: _tabs[2],
                active: 2 == selectedIndex,
                onTap: () => onTap(2)),
          ),
          Expanded(
            child: _NavTile(
                def: _tabs[3],
                active: 3 == selectedIndex,
                onTap: () => onTap(3)),
          ),
        ],
      ),
    );
  }
}

// ── Raised centre "study" button ────────────────────────────────────────────

class _StudyButton extends StatelessWidget {
  const _StudyButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.clay,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.clay.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}

// ── Data + tiles ───────────────────────────────────────────────────────────────

class _SlotDef {
  const _SlotDef(this.icon, this.activeIcon, this.labelKey, this.tabIndex);
  final IconData icon;
  final IconData activeIcon;
  final String labelKey; // i18n key
  final int tabIndex; // 0–3
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.def,
    required this.active,
    required this.onTap,
  });

  final _SlotDef def;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? (isDark ? AppColors.onDark : AppColors.ink)
        : (isDark ? AppColors.onDarkFaint : AppColors.faint);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(active ? def.activeIcon : def.icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            def.labelKey.tr(),
            style: AppTextStyles.eyebrowSm.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
