import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/zonix_badge.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
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
    return SizedBox(
      width: extended ? 248 : 88,
      child: Stack(
        children: [
          const Positioned.fill(child: ZonixHeaderBackground(hairline: false)),
          // Neon edge on the rail's right side.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ZonixColors.cyan.withValues(alpha: 0.0),
                    ZonixColors.cyan.withValues(alpha: 0.7),
                    ZonixColors.emerald.withValues(alpha: 0.6),
                    ZonixColors.emerald.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: AdminNavContent(
              extended: extended,
              current: current,
              onNavigate: onNavigate,
              onLogout: onLogout,
            ),
          ),
        ],
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
    final brandMark = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ZonixColors.cyan.withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      ),
      child: const ZonixBadge(size: 36),
    );

    final brandRow = extended
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spacing20,
              28,
              AppDimens.spacing20,
              AppDimens.spacing24,
            ),
            child: Row(
              children: [
                brandMark,
                const SizedBox(width: AppDimens.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Zonix Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const PulseDot(color: ZonixColors.emerald),
                          const SizedBox(width: AppDimens.spacing4),
                          Flexible(
                            child: Text(
                              'CONTROL CENTER',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ZonixColors.cyan.withValues(alpha: 0.9),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(child: brandMark),
          );

    final sectionLabel = extended
        ? Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 20, AppDimens.spacing8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

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
        icon: Icons.hourglass_top_rounded,
        label: 'Trial settings',
        selected: current == AdminPage.trialSettings,
        extended: extended,
        onTap: () => onNavigate(AdminPage.trialSettings),
      ),
      AdminNavItem(
        icon: Icons.support_agent_rounded,
        label: 'Join contact',
        selected: current == AdminPage.joinContact,
        extended: extended,
        onTap: () => onNavigate(AdminPage.joinContact),
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
        color: const Color(0xFFFF8A8A),
        onTap: onLogout,
      ),
    );

    return Column(
      children: [
        brandRow,
        sectionLabel,
        ...navItems,
        const Spacer(),
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Colors.white.withValues(alpha: 0.10),
        ),
        logoutItem,
      ],
    );
  }
}
