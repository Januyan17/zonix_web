import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/page_header.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
import 'package:zonixweb/features/app_version/services/app_version_service.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/device_logins/models/device_login.dart';
import 'package:zonixweb/features/device_logins/models/device_session.dart';
import 'package:zonixweb/features/device_logins/services/device_login_service.dart';
import 'package:zonixweb/features/device_logins/utils/device_grouping.dart';
import 'package:zonixweb/features/device_logins/widgets/delete_device_history.dart';
import 'package:zonixweb/features/device_logins/widgets/device_group_tile.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/services/shop_directory.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

/// Lists the devices people use the mobile app on, newest install first,
/// optionally for one shop. Reads `device_logins` 25 installs at a time and
/// folds reinstalls on the same phone into one row; each person's live
/// sessions (one small read per person) say whether a device is signed in
/// now and when it last logged in.
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
  List<DeviceGroup> _groups = const [];
  DeviceLoginPage? _lastPage;

  /// Live sessions per `shopId/userId`, fetched once per person per load
  /// and kept across "Load more". A key absent from both maps after loading
  /// means the lookup failed — shown as unknown status.
  Map<String, List<DeviceSession>> _sessions = const {};
  Set<String> _sessionsLoading = const {};

  /// 'owner', 'staff', or null for everyone. Filters what's already loaded,
  /// so switching costs no reads.
  String? _role;

  /// Nothing is fetched until a shop is picked (or "All shops", on
  /// purpose). A shop's "View all" link arrives with its shop already
  /// picked, so that entry point loads straight away.
  late bool _requested = widget.initialShopId != null;
  bool _floorRequested = false;

  late bool _loading = _requested;
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
    if (_requested) _loadNow();
  }

  /// The first load on request, and every Refresh after it. The build
  /// floor is read once, alongside the first load.
  void _loadNow() {
    setState(() => _requested = true);
    if (!_floorRequested) {
      _floorRequested = true;
      _loadFloor();
    }
    _reload();
  }

  /// The shop dropdown is filled from the portal's own shop index, read
  /// once — the same shared source the Shops page lists from, so it is
  /// usually already loaded and costs no extra reads.
  Future<void> _loadShops() async {
    try {
      final docs = await ShopDirectory.instance.indexOnce();
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
        _setLogins(page.logins);
        _lastPage = page;
        _sessions = const {};
        _sessionsLoading = const {};
      });
      _loadSessions(generation);
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
        _setLogins([..._logins, ...page.logins]);
        _lastPage = page;
      });
      _loadSessions(generation);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _moreError = describeError(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setLogins(List<DeviceLogin> logins) {
    _logins = logins;
    _groups = groupDeviceLogins(logins);
  }

  /// Fetches sessions for people on screen whose status isn't known yet.
  Future<void> _loadSessions(int generation) async {
    final keys = userKeysOf(_groups)
        .where(
          (k) => !_sessions.containsKey(k) && !_sessionsLoading.contains(k),
        )
        .toSet();
    if (keys.isEmpty) return;
    setState(() => _sessionsLoading = {..._sessionsLoading, ...keys});
    final result = await _service.fetchActiveSessionsFor(keys);
    if (!mounted || generation != _generation) return;
    setState(() {
      _sessions = {..._sessions, ...result};
      _sessionsLoading = _sessionsLoading.difference(keys);
    });
  }

  Future<void> _delete(List<DeviceLogin> installs) async {
    final deleted = await confirmAndDeleteDeviceHistory(
      context,
      service: _service,
      installs: installs,
    );
    if (!deleted || !mounted) return;
    final ids = {for (final l in installs) l.id};
    // Dropped locally; the paging cursor stays valid because Firestore's
    // startAfterDocument uses the snapshot's values, not its existence.
    setState(
      () => _setLogins(_logins.where((l) => !ids.contains(l.id)).toList()),
    );
  }

  /// Dropdown value for the explicit "All shops" choice — distinct from
  /// null, which here means nothing has been picked yet.
  static const _allShops = '__all_shops__';

  void _selectShop(String? value) {
    if (value == null) return;
    final shopId = value == _allShops ? null : value;
    if (_requested && shopId == _shopId) return;
    setState(() => _shopId = shopId);
    _loadNow();
  }

  @override
  Widget build(BuildContext context) {
    final authService = widget.authService;
    if (authService == null) {
      return Scaffold(
        appBar: zonixAppBar(title: 'Device logins', tag: 'Security'),
        body: ZonixBackdrop(child: _buildBody()),
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
    return ListView(
      padding: AppDimens.paddingAll24,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  icon: Icons.phonelink_lock_rounded,
                  tag: 'Security',
                  title: 'Device logins',
                  subtitle:
                      'One row per phone, newest install first. Reinstalls on '
                      'the same phone are folded in — tap a row to see them. '
                      '"Signed in" means the app is logged in on that phone '
                      'now; the time is its most recent login.',
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
            key: ValueKey('${_shops.length}-$_shopId-$_requested'),
            initialValue: _requested ? (_shopId ?? _allShops) : null,
            isExpanded: true,
            hint: const Text('Select a shop'),
            decoration: const InputDecoration(
              labelText: 'Shop',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: _allShops,
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
          // Nothing to refresh until a shop has been picked.
          onPressed: !_requested || _loading ? null : _loadNow,
          icon: const Icon(Icons.refresh_rounded, size: AppDimens.iconLg),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_requested) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const GlowIconTile(icon: Icons.storefront_outlined, size: 56),
              const SizedBox(height: AppDimens.spacing16),
              const Text(
                'Select a shop to see its device logins.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppDimens.spacing4),
              Text(
                'Only the chosen shop is loaded. Pick "All shops" to load '
                'every shop.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

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

    int countRole(String role) =>
        _groups.where((g) => g.latest.role.toLowerCase() == role).length;
    final owners = countRole('owner');
    final staff = countRole('staff');
    final groups = _role == null
        ? _groups
        : _groups.where((g) => g.latest.role.toLowerCase() == _role).toList();
    final signedIn = groups
        .where((g) => g.activeSessionIn(_sessions[g.userKey]) != null)
        .length;

    Widget roleChip(String? role, String label, int count, IconData? icon) {
      return ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: AppDimens.iconSm),
        label: Text('$label ($count)'),
        selected: _role == role,
        onSelected: (_) => setState(() => _role = role),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppDimens.spacing8,
          runSpacing: AppDimens.spacing8,
          children: [
            roleChip(null, 'All', _groups.length, null),
            roleChip(
              'owner',
              'Owners',
              owners,
              Icons.admin_panel_settings_rounded,
            ),
            roleChip('staff', 'Staff', staff, Icons.badge_outlined),
          ],
        ),
        const SizedBox(height: AppDimens.spacing12),
        Text(
          '${groups.length} device${groups.length == 1 ? '' : 's'}'
          '${_sessionsLoading.isEmpty ? ' · $signedIn signed in' : ''}'
          ' · ${_logins.length} install${_logins.length == 1 ? '' : 's'} loaded',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimens.spacing8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: groups.isEmpty
              ? Padding(
                  padding: AppDimens.paddingAll20,
                  child: Text(
                    _role == 'owner'
                        ? 'No owner devices in what\'s loaded.'
                        : 'No staff devices in what\'s loaded.',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      DeviceGroupTile(
                        key: ValueKey(groups[i].key),
                        group: groups[i],
                        sessions: _sessions[groups[i].userKey],
                        sessionsLoading: _sessionsLoading.contains(
                          groups[i].userKey,
                        ),
                        minSupportedBuild: _minSupportedBuild,
                        showShop: _shopId == null,
                        onDelete: _delete,
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
