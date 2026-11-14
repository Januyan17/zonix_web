import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/widgets/zonix_badge.dart';
import 'package:zonixweb/features/billing/services/billing_service.dart';
import 'package:zonixweb/features/billing/services/trial_overview.dart';
import 'package:zonixweb/features/history_requests/services/history_request_service.dart';
import 'package:zonixweb/features/shell/models/admin_page.dart';
import 'package:zonixweb/features/shell/widgets/admin_nav_item.dart';

class AdminSideNav extends StatelessWidget {
  const AdminSideNav({
    super.key,
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
        child: AdminNavContent(
          extended: extended,
          current: current,
          onNavigate: onNavigate,
          onLogout: onLogout,
        ),
      ),
    );
  }
}

/// Overdue/due-soon monthly payments plus ended free trials. One shared
/// object, so rebuilding the nav doesn't re-subscribe the listeners.
final Listenable _paymentsBadgeSource = Listenable.merge([
  ShopBillingOverview.instance,
  TrialOverview.instance,
]);

String? _countLabel(int count) => count <= 0 ? null : '$count';

/// The pending-requests bubble text: null (no bubble) at 0, and "50+" at
/// the listener's limit, since it can't see past it.
String? _pendingLabel(int count) {
  if (count <= 0) return null;
  const limit = HistoryRequestService.pendingLimit;
  return count >= limit ? '$limit+' : '$count';
}

class AdminNavContent extends StatelessWidget {
  const AdminNavContent({
    super.key,
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
      AdminNavItem(
        icon: Icons.storefront_rounded,
        label: 'Shops',
        selected: current == AdminPage.shops,
        extended: extended,
        onTap: () => onNavigate(AdminPage.shops),
      ),
      AdminNavItem(
        icon: Icons.insights_rounded,
        label: 'Overview',
        selected: current == AdminPage.overview,
        extended: extended,
        onTap: () => onNavigate(AdminPage.overview),
      ),
      // Overdue / due-soon shop payments, from one shared listener.
      ListenableBuilder(
        listenable: _paymentsBadgeSource,
        builder: (context, _) => AdminNavItem(
          icon: Icons.payments_outlined,
          label: 'Payments',
          selected: current == AdminPage.payments,
          extended: extended,
          badgeLabel: _countLabel(
            ShopBillingOverview.instance.attentionCount +
                TrialOverview.instance.endedCount,
          ),
          onTap: () => onNavigate(AdminPage.payments),
        ),
      ),
      AdminNavItem(
        icon: Icons.system_update_rounded,
        label: 'App version',
        selected: current == AdminPage.appVersion,
        extended: extended,
        onTap: () => onNavigate(AdminPage.appVersion),
      ),
      AdminNavItem(
        icon: Icons.phonelink_lock_rounded,
        label: 'Device logins',
        selected: current == AdminPage.deviceLogins,
        extended: extended,
        onTap: () => onNavigate(AdminPage.deviceLogins),
      ),
      // The badge listens to the one shared pending-requests listener, so
      // rebuilding the shell on every page change doesn't re-subscribe.
      ListenableBuilder(
        listenable: PendingHistoryRequests.instance,
        builder: (context, _) => AdminNavItem(
          icon: Icons.manage_history_rounded,
          label: 'History requests',
          selected: current == AdminPage.historyRequests,
          extended: extended,
          badgeLabel: _pendingLabel(PendingHistoryRequests.instance.count),
          onTap: () => onNavigate(AdminPage.historyRequests),
        ),
      ),
    ];

    final logoutItem = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing12),
      child: AdminNavItem(
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
