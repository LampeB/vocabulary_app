import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

final _connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
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
                          children: const [
                            Icon(Icons.wifi_off, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'No internet connection — changes will sync when back online',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12),
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
          // Frosted bottom nav — bar + raised clay FAB.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _VkBottomNav(
              selectedIndex: selected,
              onTap: (slot) {
                // Slot 2 is the centre FAB → go to lists to pick a study list.
                const dests = ['/home', '/lists', '/lists', '/social', '/profile'];
                context.go(dests[slot]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Constants ──────────────────────────────────────────────────────────────────

const _kBarHeight   = 92.0;
const _kFabSize     = 56.0;
const _kFabProtrude = _kFabSize / 2; // pixels above the bar top

// ── Nav widget ─────────────────────────────────────────────────────────────────

class _VkBottomNav extends StatelessWidget {
  const _VkBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex; // 0–3, maps to AppShell._routes
  final void Function(int visualSlot) onTap; // 0–4

  static const List<_SlotDef?> _slots = [
    _SlotDef(Icons.home_outlined,         Icons.home_rounded,          'ACCUEIL', 0),
    _SlotDef(Icons.bookmark_border,       Icons.bookmark,              'LISTES',  1),
    null, // centre slot — occupied by the raised FAB
    _SlotDef(Icons.emoji_events_outlined, Icons.emoji_events_rounded,  'AMIS',    2),
    _SlotDef(Icons.person_outline_rounded, Icons.person_rounded,       'PROFIL',  3),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _kFabProtrude + _kBarHeight + safeBottom,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Frosted bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _kBarHeight + safeBottom,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFAF6F1EA), // paper @ 98 %
                border: Border(
                  top: BorderSide(color: AppColors.line, width: 1),
                ),
              ),
              padding: EdgeInsets.only(bottom: safeBottom),
              child: Row(
                children: [
                  for (int i = 0; i < _slots.length; i++)
                    if (_slots[i] == null)
                      const Expanded(child: SizedBox()) // FAB gutter
                    else
                      Expanded(
                        child: _NavTile(
                          def: _slots[i]!,
                          active: _slots[i]!.tabIndex == selectedIndex,
                          onTap: () => onTap(i),
                        ),
                      ),
                ],
              ),
            ),
          ),
          // Raised clay study FAB — straddles the bar's top edge.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: _kFabSize,
                  height: _kFabSize,
                  decoration: BoxDecoration(
                    color: AppColors.clay,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.clay.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data + tiles ───────────────────────────────────────────────────────────────

class _SlotDef {
  const _SlotDef(this.icon, this.activeIcon, this.label, this.tabIndex);
  final IconData icon;
  final IconData activeIcon;
  final String label; // already UPPERCASE
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
    final color = active ? AppColors.ink : AppColors.faint;
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
            def.label,
            style: AppTextStyles.eyebrowSm.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
