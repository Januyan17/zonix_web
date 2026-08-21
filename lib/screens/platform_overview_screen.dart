import 'package:flutter/material.dart';

import '../models/app_version_config.dart';
import '../models/platform_stats.dart';
import '../models/shop_stats.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/platform_stats_service.dart';
import '../services/shop_service.dart';
import '../theme/app_dimens.dart';
import '../theme/zonix_colors.dart';
import '../utils/date_format.dart';
import '../utils/error_utils.dart';
import '../utils/money_format.dart';
import '../widgets/admin_shell.dart';
import '../widgets/shop_growth_chart.dart';
import '../widgets/trend_chart.dart';
import 'shop_detail/shop_detail_screen.dart';
import 'shop_detail/widgets/stat_widgets.dart';

/// Platform-wide analytics: growth, per-shop health and churn risk, feature
/// adoption, and update-gate adoption — the things a platform admin needs
/// that no single shop's page can answer.
///
/// The page loads its cheap tier automatically. Revenue across every shop
/// sits behind a button on purpose: it reads every transaction document of
/// every shop, which grows without bound as history accumulates, and is not
/// something a page should do just because someone opened it.
class PlatformOverviewScreen extends StatefulWidget {
  const PlatformOverviewScreen({
    super.key,
    required this.authService,
    required this.shopService,
    this.statsService,
    this.appVersionService,
  });

  final AuthService authService;
  final ShopService shopService;
  final PlatformStatsService? statsService;
  final AppVersionService? appVersionService;

  @override
  State<PlatformOverviewScreen> createState() => _PlatformOverviewScreenState();
}

class _PlatformOverviewScreenState extends State<PlatformOverviewScreen> {
  late final PlatformStatsService _stats =
      widget.statsService ?? PlatformStatsService();
  late final AppVersionService _appVersion =
      widget.appVersionService ?? AppVersionService();

  bool _loading = true;
  String? _loadError;
  PlatformHealth? _health;
  AppVersionConfig? _versionConfig;

  bool _computingVolume = false;
  String? _volumeError;
  int _volumeDone = 0;
  int _volumeTotal = 0;
  PlatformVolume? _volume;

