import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/page_header.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/core/widgets/state_cards.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/history_requests/models/history_request.dart';
import 'package:zonixweb/features/history_requests/services/history_request_service.dart';
import 'package:zonixweb/features/history_requests/utils/history_request_state.dart';
import 'package:zonixweb/features/history_requests/widgets/history_request_list.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/services/shop_directory.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

/// Phones asking to download sales history older than the current month
/// (after a reinstall, cleared data, a new phone or a shop change). An
/// approval is per phone and lasts 24 hours from when it's turned on.
///
/// "Pending" is live (the same shared listener that drives the nav badge);
/// "Recent" is one-off reads, 25 at a time, with approvals whose 24 hours
/// have run out moved to a separate "Expired" group as they expire.
class HistoryRequestsScreen extends StatefulWidget {
  const HistoryRequestsScreen({
    super.key,
    required this.authService,
    required this.shopService,
    this.historyRequestService,
  });

  final AuthService authService;
  final ShopService shopService;
  final HistoryRequestService? historyRequestService;

  @override
  State<HistoryRequestsScreen> createState() => _HistoryRequestsScreenState();
}

class _HistoryRequestsScreenState extends State<HistoryRequestsScreen> {
  late final HistoryRequestService _service =
      widget.historyRequestService ?? HistoryRequestService();
  final _pending = PendingHistoryRequests.instance;

  List<HistoryRequest> _recent = const [];
  HistoryRequestPage? _lastPage;

  /// The Recent list loads per shop, and only once a shop is picked (or
  /// "All shops", on purpose). Pending stays live: it drives the nav badge.
  List<({String id, String name})> _shops = const [];
  String? _shopId;
  bool _requested = false;
  static const _allShops = '__all_shops__';

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;
  int _generation = 0;

  /// Re-groups the loaded rows as approvals run out, so an expired one moves
  /// from Recent to Expired without a reload. Only rebuilds while there's a
  /// live approval on screen (plus once more, on the tick it expires).
  Timer? _expiryTicker;
  bool _hadLiveApproval = false;

