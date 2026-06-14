import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    _Tab(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Today',
        path: '/home'),
    _Tab(
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: 'Lists',
        path: '/lists'),
    _Tab(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Social',
        path: '/social'),
    _Tab(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile',
        path: '/profile'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selectedIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;
}
