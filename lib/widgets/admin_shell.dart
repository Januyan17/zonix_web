import 'package:flutter/material.dart';

import '../screens/auth_gate.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import 'zonix_badge.dart';

const double _wideBreakpoint = 900;
const double _railExtendedBreakpoint = 1200;

/// Responsive admin dashboard frame: a persistent side nav rail on wide
/// screens, a drawer + app bar on narrow/mobile screens. Wraps the
/// dashboard's body content; sub-pages (create/detail) stay as their own
/// pushed screens with a back button, outside this shell.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.authService,
    required this.shopService,
    required this.body,
    this.floatingActionButton,
  });

  final AuthService authService;
  final ShopService shopService;
  final Widget body;
  final Widget? floatingActionButton;

  Future<void> _logout(BuildContext context) async {
    await authService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AuthGate(authService: authService, shopService: shopService),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (isWide) {
          final extended = constraints.maxWidth >= _railExtendedBreakpoint;
          return Scaffold(
            body: Row(
              children: [
                _SideNav(extended: extended, onLogout: () => _logout(context)),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
            floatingActionButton: floatingActionButton,
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                ZonixBadge(size: 28),
                SizedBox(width: 10),
                Flexible(
                  child: Text('Zonix Admin', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          drawer: Drawer(
            child: SafeArea(
              child: _NavContent(onLogout: () => _logout(context)),
            ),
          ),
          body: body,
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.extended, required this.onLogout});

  final bool extended;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: extended ? 240 : 84,
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(child: _NavContent(extended: extended, onLogout: onLogout)),
    );
  }
}

class _NavContent extends StatelessWidget {
  const _NavContent({this.extended = true, required this.onLogout});

  final bool extended;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final brandRow = extended
        ? const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Row(
              children: [
                ZonixBadge(size: 34),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Zonix Admin',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: ZonixBadge(size: 34)),
          );

    final navItem = _NavItem(
      icon: Icons.storefront_rounded,
      label: 'Shops',
      selected: true,
      extended: extended,
    );

    final logoutItem = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _NavItem(
        icon: Icons.logout_rounded,
        label: 'Log out',
        selected: false,
        extended: extended,
        color: colorScheme.error,
        onTap: onLogout,
      ),
    );

    return Column(
      children: [
        brandRow,
        navItem,
        const Spacer(),
        const Divider(height: 1),
        logoutItem,
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = color ?? (selected ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final bg = selected ? colorScheme.primaryContainer.withValues(alpha: 0.6) : Colors.transparent;

    final content = Container(
      margin: EdgeInsets.symmetric(horizontal: extended ? 12 : 16, vertical: 3),
      padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 0, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: extended
          ? Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ],
            )
          : Icon(icon, size: 22, color: fg),
    );

    return Tooltip(
      message: extended ? '' : label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
