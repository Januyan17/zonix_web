import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';
import 'package:zonixweb/features/shops/models/shop_user.dart';

export 'package:zonixweb/core/widgets/zonix_chrome.dart';

/// Shop-detail specific chrome: the header title, the header tab bar and
/// the KPI pulse strip. The generic pieces live in core/widgets.

/// Shop name with a live status dot and the slug in a mono "terminal" tag.
class ShopHeaderTitle extends StatelessWidget {
  const ShopHeaderTitle({
    super.key,
    required this.title,
    required this.slug,
    required this.isActive,
  });

  final String title;
  final String slug;

  /// Null while the shop is still loading.
  final bool? isActive;

  @override
  Widget build(BuildContext context) {
    final active = isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppDimens.spacing4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacing8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                  border: Border.all(
                    color: ZonixColors.cyan.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '/$slug',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppDimens.fontCaption,
                    color: ZonixColors.cyan.withValues(alpha: 0.95),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
            if (active != null) ...[
              const SizedBox(width: AppDimens.spacing10),
              PulseDot(
                color: active ? ZonixColors.emerald : const Color(0xFFF59E0B),
                animate: active,
              ),
              const SizedBox(width: AppDimens.spacing6),
              Text(
                active ? 'ONLINE' : 'PAUSED',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Pill tab bar for the shop header.
class ShopHeaderTabBar extends StatelessWidget implements PreferredSizeWidget {
  const ShopHeaderTabBar({super.key, required this.tabs});

  final List<({IconData icon, String label})> tabs;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return ZonixPillTabBar(
      tabs: [
        for (final t in tabs) ZonixTabLabel(icon: Icon(t.icon), label: t.label),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pulse strip (KPIs)
// ---------------------------------------------------------------------------

/// Read-only KPI tiles across the top of the details tab. Everything shown
/// is derived from data the screen already holds; nothing here is tappable.
class ShopPulseStrip extends StatelessWidget {
  const ShopPulseStrip({
    super.key,
    required this.shop,
    required this.users,
    required this.staffCount,
    required this.productCount,
  });

  final Shop shop;
  final List<ShopUser> users;
  final int staffCount;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final liveUsers = users.where((u) => !u.isDeleted).toList();
    final enabled = liveUsers.where((u) => u.isEnabled).length;
    final now = DateTime.now();
    final trial = shop.trial;
    final trialState = trial.stateAt(now);

    final (
      String trialValue,
      String trialCaption,
      Color trialColor,
    ) = switch (trialState) {
      ShopTrialState.off => ('Off', 'No trial running', ZonixColors.chartBlue),
      ShopTrialState.active => (
        '${trial.daysLeftAt(now) ?? '—'}d',
        'Trial time left',
        ZonixColors.cyan,
      ),
      ShopTrialState.ended => ('Ended', 'App locked', const Color(0xFFDC2626)),
    };

    final tiles = <Widget>[
      _PulseTile(
        icon: Icons.bolt_rounded,
        label: 'Status',
        value: shop.isActive ? 'Active' : 'Inactive',
        caption: shop.isActive ? 'Mobile login open' : 'Mobile login blocked',
        color: shop.isActive ? ZonixColors.emerald : const Color(0xFFF59E0B),
        live: shop.isActive,
      ),
      _PulseTile(
        icon: Icons.group_rounded,
        label: 'Users',
        value: '$enabled',
        valueSuffix: '/${liveUsers.length}',
        caption: 'Can sign in',
        color: ZonixColors.chartBlue,
        progress: liveUsers.isEmpty ? null : enabled / liveUsers.length,
      ),
      _PulseTile(
        icon: Icons.groups_2_rounded,
        label: 'Staff seats',
        value: '$staffCount',
        valueSuffix: '/${shop.staffLimit ?? '∞'}',
        caption: shop.staffLimit == null ? 'Unlimited' : 'Seats used',
        color: ZonixColors.emerald,
        progress: _ratio(staffCount, shop.staffLimit),
      ),
      _PulseTile(
        icon: Icons.inventory_2_rounded,
        label: 'Products',
        value: '$productCount',
        valueSuffix: '/${shop.productLimit ?? '∞'}',
        caption: shop.productLimit == null ? 'Unlimited' : 'Catalog used',
        color: ZonixColors.cyan,
        progress: _ratio(productCount, shop.productLimit),
      ),
      _PulseTile(
        icon: Icons.hourglass_top_rounded,
        label: 'Free trial',
        value: trialValue,
        caption: trialCaption,
        color: trialColor,
      ),
      _PulseTile(
        icon: Icons.devices_rounded,
        label: 'Device cap',
        value: '${shop.maxActiveDevicesStaff}',
        valueSuffix: ' · ${shop.maxActiveDevicesOwner}',
        caption: 'Staff · Owner per user',
        color: ZonixColors.navy,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final columns = w >= 1100
            ? 6
            : w >= 720
            ? 3
            : 2;
        const gap = AppDimens.spacing12;
        final tileWidth = (w - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles) SizedBox(width: tileWidth, child: t),
          ],
        );
      },
    );
  }

  static double? _ratio(int used, int? limit) {
    if (limit == null || limit <= 0) return null;
    return (used / limit).clamp(0.0, 1.0);
  }
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    this.valueSuffix,
    this.progress,
    this.live = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? valueSuffix;
  final String caption;
  final Color color;
  final double? progress;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final p = progress;
    final over = p != null && p >= 1;
    final barColor = over ? const Color(0xFFDC2626) : color;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: color.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: AppDimens.iconSm, color: color),
              ),
              const SizedBox(width: AppDimens.spacing8),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (live) PulseDot(color: color),
            ],
          ),
          const SizedBox(height: AppDimens.spacing12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: ZonixColors.navy,
                    height: 1.0,
                  ),
                ),
                if (valueSuffix != null)
                  TextSpan(
                    text: valueSuffix,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimens.spacing6),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppDimens.fontCaption,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.spacing10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: color.withValues(alpha: 0.10)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: p ?? 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: p == null
                              ? [
                                  color.withValues(alpha: 0.15),
                                  color.withValues(alpha: 0.55),
                                ]
                              : [barColor.withValues(alpha: 0.6), barColor],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
