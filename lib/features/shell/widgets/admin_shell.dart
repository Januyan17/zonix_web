import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/zonix_badge.dart';
import 'package:zonixweb/features/app_version/screens/app_version_screen.dart';
import 'package:zonixweb/features/auth/screens/auth_gate.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/billing/screens/payments_screen.dart';
import 'package:zonixweb/features/device_logins/screens/device_logins_screen.dart';
import 'package:zonixweb/features/history_requests/screens/history_requests_screen.dart';
import 'package:zonixweb/features/overview/screens/platform_overview_screen.dart';
import 'package:zonixweb/features/shell/models/admin_page.dart';
import 'package:zonixweb/features/shell/widgets/admin_nav.dart';
import 'package:zonixweb/features/shops/screens/shop_list_screen.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

export 'package:zonixweb/features/shell/models/admin_page.dart';

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
          AdminPage.payments => PaymentsScreen(
            authService: authService,
            shopService: shopService,
          ),
          AdminPage.appVersion => AppVersionScreen(
            authService: authService,
            shopService: shopService,
          ),
          AdminPage.deviceLogins => DeviceLoginsScreen(
            authService: authService,
            shopService: shopService,
          ),
          AdminPage.historyRequests => HistoryRequestsScreen(
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
                AdminSideNav(
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
              child: AdminNavContent(
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
