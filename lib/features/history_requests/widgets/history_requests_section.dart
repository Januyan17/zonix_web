import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/history_requests/models/history_request.dart';
import 'package:zonixweb/features/history_requests/services/history_request_service.dart';
import 'package:zonixweb/features/history_requests/utils/history_request_state.dart';
import 'package:zonixweb/features/history_requests/widgets/history_request_tile.dart';

/// This shop's history requests (one per phone), with the same approve /
/// deny switch as the History requests screen. Self-contained one-off
/// reads of the shop's own subcollection — no listener, and a failure here
/// never affects the rest of the shop page.
class HistoryRequestsSection extends StatefulWidget {
  const HistoryRequestsSection({
    super.key,
    required this.shopId,
    this.historyRequestService,
  });

  final String shopId;
  final HistoryRequestService? historyRequestService;

  @override
  State<HistoryRequestsSection> createState() => _HistoryRequestsSectionState();
}

class _HistoryRequestsSectionState extends State<HistoryRequestsSection> {
  late final HistoryRequestService _service =
      widget.historyRequestService ?? HistoryRequestService();

  List<HistoryRequest> _requests = const [];
  HistoryRequestPage? _lastPage;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// Moves an approval into the Expired group once its 24 hours run out,
  /// without a reload. Rebuilds only while one is live (and on the tick it
  /// expires).
  Timer? _expiryTicker;
  bool _hadLiveApproval = false;

  @override
  void initState() {
    super.initState();
    _load();
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final live = hasLiveApproval(_requests, DateTime.now());
      if (live || _hadLiveApproval) setState(() {});
      _hadLiveApproval = live;
    });
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.getRecent(shopId: widget.shopId);
      if (!mounted) return;
      setState(() {
        _requests = page.requests;
        _lastPage = page;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _lastPage?.cursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.getRecent(
        shopId: widget.shopId,
        startAfter: cursor,
      );
      if (!mounted) return;
      setState(() {
        _requests = [..._requests, ...page.requests];
        _lastPage = page;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: ${describeError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _replace(HistoryRequest updated) {
    if (!mounted) return;
    final path = updated.ref?.path;
    if (path == null) return;
    setState(() {
      _requests = [
        for (final r in _requests) r.ref?.path == path ? updated : r,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.manage_history_rounded,
          label: 'History requests',
          trailing: IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: AppDimens.iconLg),
          ),
        ),
        const SizedBox(height: AppDimens.spacing10),
        Card(clipBehavior: Clip.antiAlias, child: _buildContent(colorScheme)),
        if (!_loading && _error == null && (_lastPage?.hasMore ?? false)) ...[
          const SizedBox(height: AppDimens.spacing10),
          Center(
            child: TextButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: const Text('Load more'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    if (_loading) {
      return const Padding(
        padding: AppDimens.paddingAll20,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: AppDimens.paddingAll20,
        child: SelectableText(
          'Could not load history requests: $_error',
          style: TextStyle(
            fontSize: AppDimens.fontBody,
            color: colorScheme.error,
          ),
        ),
      );
    }
    if (_requests.isEmpty) {
      return Padding(
        padding: AppDimens.paddingAll20,
        child: Text(
          'No history requests from this shop.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    final groups = splitExpired(_requests, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._tiles(groups.current),
        if (groups.expired.isNotEmpty) ...[
          if (groups.current.isNotEmpty) const Divider(height: 1),
          Container(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacing16,
              vertical: AppDimens.spacing8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_off_outlined,
                  size: AppDimens.iconSm,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimens.spacing8),
                Text(
                  'Expired (${groups.expired.length})',
                  style: TextStyle(
                    fontSize: AppDimens.fontLabel,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ..._tiles(groups.expired),
        ],
      ],
    );
  }

  List<Widget> _tiles(List<HistoryRequest> requests) {
    return [
      for (var i = 0; i < requests.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        HistoryRequestTile(
          key: ValueKey(requests[i].ref?.path ?? i),
          request: requests[i],
          service: _service,
          showShop: false,
          onUpdated: _replace,
        ),
      ],
    ];
  }
}
