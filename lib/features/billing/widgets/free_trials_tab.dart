import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/billing/models/shop_billing.dart';
import 'package:zonixweb/features/billing/services/billing_service.dart';
import 'package:zonixweb/features/billing/services/trial_overview.dart';
import 'package:zonixweb/features/billing/widgets/record_payment_flow.dart';
import 'package:zonixweb/features/billing/widgets/trial_shop_tile.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';
import 'package:zonixweb/features/shops/screens/shop_detail_screen.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

/// The Payments page's "Free trials" tab: every shop currently on a free
/// trial, ended ones first. An ended trial means the shop's app is locked
/// and waiting for payment: "Collect payment" records it like any monthly
/// payment, then offers to switch the trial off so the app unlocks.
class FreeTrialsTab extends StatelessWidget {
  const FreeTrialsTab({
    super.key,
    required this.shopService,
    required this.billingService,
  });

  final ShopService shopService;
  final BillingService billingService;

  @override
  Widget build(BuildContext context) {
    final overview = TrialOverview.instance;
    return ListenableBuilder(
      listenable: overview,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final Widget content;
        if (overview.error != null) {
          content = Card(
            child: Padding(
              padding: AppDimens.paddingAll20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Could not load free trials.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppDimens.spacing8),
                  SelectableText(
                    overview.error!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                  const SizedBox(height: AppDimens.spacing16),
                  FilledButton(
                    onPressed: overview.retry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        } else if (overview.loading) {
          content = const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          );
        } else {
          content = _buildGroups(context, overview.trialShops);
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
                      'Shops on a free trial. When a trial ends the shop\'s '
                      'app is locked — collect the payment, then switch the '
                      'trial off to unlock it.',
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
      },
    );
  }

  Widget _buildGroups(BuildContext context, List<Shop> shops) {
    final now = DateTime.now();
    // Unknown end (start timestamp still pending) sorts last.
    int byEnd(Shop a, Shop b) {
      final ea = a.trial.endsAt, eb = b.trial.endsAt;
      if (ea == null) return eb == null ? 0 : 1;
      if (eb == null) return -1;
      return ea.compareTo(eb);
    }

    final ended =
        shops
            .where((s) => s.trial.stateAt(now) == ShopTrialState.ended)
            .toList()
          ..sort(byEnd);
    final active = shops
        .where((s) => s.trial.stateAt(now) == ShopTrialState.active)
        .toList();
    bool endingSoon(Shop s) {
      final left = s.trial.daysLeftAt(now);
      return left != null && left <= kTrialEndingSoonDays;
    }

    final soon = active.where(endingSoon).toList()..sort(byEnd);
    final later = active.where((s) => !endingSoon(s)).toList()..sort(byEnd);

    if (shops.isEmpty) {
      return Card(
        child: Padding(
          padding: AppDimens.paddingAll24,
          child: Center(
            child: Text(
              'No shops are on a free trial.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _group(
          context,
          'Trial ended — collect payment',
          Icons.lock_outline,
          ended,
        ),
        _group(
          context,
          'Ending in $kTrialEndingSoonDays days or less',
          Icons.hourglass_bottom_rounded,
          soon,
        ),
        _group(context, 'Active trials', Icons.hourglass_top_rounded, later),
      ],
    );
  }

  Widget _group(
    BuildContext context,
    String title,
    IconData icon,
    List<Shop> shops,
  ) {
    if (shops.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(icon: icon, label: '$title (${shops.length})'),
          const SizedBox(height: AppDimens.spacing10),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < shops.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  TrialShopTile(
                    shop: shops[i],
                    onOpen: () => _openShop(context, shops[i].id),
                    onCollect: () => _collectPayment(context, shops[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openShop(BuildContext context, String slug) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(slug: slug, shopService: shopService),
      ),
    );
  }

  Future<void> _collectPayment(BuildContext context, Shop shop) async {
    final billing =
        ShopBillingOverview.instance.entries
            ?.where((e) => e.slug == shop.id)
            .firstOrNull
            ?.billing ??
        const ShopBilling();
    final saved = await recordPaymentFlow(
      context,
      service: billingService,
      slug: shop.id,
      shopName: shop.name,
      billing: billing,
    );
    if (!saved || !context.mounted) return;

    final turnOff = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch off the free trial?'),
        content: Text(
          'Payment saved for ${shop.name}. Switch the free trial off now? '
          'This unlocks the shop\'s app straight away.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep trial on'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Switch off & unlock'),
          ),
        ],
      ),
    );
    if (turnOff != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await shopService.endTrial(shop.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Free trial switched off for ${shop.name}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to switch off trial: ${describeError(e)}'),
        ),
      );
    }
  }
}
