import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/status_pill.dart';
import 'package:zonixweb/features/history_requests/models/history_request.dart';
import 'package:zonixweb/features/history_requests/services/history_request_service.dart';
import 'package:zonixweb/features/history_requests/utils/history_request_state.dart';

/// One history request row with its approve/deny switch. Shared by the
/// History requests screen and the shop detail page's section.
///
/// Switch ON = approved and not expired; OFF = pending, denied or expired.
/// Turning it on asks for confirmation then approves (restarting the 24
/// hours, even for an expired request); turning it off denies.
class HistoryRequestTile extends StatefulWidget {
  const HistoryRequestTile({
    super.key,
    required this.request,
    required this.service,
    this.onUpdated,
    this.showShop = true,
  });

  final HistoryRequest request;
  final HistoryRequestService service;

  /// Called with the re-read document after a successful approve/deny, so
  /// one-off lists can show the new state without a full reload.
  final ValueChanged<HistoryRequest>? onUpdated;

  /// Hidden on the shop detail page, where every row is the same shop.
  final bool showShop;

  @override
  State<HistoryRequestTile> createState() => _HistoryRequestTileState();
}

class _HistoryRequestTileState extends State<HistoryRequestTile> {
  bool _saving = false;

  /// Ticks the "Expires in …" label (and the switch, once it runs out)
  /// while an approval is live. Not started for any other state.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(HistoryRequestTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  HistoryRequestStatus _status() => historyRequestStatus(
    status: widget.request.status,
    approvedAt: widget.request.approvedAt,
    now: DateTime.now(),
  );

  void _syncTicker() {
    final live = _status().state == HistoryRequestState.approved;
    if (live && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {});
        if (_status().state != HistoryRequestState.approved) {
          _ticker?.cancel();
          _ticker = null;
        }
      });
    } else if (!live) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _toggle(bool approve) async {
    final request = widget.request;
    final ref = request.ref;
    if (ref == null) return;

    if (approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allow older history?'),
          content: Text(
            'Allow ${request.deviceLabel} at ${request.shopLabel} to '
            'download older history for 24 hours?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (approve) {
        await widget.service.approve(ref);
      } else {
        await widget.service.deny(ref);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Approved for 24 hours: ${request.deviceLabel}'
                : 'Denied: ${request.deviceLabel}',
          ),
        ),
      );
      try {
        final updated = await widget.service.getOne(ref);
        widget.onUpdated?.call(updated);
      } catch (_) {
        // The write succeeded; a failed re-read only leaves this row stale
        // until the next refresh.
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update request: ${describeError(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final request = widget.request;
    final now = DateTime.now();
    final status = historyRequestStatus(
      status: request.status,
      approvedAt: request.approvedAt,
      now: now,
    );
    final requestedAt = request.requestedAt;
    final expiresAt = status.expiresAt;

    final secondary = TextStyle(
      fontSize: AppDimens.fontBody,
      color: colorScheme.onSurfaceVariant,
    );

    final (Color fg, Color bg) = switch (status.state) {
      HistoryRequestState.pending => (
        colorScheme.onPrimaryContainer,
        colorScheme.primaryContainer.withValues(alpha: 0.6),
      ),
      HistoryRequestState.approved => (
        colorScheme.onTertiaryContainer,
        colorScheme.tertiaryContainer.withValues(alpha: 0.6),
      ),
      HistoryRequestState.expired => (
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
      ),
      HistoryRequestState.denied => (
        colorScheme.onErrorContainer,
        colorScheme.errorContainer,
      ),
    };

    final String? stateDetail = switch (status.state) {
      HistoryRequestState.approved =>
        expiresAt == null
            ? 'Approved just now'
            : expiresInLabel(expiresAt: expiresAt, now: now),
      HistoryRequestState.expired =>
        expiresAt == null ? null : 'Expired ${formatShortDateTime(expiresAt)}',
      _ => null,
    };

    return Padding(
      padding: AppDimens.paddingH16V12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppDimens.spacing8,
                  runSpacing: AppDimens.spacing4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      request.userLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppDimens.fontBodyLg,
                      ),
                    ),
                    if (request.role.isNotEmpty)
                      StatusPill(
                        label: request.role,
                        fg: colorScheme.onSurfaceVariant,
                        bg: colorScheme.surfaceContainerHighest,
                      ),
                    StatusPill(
                      label: historyRequestStateLabel(status.state),
                      fg: fg,
                      bg: bg,
                    ),
                  ],
                ),
                if (widget.showShop) ...[
                  const SizedBox(height: AppDimens.spacing2),
                  Text(
                    request.shopLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: AppDimens.spacing2),
                Text(
                  [
                    request.deviceName.isEmpty
                        ? 'Unknown device'
                        : request.deviceName,
                    'Requested ${requestedAt == null ? '—' : formatShortDateTime(requestedAt)}',
                  ].join(' · '),
                  style: secondary,
                ),
                if (stateDetail != null) ...[
                  const SizedBox(height: AppDimens.spacing2),
                  Text(
                    stateDetail,
                    style: TextStyle(
                      fontSize: AppDimens.fontLabel,
                      fontWeight: FontWeight.w600,
                      color: status.state == HistoryRequestState.approved
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppDimens.spacing12),
          if (_saving)
            const SizedBox(
              width: AppDimens.spinnerBox,
              height: AppDimens.spinnerBox,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Tooltip(
              message: status.state == HistoryRequestState.approved
                  ? 'Turn off to deny'
                  : 'Turn on to allow for 24 hours',
              child: Switch(
                value: status.state == HistoryRequestState.approved,
                onChanged: request.ref == null ? null : _toggle,
              ),
            ),
        ],
      ),
    );
  }
}
