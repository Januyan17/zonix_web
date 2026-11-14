import 'package:flutter/material.dart';

import '../models/shop_billing.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/shop_service.dart';
import '../services/trial_overview.dart';
import '../theme/app_dimens.dart';
import '../utils/date_format.dart';
import '../utils/money_format.dart';
import '../widgets/admin_shell.dart';
import '../widgets/billing_widgets.dart';
import 'free_trials_tab.dart';
import 'shop_detail/shop_detail_screen.dart';

/// Every shop's monthly payment status in one place, soonest due first:
/// the reminder list. Overdue and due-soon shops are also counted on the
/// nav badge. Shops are marked paid here or from their own Payments tab.
///
/// A second tab lists shops on a free trial, with ended trials (app locked,
/// payment to collect) first; those are counted on the nav badge too.
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    required this.authService,
    required this.shopService,
    this.billingService,
    this.initialTab = 0,
  });

  final AuthService authService;
  final ShopService shopService;
  final BillingService? billingService;

  /// 0 = Monthly payments, 1 = Free trials.
  final int initialTab;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late final BillingService _service =
      widget.billingService ?? BillingService();
  final _overview = ShopBillingOverview.instance;
  final _searchController = TextEditingController();

  /// Kept as one object so rebuilds don't re-subscribe the shared listener.
  late final Listenable _monthlyListenable = Listenable.merge([
    _overview,
    _searchController,
  ]);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openShop(String slug) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          slug: slug,
          shopService: widget.shopService,
          initialTab: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: widget.authService,
      shopService: widget.shopService,
      current: AdminPage.payments,
      body: DefaultTabController(
        length: 2,
        initialIndex: widget.initialTab,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                tabs: [
                  const Tab(
                    icon: Icon(Icons.payments_outlined),
                    text: 'Monthly payments',
                  ),
                  ListenableBuilder(
                    listenable: TrialOverview.instance,
                    builder: (context, _) {
                      final ended = TrialOverview.instance.endedCount;
                      return Tab(
                        icon: Badge(
                          isLabelVisible: ended > 0,
                          label: Text('$ended'),
                          child: const Icon(Icons.hourglass_top_rounded),
                        ),
                        text: 'Free trials',
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListenableBuilder(
                    listenable: _monthlyListenable,
                    builder: (context, _) => _buildBody(),
                  ),
                  FreeTrialsTab(
                    shopService: widget.shopService,
                    billingService: _service,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final entries = _overview.entries;

    final Widget content;
    if (_overview.error != null) {
      content = Card(
        child: Padding(
          padding: AppDimens.paddingAll20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Could not load payments.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppDimens.spacing8),
              SelectableText(
                _overview.error!,
                style: TextStyle(color: colorScheme.error),
              ),
              const SizedBox(height: AppDimens.spacing16),
              FilledButton(
                onPressed: _overview.retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (entries == null) {
      content = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      content = _buildLists(entries);
    }

    return ListView(
      padding: AppDimens.paddingAll24,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Monthly payments for every shop. When a customer pays, '
                  'mark it paid with the exact date and amount — the next '
                  'due date is set one month later, and the shop shows up '
                  'here again $kBillingDueSoonDays days before it\'s due.',
                  style: TextStyle(
                    fontSize: AppDimens.fontBody,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.spacing20),
                content,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLists(List<ShopBillingEntry> all) {
    final now = DateTime.now();
    final query = _searchController.text.trim().toLowerCase();
    final entries = query.isEmpty
        ? all
        : all
              .where(
                (e) =>
                    e.name.toLowerCase().contains(query) ||
                    e.slug.toLowerCase().contains(query),
              )
              .toList();

    int byDue(ShopBillingEntry a, ShopBillingEntry b) =>
        a.billing.nextDueAt!.compareTo(b.billing.nextDueAt!);

    final overdue =
        entries
            .where((e) => e.billing.dueStateAt(now) == BillingDueState.overdue)
            .toList()
          ..sort(byDue);
    final dueSoon =
        entries
            .where(
              (e) => switch (e.billing.dueStateAt(now)) {
                BillingDueState.dueToday || BillingDueState.dueSoon => true,
                _ => false,
              },
            )
            .toList()
          ..sort(byDue);
    final upcoming =
        entries
            .where((e) => e.billing.dueStateAt(now) == BillingDueState.upcoming)
            .toList()
          ..sort(byDue);
    final notSet =
        entries
            .where((e) => e.billing.dueStateAt(now) == BillingDueState.notSet)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final thisMonth = monthOf(now);
    final collectedThisMonth = all.fold<double>(
      0,
      (total, e) =>
          total +
          e.billing.payments
              .where((p) => monthOf(p.paidAt) == thisMonth)
              .fold<double>(0, (t, p) => t + p.amount),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimens.spacing12,
          runSpacing: AppDimens.spacing12,
          children: [
            _SummaryTile(
              icon: Icons.warning_amber_rounded,
              label: 'Overdue',
              value: '${overdue.length}',
              highlight: overdue.isNotEmpty,
            ),
            _SummaryTile(
              icon: Icons.notifications_outlined,
              label: 'Due in $kBillingDueSoonDays days',
              value: '${dueSoon.length}',
            ),
            _SummaryTile(
              icon: Icons.savings_outlined,
              label: 'Collected in ${monthLabel(thisMonth)}',
              value: formatMoney(collectedThisMonth),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing20),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search shops',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _searchController.clear,
                  ),
          ),
        ),
        const SizedBox(height: AppDimens.spacing8),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppDimens.spacing24),
            child: Center(child: Text('No shops found.')),
          ),
        _group('Overdue', Icons.warning_amber_rounded, overdue),
        _group('Due soon', Icons.notifications_outlined, dueSoon),
        _group('Paid up', Icons.check_circle_outline, upcoming),
        _group(
          'Billing not set up',
          Icons.event_busy_outlined,
          notSet,
          collapsed: true,
        ),
      ],
    );
  }

  Widget _group(
    String title,
    IconData icon,
    List<ShopBillingEntry> entries, {
    bool collapsed = false,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final tiles = Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ShopBillingTile(
              entry: entries[i],
              onOpen: () => _openShop(entries[i].slug),
              onMarkPaid: () => recordPaymentFlow(
                context,
                service: _service,
                slug: entries[i].slug,
                shopName: entries[i].name,
                billing: entries[i].billing,
              ),
            ),
          ],
        ],
      ),
    );
    final header = Row(
      children: [
        Icon(icon, size: AppDimens.iconLg, color: colorScheme.primary),
        const SizedBox(width: AppDimens.spacing8),
        Text(
          '$title (${entries.length})',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(top: AppDimens.spacing16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: header,
            children: [tiles],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: AppDimens.spacing10),
          tiles,
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = highlight ? colorScheme.onErrorContainer : colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: Card(
        color: highlight ? colorScheme.errorContainer : null,
        child: Padding(
          padding: AppDimens.paddingAll14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: AppDimens.spacing12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: AppDimens.fontTitle,
                      fontWeight: FontWeight.w700,
                      color: highlight ? fg : null,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: AppDimens.fontLabel,
                      color: highlight ? fg : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopBillingTile extends StatelessWidget {
  const _ShopBillingTile({
    required this.entry,
    required this.onOpen,
    required this.onMarkPaid,
  });

  final ShopBillingEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final billing = entry.billing;
    final last = billing.lastPayment;
    final details = [
      if (billing.nextDueAt != null)
        'Due ${formatShortDate(billing.nextDueAt!)}',
      if (billing.monthlyAmount != null) formatMoney(billing.monthlyAmount!),
      if (last != null) 'Last paid ${formatShortDate(last.paidAt)}',
      if (billing.paidThrough != null)
        'Paid until ${shortMonthLabel(billing.paidThrough!)}',
    ].join(' · ');

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: AppDimens.paddingH16V12,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimens.spacing4),
                  Wrap(
                    spacing: AppDimens.spacing8,
                    runSpacing: AppDimens.spacing4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      BillingDueBadge(billing: billing, compact: true),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          style: TextStyle(
                            fontSize: AppDimens.fontLabel,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spacing8),
            OutlinedButton.icon(
              onPressed: onMarkPaid,
              icon: const Icon(
                Icons.check_circle_outline,
                size: AppDimens.iconLg,
              ),
              label: const Text('Mark paid'),
            ),
          ],
        ),
      ),
    );
  }
}