  /// Window for the on-demand volume scan. 30 days keeps the first run
  /// small; the totals are filtered client-side either way.
  static const _volumeDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // The update gate is read alongside, so build adoption can be shown
      // against the floor that is actually published rather than in a
      // vacuum. A missing document is fine and means no gate is set.
      final results = await Future.wait([
        _stats.loadHealth(),
        _appVersion.read().catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _health = results[0] as PlatformHealth;
        _versionConfig = results[1] as AppVersionConfig?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = describeError(e);
        _loading = false;
      });
    }
  }

  Future<void> _computeVolume() async {
    setState(() {
      _computingVolume = true;
      _volumeError = null;
      _volumeDone = 0;
      _volumeTotal = _health?.totalShops ?? 0;
    });
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: _volumeDays - 1));
      final volume = await _stats.computeVolume(
        range: StatsDateRange(start: start, end: end),
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _volumeDone = done;
            _volumeTotal = total;
          });
        },
      );
      if (!mounted) return;
      setState(() => _volume = volume);
    } catch (e) {
      if (!mounted) return;
      setState(() => _volumeError = describeError(e));
    } finally {
      if (mounted) setState(() => _computingVolume = false);
    }
  }

  void _openShop(String slug) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          slug: slug,
          shopService: widget.shopService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: widget.authService,
      shopService: widget.shopService,
      current: AdminPage.overview,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: AppDimens.paddingAll24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load platform stats.\n$_loadError'),
              const SizedBox(height: AppDimens.spacing16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final health = _health!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: AppDimens.paddingAll24,
        children: [
          _Header(loadedAt: health.loadedAt, onRefresh: _load),
          const SizedBox(height: AppDimens.spacing16),
          _SummaryTiles(health: health),
          const SizedBox(height: AppDimens.spacing16),
          ShopGrowthChart(loading: false, points: health.growth),
          const SizedBox(height: AppDimens.spacing16),
          _ShopHealthCard(health: health, onOpenShop: _openShop),
          const SizedBox(height: AppDimens.spacing16),
          _FeatureAdoptionCard(features: health.features),
          const SizedBox(height: AppDimens.spacing16),
          _BuildAdoptionCard(
            builds: health.builds,
            config: _versionConfig,
          ),
          const SizedBox(height: AppDimens.spacing16),
          _VolumeCard(
            volume: _volume,
            computing: _computingVolume,
            done: _volumeDone,
            total: _volumeTotal,
            error: _volumeError,
            days: _volumeDays,
            onCompute: _computingVolume ? null : _computeVolume,
            onOpenShop: _openShop,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.loadedAt, required this.onRefresh});

  final DateTime loadedAt;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Platform overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimens.spacing2),
              Text(
                'Loaded ${formatRelativeDate(loadedAt).toLowerCase()}',
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: AppDimens.iconLg),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.health});

  final PlatformHealth health;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stale = health.stale().length;
    final nearLimit = health.nearLimit.length;

    return Wrap(
      spacing: AppDimens.spacing10,
      runSpacing: AppDimens.spacing10,
      children: [
        StatTile(
          icon: Icons.storefront_outlined,
          label: 'Total shops',
          value: '${health.totalShops}',
          color: colorScheme.primary,
          containerColor: colorScheme.primaryContainer,
        ),
        StatTile(
          icon: Icons.check_circle_outline,
          label: 'Active',
          value: '${health.activeShops}',
          color: colorScheme.tertiary,
          containerColor: colorScheme.tertiaryContainer,
        ),
        StatTile(
          icon: Icons.trending_down_rounded,
          label: 'Needs attention',
          value: '$stale',
          color: stale > 0 ? colorScheme.error : colorScheme.onSurfaceVariant,
          containerColor: stale > 0
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainerHighest,
        ),
        StatTile(
          icon: Icons.speed_rounded,
          label: 'Near a limit',
          value: '$nearLimit',
          color: nearLimit > 0
              ? ZonixColors.chartBlue
              : colorScheme.onSurfaceVariant,
          containerColor: nearLimit > 0
              ? ZonixColors.cyanContainer
              : colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

/// Per-shop liveness and cap utilization — the churn-risk and upsell view.
/// Sorted worst-first so the shops that need attention are at the top
/// rather than wherever alphabetical order happens to put them.
class _ShopHealthCard extends StatelessWidget {
  const _ShopHealthCard({required this.health, required this.onOpenShop});

  final PlatformHealth health;
  final ValueChanged<String> onOpenShop;

  static int _severity(ShopActivity activity) => switch (activity) {
    ShopActivity.dormant => 0,
    ShopActivity.neverSold => 1,
    ShopActivity.quiet => 2,
    ShopActivity.live => 3,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final shops = [...health.shops]
      ..sort((a, b) {
        final bySeverity = _severity(
          a.activity(now: now),
        ).compareTo(_severity(b.activity(now: now)));
        if (bySeverity != 0) return bySeverity;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Shop health',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'A till that stops ringing is the earliest sign of churn. '
              'Sorted by how long it has been quiet.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing12),
            if (shops.isEmpty)
              Text(
                'No shops yet.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              for (final shop in shops) ...[
                const Divider(height: 1),
                _ShopHealthRow(
                  shop: shop,
                  now: now,
                  onTap: () => onOpenShop(shop.slug),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ShopHealthRow extends StatelessWidget {
  const _ShopHealthRow({
    required this.shop,
    required this.now,
    required this.onTap,
  });

  final ShopHealth shop;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activity = shop.activity(now: now);
    final days = shop.daysSinceLastSale(now: now);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing10),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppDimens.spacing12,
          runSpacing: AppDimens.spacing8,
          children: [
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppDimens.fontBodyLg,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!shop.isActive)
                    Text(
                      'Shop deactivated',
                      style: TextStyle(
                        fontSize: AppDimens.fontCaption,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            _ActivityChip(activity: activity, days: days),
            _UtilizationText(
              icon: Icons.badge_outlined,
              used: shop.staffCount,
              limit: shop.staffLimit,
              unit: 'staff',
            ),
            _UtilizationText(
              icon: Icons.inventory_2_outlined,
              used: shop.productCount,
              limit: shop.productLimit,
              unit: 'products',
            ),
          ],
        ),
      ),
    );
  }
}

/// Status is never carried by color alone — every state ships with its own
/// icon and its own words, so it survives a colorblind reader, a greyscale
/// print, and a screenshot pasted into chat.
class _ActivityChip extends StatelessWidget {
  const _ActivityChip({required this.activity, required this.days});

  final ShopActivity activity;
  final int? days;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (IconData icon, Color color, Color background, String label) =
        switch (activity) {
          ShopActivity.live => (
            Icons.check_circle_outline,
            colorScheme.onTertiaryContainer,
            colorScheme.tertiaryContainer.withValues(alpha: 0.6),
            days == 0 ? 'Sold today' : 'Sold ${days}d ago',
          ),
          ShopActivity.quiet => (
            Icons.schedule_rounded,
            ZonixColors.onCyanContainer,
            ZonixColors.cyanContainer,
            'Quiet ${days}d',
          ),
          ShopActivity.dormant => (
            Icons.warning_amber_rounded,
            colorScheme.onErrorContainer,
            colorScheme.errorContainer,
            'Dormant ${days}d',
          ),
          ShopActivity.neverSold => (
            Icons.remove_circle_outline,
            colorScheme.onSurfaceVariant,
            colorScheme.surfaceContainerHighest,
            'Never sold',
          ),
        };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing8,
        vertical: AppDimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.iconXs, color: color),
          const SizedBox(width: AppDimens.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: AppDimens.fontCaption,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilizationText extends StatelessWidget {
  const _UtilizationText({
    required this.icon,
    required this.used,
    required this.limit,
    required this.unit,
  });

  final IconData icon;
  final int used;
  final int? limit;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final atRisk = limit != null && limit! > 0 && used / limit! >= 0.8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppDimens.iconXs, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppDimens.spacing6),
        Text(
          limit == null ? '$used $unit' : '$used / $limit $unit',
          style: TextStyle(
            fontSize: AppDimens.fontLabel,
            fontWeight: atRisk ? FontWeight.w700 : FontWeight.w400,
            color: atRisk ? colorScheme.error : colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FeatureAdoptionCard extends StatelessWidget {
  const _FeatureAdoptionCard({required this.features});

  final FeatureAdoption features;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = features.totalShops;

    final rows = [
      ('Shop links editable', features.shopLinksEnabled),
      ('Staff delete allowed', features.staffDeleteEnabled),
      ('Staff limit set', features.staffLimitSet),
      ('Product limit set', features.productLimitSet),
      ('Staff multi-device', features.multiDeviceStaff),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Feature adoption',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'How many of your $total shop${total == 1 ? '' : 's'} have each '
              'optional setting turned on.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing14),
            for (final (label, count) in rows) ...[
              _ProportionRow(label: label, count: count, total: total),
              const SizedBox(height: AppDimens.spacing10),
            ],
          ],
        ),
      ),
    );
  }
}

/// A labelled proportion bar. The count is always printed beside it, so the
/// bar is a second encoding of the number rather than the only one.
class _ProportionRow extends StatelessWidget {
  const _ProportionRow({
    required this.label,
    required this.count,
    required this.total,
  });

  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : count / total;

    return Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppDimens.fontBody,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation(ZonixColors.chartBlue),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacing12),
        SizedBox(
          width: 56,
          child: Text(
            '$count / $total',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: AppDimens.fontLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Which build each device is on, cross-referenced against the published
/// update gate. Empty until the mobile app starts writing its build number
/// onto the user document it already syncs — which is a change in the app
/// repo, not here, so the card says so instead of showing a blank chart.
class _BuildAdoptionCard extends StatelessWidget {
  const _BuildAdoptionCard({required this.builds, required this.config});

  final BuildAdoption builds;
  final AppVersionConfig? config;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update adoption',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'Which build each device is on, so raising the floor on the '
              'App Version page stops being a guess.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing14),
            if (!builds.hasData)
              _EmptyNote(
                icon: Icons.info_outline,
                text:
                    'No device reports a build number yet '
                    '(${builds.usersWithoutBuild} user record'
                    '${builds.usersWithoutBuild == 1 ? '' : 's'} checked). '
                    'This fills in on its own once the mobile app writes its '
                    'build number onto shops/{shopId}/users/{uid} — a change '
                    'in the app repo, not this one.',
              )
            else ...[
              for (final build in builds.buildsDescending) ...[
                _BuildRow(
                  buildNumber: build,
                  devices: builds.devicesByBuild[build]!,
                  totalDevices: builds.reportingDevices,
                  config: config,
                ),
                const SizedBox(height: AppDimens.spacing10),
              ],
              if (config != null && config!.minSupportedBuild > 0) ...[
                const Divider(height: AppDimens.spacing20),
                Text(
                  'The published floor is build ${config!.minSupportedBuild}. '
                  '${builds.blockedBy(config!.minSupportedBuild)} of '
                  '${builds.reportingDevices} reporting devices would be '
                  'blocked right now.',
                  style: TextStyle(
                    fontSize: AppDimens.fontBody,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (builds.usersWithoutBuild > 0) ...[
                const SizedBox(height: AppDimens.spacing8),
                Text(
                  '${builds.usersWithoutBuild} user record'
                  '${builds.usersWithoutBuild == 1 ? '' : 's'} report no '
                  'build — most likely a device that has not signed in since '
                  'build reporting shipped.',
                  style: TextStyle(
                    fontSize: AppDimens.fontCaption,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _BuildRow extends StatelessWidget {
  const _BuildRow({
    required this.buildNumber,
    required this.devices,
    required this.totalDevices,
    required this.config,
  });

  final int buildNumber;
  final int devices;
  final int totalDevices;
  final AppVersionConfig? config;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final min = config?.minSupportedBuild ?? 0;
    final latest = config?.latestBuild ?? 0;

    // Reserved status colors, each paired with an icon and words.
    final (IconData icon, Color color, String note) = buildNumber < min
        ? (Icons.block_rounded, colorScheme.error, 'blocked now')
        : (buildNumber < latest
              ? (
                  Icons.arrow_upward_rounded,
                  ZonixColors.onCyanContainer,
                  'update available',
                )
              : (
                  Icons.check_circle_outline,
                  colorScheme.onTertiaryContainer,
                  'current',
                ));

    return Row(
      children: [
        Icon(icon, size: AppDimens.iconSm, color: color),
        const SizedBox(width: AppDimens.spacing8),
        SizedBox(
          width: 96,
          child: Text(
            'Build $buildNumber',
            style: const TextStyle(
              fontSize: AppDimens.fontBody,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
            child: LinearProgressIndicator(
              value: totalDevices == 0 ? 0 : devices / totalDevices,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spacing12),
        SizedBox(
          width: 128,
          child: Text(
            '$devices device${devices == 1 ? '' : 's'} · $note',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: AppDimens.fontCaption,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The expensive tier, behind an explicit action.
class _VolumeCard extends StatelessWidget {
  const _VolumeCard({
    required this.volume,
    required this.computing,
    required this.done,
    required this.total,
    required this.error,
    required this.days,
    required this.onCompute,
    required this.onOpenShop,
  });

  final PlatformVolume? volume;
  final bool computing;
  final int done;
  final int total;
  final String? error;
  final int days;
  final VoidCallback? onCompute;
  final ValueChanged<String> onOpenShop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue across all shops · last $days days',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCompute,
                  icon: computing
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow_rounded,
                          size: AppDimens.iconLg,
                        ),
                  label: Text(volume == null ? 'Compute' : 'Recompute'),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'Not loaded automatically: this reads every sale, expense, and '
              'income record of every shop, and that cost grows with your '
              'history rather than your shop count. Run it when you need it. '
              'To have it always fresh instead, it needs nightly rollup '
              'documents written by a scheduled function.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (computing) ...[
              const SizedBox(height: AppDimens.spacing14),
              LinearProgressIndicator(
                value: total == 0 ? null : done / total,
                minHeight: 6,
              ),
              const SizedBox(height: AppDimens.spacing6),
              Text(
                'Scanned $done of $total shops…',
                style: TextStyle(
                  fontSize: AppDimens.fontCaption,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: AppDimens.spacing14),
              _EmptyNote(icon: Icons.error_outline, text: error!),
            ],
            if (volume != null) ...[
              const SizedBox(height: AppDimens.spacing16),
              _VolumeResults(volume: volume!, onOpenShop: onOpenShop),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeResults extends StatelessWidget {
  const _VolumeResults({required this.volume, required this.onOpenShop});

  final PlatformVolume volume;
  final ValueChanged<String> onOpenShop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ranked = volume.shops.where((s) => s.stats.totalRevenue > 0).toList();
    final peak = ranked.isEmpty ? 0.0 : ranked.first.stats.totalRevenue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimens.spacing10,
          runSpacing: AppDimens.spacing10,
          children: [
            StatTile(
              icon: Icons.payments_outlined,
              label: 'Total revenue',
              value: formatMoney(volume.totalRevenue),
              color: colorScheme.tertiary,
              containerColor: colorScheme.tertiaryContainer,
            ),
            StatTile(
              icon: Icons.savings_outlined,
              label: 'Net profit',
              value: formatMoney(volume.totalNetProfit),
              color: volume.totalNetProfit >= 0
                  ? colorScheme.tertiary
                  : colorScheme.error,
              containerColor: volume.totalNetProfit >= 0
                  ? colorScheme.tertiaryContainer
                  : colorScheme.errorContainer,
            ),
            StatTile(
              icon: Icons.receipt_long_outlined,
              label: 'Sales',
              value: '${volume.totalSalesCount}',
              color: ZonixColors.chartBlue,
              containerColor: ZonixColors.cyanContainer,
            ),
            StatTile(
              icon: Icons.storefront_outlined,
              label: 'Shops selling',
              value: '${volume.sellingShopCount} / ${volume.shops.length}',
              color: colorScheme.primary,
              containerColor: colorScheme.primaryContainer,
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing16),
        TrendChart(
          loading: false,
          series: volume.series,
          rangeLabel: 'last ${volume.series.length} days',
        ),
        const SizedBox(height: AppDimens.spacing16),
        Text(
          'Revenue by shop',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDimens.spacing10),
        if (ranked.isEmpty)
          Text(
            'No shop recorded a sale in this period.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          )
        else
          for (final shop in ranked) ...[
            _RevenueBar(
              name: shop.name,
              revenue: shop.stats.totalRevenue,
              peak: peak,
              onTap: () => onOpenShop(shop.slug),
            ),
            const SizedBox(height: AppDimens.spacing8),
          ],
      ],
    );
  }
}

/// One shop's revenue as a ranked bar. Every bar is the same color on
/// purpose — the measure is identical across rows, so a per-shop hue would
/// encode nothing and imply a category that does not exist.
class _RevenueBar extends StatelessWidget {
  const _RevenueBar({
    required this.name,
    required this.revenue,
    required this.peak,
    required this.onTap,
  });

  final String name;
  final double revenue;
  final double peak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing4),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppDimens.fontBody),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimens.radiusHandle),
                child: LinearProgressIndicator(
                  value: peak == 0 ? 0 : revenue / peak,
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation(
                    ZonixColors.chartBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimens.spacing12),
            SizedBox(
              width: 110,
              child: Text(
                formatMoney(revenue),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: AppDimens.fontLabel,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacing12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppDimens.iconLg, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppDimens.spacing8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
