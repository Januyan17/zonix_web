import 'package:flutter/material.dart';

import '../models/device_login.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/device_login_service.dart';
import '../services/shop_service.dart';
import '../theme/app_dimens.dart';
import '../utils/device_login_badges.dart';
import '../utils/error_utils.dart';
import '../widgets/admin_shell.dart';
import '../widgets/device_login_tile.dart';

/// Lists first logins of mobile app installs (the `device_logins`
/// collection), newest first, 25 at a time, optionally for one shop.
///
/// Reached two ways: from the nav rail, as a top-level page inside the
/// [AdminShell]; or pushed from a shop's detail page via
/// [DeviceLoginsScreen.subPage], pre-filtered to that shop, as a plain page
/// with a back button (the detail page has no AuthService to build a shell).
class DeviceLoginsScreen extends StatefulWidget {
  const DeviceLoginsScreen({
    super.key,
    required AuthService this.authService,
    required this.shopService,
    this.initialShopId,
    this.deviceLoginService,
    this.appVersionService,
  });

  const DeviceLoginsScreen.subPage({
    super.key,
    required this.shopService,
    required String this.initialShopId,
    this.deviceLoginService,
    this.appVersionService,
  }) : authService = null;

  /// Null in sub-page mode.
  final AuthService? authService;
  final ShopService shopService;
  final String? initialShopId;
  final DeviceLoginService? deviceLoginService;
  final AppVersionService? appVersionService;

  @override
  State<DeviceLoginsScreen> createState() => _DeviceLoginsScreenState();
}

class _ShopOption {
  const _ShopOption(this.id, this.name);

  final String id;
  final String name;
}

class _DeviceLoginsScreenState extends State<DeviceLoginsScreen> {
  late final DeviceLoginService _service =
      widget.deviceLoginService ?? DeviceLoginService();
  late final AppVersionService _appVersion =
      widget.appVersionService ?? AppVersionService();

  List<_ShopOption> _shops = const [];
  late String? _shopId = widget.initialShopId;

  /// The forced-update floor, read once. Null when unreadable or not set,
  /// in which case no row is flagged "Old build".
  int? _minSupportedBuild;

  List<DeviceLogin> _logins = const [];
  DeviceLoginPage? _lastPage;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;

  /// Bumped on every fresh load so a slow response for a previous filter
  /// can't land on top of the current one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadShops();
    _loadFloor();
    _reload();
  }

  /// The shop dropdown is filled from the portal's own shop index, read
  /// once — the same source the Shops page lists from.
  Future<void> _loadShops() async {
    try {
      final docs = await widget.shopService.watchShopIndex().first;
      if (!mounted) return;
      setState(() {
        _shops = [
          for (final d in docs)
            _ShopOption(d.id, d.data()['name'] as String? ?? d.id),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    } catch (_) {
      // The filter is a convenience; the list still works without it.
    }
  }

  Future<void> _loadFloor() async {
    try {
      final config = await _appVersion.read();
      if (!mounted) return;
      setState(() => _minSupportedBuild = config?.minSupportedBuild);
    } catch (_) {
      // Without the floor, nothing is flagged "Old build" — the list itself
      // is unaffected.
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
    });
    try {
      final page = await _service.fetchPage(shopId: _shopId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _logins = page.logins;
        _lastPage = page;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // Shown verbatim: a missing composite index fails with a message that
      // contains the link to create it.
      setState(() => _error = describeError(e));
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _lastPage?.cursor;
    if (cursor == null || _loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await _service.fetchPage(
        shopId: _shopId,
        startAfter: cursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _logins = [..._logins, ...page.logins];
        _lastPage = page;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _moreError = describeError(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _selectShop(String? shopId) {
    if (shopId == _shopId) return;
    setState(() => _shopId = shopId);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final authService = widget.authService;
    if (authService == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device logins')),
        body: _buildBody(),
      );
    }
    return AdminShell(
      authService: authService,
      shopService: widget.shopService,
      current: AdminPage.deviceLogins,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: AppDimens.paddingAll24,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phonelink_lock_rounded,
                      size: AppDimens.iconLg,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppDimens.spacing8),
                    Text(
                      'New device logins',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spacing6),
                Text(
                  'The first login of each app install. A reinstall or '
                  'cleared app data counts as a new install; logging out and '
                  'back in on the same install does not.',
                  style: TextStyle(
                    fontSize: AppDimens.fontBody,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.spacing16),
                _buildFilterRow(),
                const SizedBox(height: AppDimens.spacing16),
                _buildResults(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    // The pre-selected shop may not be in the index (or the index may not
    // have loaded yet); it still needs an entry so the dropdown can show it.
    final options = [
      ..._shops,
      if (_shopId != null && !_shops.any((s) => s.id == _shopId))
        _ShopOption(_shopId!, _shopId!),
    ];

    return Wrap(
      spacing: AppDimens.spacing12,
      runSpacing: AppDimens.spacing12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DropdownButtonFormField<String?>(
            // Rebuilt when the options arrive so the selection shows the
            // shop's name rather than its id.
            key: ValueKey('${_shops.length}-$_shopId'),
            initialValue: _shopId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Shop',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All shops'),
              ),
              for (final s in options)
                DropdownMenuItem<String?>(
                  value: s.id,
                  child: Text(s.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _loading ? null : _selectShop,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _loading ? null : _reload,
          icon: const Icon(Icons.refresh_rounded, size: AppDimens.iconLg),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: AppDimens.paddingAll20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Could not load device logins.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppDimens.spacing8),
              // Selectable so a "requires an index" link can be copied.
              SelectableText(
                _error!,
                style: TextStyle(
                  fontSize: AppDimens.fontBody,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: AppDimens.spacing16),
              FilledButton(onPressed: _reload, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_logins.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.devices_other_outlined,
                size: AppDimens.icon2xl,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppDimens.spacing12),
              Text(
                _shopId == null
                    ? 'No device logins yet.'
                    : 'No device logins for this shop yet.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final repeats = repeatInstallKeys(_logins);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_logins.length} loaded',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimens.spacing8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < _logins.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                DeviceLoginTile(
                  login: _logins[i],
                  showShop: _shopId == null,
                  oldBuild: isOldBuild(
                    appBuild: _logins[i].appBuild,
                    minSupportedBuild: _minSupportedBuild,
                  ),
                  repeatInstall: isRepeatInstall(_logins[i], repeats),
                ),
              ],
            ],
          ),
        ),
        if (_moreError != null) ...[
          const SizedBox(height: AppDimens.spacing12),
          SelectableText(
            'Could not load more: $_moreError',
            style: TextStyle(
              fontSize: AppDimens.fontBody,
              color: colorScheme.error,
            ),
          ),
        ],
        if (_lastPage?.hasMore ?? false) ...[
          const SizedBox(height: AppDimens.spacing16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: AppDimens.iconLg,
                      height: AppDimens.iconLg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: const Text('Load more'),
            ),
          ),
        ],
      ],
    );
  }
}