  @override
  void initState() {
    super.initState();
    _loadShops();
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final live = hasLiveApproval(_recent, DateTime.now());
      if (live || _hadLiveApproval) setState(() {});
      _hadLiveApproval = live;
    });
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    super.dispose();
  }

  /// The shop dropdown is filled from the portal's own shop index — the
  /// same shared source the Shops page lists from, so it is usually
  /// already loaded and costs no extra reads.
  Future<void> _loadShops() async {
    try {
      final docs = await ShopDirectory.instance.indexOnce();
      if (!mounted) return;
      setState(() {
        _shops = [
          for (final d in docs)
            (id: d.id, name: d.data()['name'] as String? ?? d.id),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    } catch (_) {
      // The filter is a convenience; "All shops" still works without it.
    }
  }

  void _selectShop(String? value) {
    if (value == null) return;
    final shopId = value == _allShops ? null : value;
    if (_requested && shopId == _shopId) return;
    setState(() {
      _shopId = shopId;
      _requested = true;
    });
    _reload();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
    });
    try {
      final page = await _service.getRecent(shopId: _shopId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _recent = page.requests;
        _lastPage = page;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // Shown verbatim: a missing index fails with a message that contains
      // the link to create it.
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
      final page = await _service.getRecent(
        shopId: _shopId,
        startAfter: cursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _recent = [..._recent, ...page.requests];
        _lastPage = page;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _moreError = describeError(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Patches a row in the Recent list after it was approved/denied —
  /// from either section — without re-reading the whole page.
  void _replace(HistoryRequest updated) {
    if (!mounted) return;
    final path = updated.ref?.path;
    if (path == null) return;
    setState(() {
      _recent = [for (final r in _recent) r.ref?.path == path ? updated : r];
    });
  }

  /// Drops a deleted request from the Recent list (Pending is live and
  /// updates by itself), without re-reading the page.
  void _remove(HistoryRequest deleted) {
    if (!mounted) return;
    final path = deleted.ref?.path;
    if (path == null) return;
    setState(() {
      _recent = [
        for (final r in _recent)
          if (r.ref?.path != path) r,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: widget.authService,
      shopService: widget.shopService,
      current: AdminPage.historyRequests,
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
                  icon: Icons.manage_history_rounded,
                  tag: 'Data restore',
                  title: 'History requests',
                  subtitle:
                      'After a fresh install the app only restores the current '
                      'month. Turning a request on lets that phone download older '
                      'history for 24 hours; turning it off denies it.',
                ),
                const SizedBox(height: AppDimens.spacing20),
                ListenableBuilder(
                  listenable: _pending,
                  builder: (context, _) => _buildPendingSection(),
                ),
                const SizedBox(height: AppDimens.spacing24),
                SectionHeader(
                  icon: Icons.history_rounded,
                  label: 'Recent',
                  trailing: OutlinedButton.icon(
                    // Nothing to refresh until a shop has been picked.
                    onPressed: !_requested || _loading ? null : _reload,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: AppDimens.iconLg,
                    ),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(height: AppDimens.spacing10),
                _buildShopPicker(),
                const SizedBox(height: AppDimens.spacing12),
                _buildRecentSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingSection() {
    final requests = _pending.requests;
    final Widget content;
    if (_pending.error != null) {
      content = ErrorCard(
        title: 'Could not load pending requests.',
        message: _pending.error!,
        onRetry: _pending.retry,
      );
    } else if (requests == null) {
      content = const LoadingCard();
    } else if (requests.isEmpty) {
      content = const EmptyCard(message: 'No pending requests.');
    } else {
      content = HistoryRequestList(
        requests: requests,
        service: _service,
        onUpdated: _replace,
        onDeleted: _remove,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.pending_actions_rounded,
          label: requests == null || requests.isEmpty
              ? 'Pending'
              : 'Pending (${requests.length}'
                    '${requests.length >= HistoryRequestService.pendingLimit ? '+' : ''})',
        ),
        const SizedBox(height: AppDimens.spacing10),
        content,
      ],
    );
  }

  Widget _buildShopPicker() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DropdownButtonFormField<String>(
          // Rebuilt when the options arrive so the selection shows the
          // shop's name.
          key: ValueKey('${_shops.length}-$_shopId-$_requested'),
          initialValue: _requested ? (_shopId ?? _allShops) : null,
          isExpanded: true,
          hint: const Text('Select a shop'),
          decoration: const InputDecoration(
            labelText: 'Shop',
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
          items: [
            const DropdownMenuItem(value: _allShops, child: Text('All shops')),
            for (final s in _shops)
              DropdownMenuItem(
                value: s.id,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _loading ? null : _selectShop,
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    final colorScheme = Theme.of(context).colorScheme;
    if (!_requested) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const GlowIconTile(icon: Icons.storefront_outlined, size: 52),
              const SizedBox(height: AppDimens.spacing16),
              const Text(
                'Select a shop to see its recent requests.',
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
    if (_loading) return const LoadingCard();
    if (_error != null) {
      return ErrorCard(
        title: 'Could not load recent requests.',
        message: _error!,
        onRetry: _reload,
      );
    }
    if (_recent.isEmpty) {
      return const EmptyCard(message: 'No history requests yet.');
    }
    final groups = splitExpired(_recent, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.current.isEmpty)
          const EmptyCard(message: 'No current requests.')
        else
          HistoryRequestList(
            requests: groups.current,
            service: _service,
            onUpdated: _replace,
            onDeleted: _remove,
          ),
        if (groups.expired.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spacing24),
          SectionHeader(
            icon: Icons.timer_off_outlined,
            label: 'Expired (${groups.expired.length})',
          ),
          const SizedBox(height: AppDimens.spacing6),
          Text(
            'Approvals whose 24 hours have run out — those phones can no '
            'longer download older history. Turn one on to allow another '
            '24 hours.',
            style: TextStyle(
              fontSize: AppDimens.fontBody,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.spacing10),
          HistoryRequestList(
            requests: groups.expired,
            service: _service,
            onUpdated: _replace,
            onDeleted: _remove,
          ),
        ],
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
