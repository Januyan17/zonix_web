import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/features/app_version/models/app_version_config.dart';
import 'package:zonixweb/features/app_version/services/app_version_service.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/overview/models/platform_stats.dart';
import 'package:zonixweb/features/overview/services/platform_stats_service.dart';
import 'package:zonixweb/features/overview/widgets/activity_mix_card.dart';
import 'package:zonixweb/features/overview/widgets/build_adoption_card.dart';
import 'package:zonixweb/features/overview/widgets/feature_adoption_card.dart';
import 'package:zonixweb/features/overview/widgets/overview_header.dart';
import 'package:zonixweb/features/overview/widgets/overview_summary_tiles.dart';
import 'package:zonixweb/features/overview/widgets/shop_growth_chart.dart';
import 'package:zonixweb/features/overview/widgets/shop_health_card.dart';
import 'package:zonixweb/features/overview/widgets/volume_card.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/models/shop_stats.dart';
import 'package:zonixweb/features/shops/screens/shop_detail_screen.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

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

  /// Switching tabs rebuilds this page from scratch (the shell uses
  /// pushReplacement), so the last results are kept for the session; the header's
  /// loaded-at time says how old they are, and refresh always re-reads.
  /// Only the health scan is reused within [_healthMaxAge] — the update
  /// gate is a single document and is re-read on each visit, since the App
  /// version page may just have changed it.
  static const _healthMaxAge = Duration(minutes: 10);
  static PlatformHealth? _cachedHealth;
  static PlatformVolume? _cachedVolume;

  @override
  void initState() {
    super.initState();
    _volume = _cachedVolume;
    final cached = _cachedHealth;
    if (cached != null &&
        DateTime.now().difference(cached.loadedAt) < _healthMaxAge) {
      _health = cached;
      _loading = false;
      _loadVersionConfig();
    } else {
      _load();
    }
  }

  Future<void> _loadVersionConfig() async {
    final config = await _appVersion.read().catchError((_) => null);
    if (mounted) setState(() => _versionConfig = config);
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
      _cachedHealth = results[0] as PlatformHealth;
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
      _cachedVolume = volume;
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
        builder: (_) =>
            ShopDetailScreen(slug: slug, shopService: widget.shopService),
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
          OverviewHeader(loadedAt: health.loadedAt, onRefresh: _load),
          const SizedBox(height: AppDimens.spacing16),
          OverviewSummaryTiles(health: health),
          const SizedBox(height: AppDimens.spacing16),
          ActivityMixCard(health: health),
          const SizedBox(height: AppDimens.spacing16),
          ShopGrowthChart(loading: false, points: health.growth),
          const SizedBox(height: AppDimens.spacing16),
          ShopHealthCard(health: health, onOpenShop: _openShop),
          const SizedBox(height: AppDimens.spacing16),
          FeatureAdoptionCard(features: health.features),
          const SizedBox(height: AppDimens.spacing16),
          BuildAdoptionCard(builds: health.builds, config: _versionConfig),
          const SizedBox(height: AppDimens.spacing16),
          VolumeCard(
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
