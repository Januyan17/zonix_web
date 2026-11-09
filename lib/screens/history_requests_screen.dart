import 'dart:async';

import 'package:flutter/material.dart';

import '../models/history_request.dart';
import '../services/auth_service.dart';
import '../services/history_request_service.dart';
import '../services/shop_service.dart';
import '../theme/app_dimens.dart';
import '../utils/error_utils.dart';
import '../utils/history_request_state.dart';
import '../widgets/admin_shell.dart';
import '../widgets/history_request_tile.dart';

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
  bool _loading = true;
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
    _reload();
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

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _moreError = null;
    });
    try {
      final page = await _service.getRecent();
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
      final page = await _service.getRecent(startAfter: cursor);
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
                Text(
                  'After a fresh install the app only restores the current '
                  'month. Turning a request on lets that phone download older '
                  'history for 24 hours; turning it off denies it.',
                  style: TextStyle(
                    fontSize: AppDimens.fontBody,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.spacing20),
                ListenableBuilder(
                  listenable: _pending,
                  builder: (context, _) => _buildPendingSection(),
                ),
                const SizedBox(height: AppDimens.spacing24),
                _SectionHeader(
                  icon: Icons.history_rounded,
                  label: 'Recent',
                  trailing: OutlinedButton.icon(
                    onPressed: _loading ? null : _reload,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: AppDimens.iconLg,
                    ),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(height: AppDimens.spacing10),
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
      content = _ErrorCard(
        title: 'Could not load pending requests.',
        message: _pending.error!,
        onRetry: _pending.retry,
      );
    } else if (requests == null) {
      content = const _LoadingCard();
    } else if (requests.isEmpty) {
      content = const _EmptyCard(message: 'No pending requests.');
    } else {
      content = _RequestList(
        requests: requests,
        service: _service,
        onUpdated: _replace,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
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

  Widget _buildRecentSection() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_loading) return const _LoadingCard();
    if (_error != null) {
      return _ErrorCard(
        title: 'Could not load recent requests.',
        message: _error!,
        onRetry: _reload,
      );
    }
    if (_recent.isEmpty) {
      return const _EmptyCard(message: 'No history requests yet.');
    }
    final groups = splitExpired(_recent, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.current.isEmpty)
          const _EmptyCard(message: 'No current requests.')
        else
          _RequestList(
            requests: groups.current,
            service: _service,
            onUpdated: _replace,
          ),
        if (groups.expired.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spacing24),
          _SectionHeader(
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
          _RequestList(
            requests: groups.expired,
            service: _service,
            onUpdated: _replace,
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

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.requests,
    required this.service,
    required this.onUpdated,
  });

  final List<HistoryRequest> requests;
  final HistoryRequestService service;
  final ValueChanged<HistoryRequest> onUpdated;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            HistoryRequestTile(
              key: ValueKey(requests[i].ref?.path ?? i),
              request: requests[i],
              service: service,
              onUpdated: onUpdated,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconLg, color: colorScheme.primary),
        const SizedBox(width: AppDimens.spacing8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: AppDimens.icon2xl,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimens.spacing12),
            Text(
              message,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppDimens.spacing8),
            // Selectable so a "requires an index" link can be copied.
            SelectableText(
              message,
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
