import 'package:flutter/material.dart';

import '../screens/app_version_screen.dart';
import '../screens/auth_gate.dart';
import '../screens/platform_overview_screen.dart';
import '../screens/shop_list_screen.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../theme/app_dimens.dart';
import 'zonix_badge.dart';

const double _wideBreakpoint = 900;
const double _railExtendedBreakpoint = 1200;

/// The top-level pages the nav rail switches between. Each one wraps itself
/// in an [AdminShell] and names itself here, so the rail highlights the
/// right entry without the shell having to inspect the route.
enum AdminPage { shops, overview, appVersion }

/// Responsive admin dashboard frame: a persistent side nav rail on wide
/// screens, a drawer + app bar on narrow/mobile screens. Wraps the
/// dashboard's body content; sub-pages (create/detail) stay as their own
/// pushed screens with a back button, outside this shell.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.authService,
    required this.shopService,
    required this.current,
    required this.body,
    this.floatingActionButton,
  });

  final AuthService authService;
  final ShopService shopService;
  final AdminPage current;
  final Widget body;
  final Widget? floatingActionButton;

  Future<void> _logout(BuildContext context) async {
    await authService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              AuthGate(authService: authService, shopService: shopService),
        ),
        (route) => false,
      );
    }
  }

  /// Switches between top-level pages with pushReplacement rather than
  /// push, so hopping between Shops and App version doesn't build a stack
  /// of shells behind the current one. Sub-pages (create/detail) are still
  /// pushed on top and keep their back button.
  void _navigate(BuildContext context, AdminPage target) {
    if (target == current) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => switch (target) {
          AdminPage.shops => ShopListScreen(
            authService: authService,
            shopService: shopService,
          ),
          AdminPage.overview => PlatformOverviewScreen(
            authService: authService,
            shopService: shopService,
          ),
          AdminPage.appVersion => AppVersionScreen(
            authService: authService,
            shopService: shopService,
          ),
        },
      ),
    );
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
                _SideNav(
                  extended: extended,
                  current: current,
                  onNavigate: (page) => _navigate(context, page),
                  onLogout: () => _logout(context),
                ),
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
                SizedBox(width: AppDimens.spacing10),
                Flexible(
                  child: Text('Zonix Admin', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          drawer: Drawer(
            child: SafeArea(
              child: _NavContent(
                current: current,
                onNavigate: (page) => _navigate(context, page),
                onLogout: () => _logout(context),
              ),
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
  const _SideNav({
    required this.extended,
    required this.current,
    required this.onNavigate,
    required this.onLogout,
  });

  final bool extended;
  final AdminPage current;
  final ValueChanged<AdminPage> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: extended ? 240 : 84,
      color: colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: _NavContent(
          extended: extended,
          current: current,
          onNavigate: onNavigate,
          onLogout: onLogout,
        ),
      ),
    );
  }
}

class _NavContent extends StatelessWidget {
  const _NavContent({
    this.extended = true,
    required this.current,
    required this.onNavigate,
    required this.onLogout,
  });

  final bool extended;
  final AdminPage current;
  final ValueChanged<AdminPage> onNavigate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final brandRow = extended
        ? const Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spacing20,
              AppDimens.spacing24,
              AppDimens.spacing20,
              AppDimens.spacing24,
            ),
            child: Row(
              children: [
                ZonixBadge(size: 34),
                SizedBox(width: AppDimens.spacing12),
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
            padding: EdgeInsets.symmetric(vertical: AppDimens.spacing24),
            child: Center(child: ZonixBadge(size: 34)),
          );

    final navItems = [
      _NavItem(
        icon: Icons.storefront_rounded,
        label: 'Shops',
        selected: current == AdminPage.shops,
        extended: extended,
        onTap: () => onNavigate(AdminPage.shops),
      ),
      _NavItem(
        icon: Icons.insights_rounded,
        label: 'Overview',
        selected: current == AdminPage.overview,
        extended: extended,
        onTap: () => onNavigate(AdminPage.overview),
      ),
      _NavItem(
        icon: Icons.system_update_rounded,
        label: 'App version',
        selected: current == AdminPage.appVersion,
        extended: extended,
        onTap: () => onNavigate(AdminPage.appVersion),
      ),
    ];

    final logoutItem = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing12),
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
        ...navItems,
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
    final fg =
        color ??
        (selected ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final bg = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.6)
        : Colors.transparent;

    final content = Container(
      margin: EdgeInsets.symmetric(
        horizontal: extended ? AppDimens.spacing12 : AppDimens.spacing16,
        vertical: 3,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: extended ? AppDimens.spacing14 : 0,
        vertical: AppDimens.spacing12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      ),
      child: extended
          ? Row(
              children: [
                Icon(icon, size: AppDimens.iconXl, color: fg),
                const SizedBox(width: AppDimens.spacing12),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: AppDimens.fontBodyLg,
                  ),
                ),
              ],
            )
          : Icon(icon, size: AppDimens.iconXxl, color: fg),
    );

    return Tooltip(
      message: extended ? '' : label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
