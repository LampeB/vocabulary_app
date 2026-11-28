import 'package:flutter/material.dart';

/// Exposes the route containing the shell's nested navigator. A nested route
/// can stay current inside that navigator when a root route covers the shell.
class ShellRouteVisibility extends StatelessWidget {
  const ShellRouteVisibility({super.key, required this.child});

  final Widget child;

  static ModalRoute<Object?>? routeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShellRouteScope>()?.route;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    return _ShellRouteScope(
      route: route,
      current: route?.isCurrent ?? true,
      child: child,
    );
  }
}

class _ShellRouteScope extends InheritedWidget {
  const _ShellRouteScope({
    required this.route,
    required this.current,
    required super.child,
  });

  final ModalRoute<Object?>? route;
  final bool current;

  @override
  bool updateShouldNotify(_ShellRouteScope oldWidget) =>
      route != oldWidget.route || current != oldWidget.current;
}
