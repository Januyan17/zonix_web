import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/utils/snackbar.dart';
import 'package:zonixweb/core/widgets/delete_confirm_dialog.dart';
import 'package:zonixweb/core/widgets/empty_state.dart';
import 'package:zonixweb/core/widgets/error_banner.dart';
import 'package:zonixweb/features/contact_zonix/models/contact_request.dart';
import 'package:zonixweb/features/contact_zonix/services/contact_request_service.dart';
import 'package:zonixweb/features/contact_zonix/utils/sri_lanka_phone.dart';
import 'package:zonixweb/features/contact_zonix/widgets/supabase_setup_banner.dart';

/// The inbox filter: one status, or every request.
enum _Filter {
  newRequest(ContactRequestStatus.newRequest),
  contacted(ContactRequestStatus.contacted),
  onboarded(ContactRequestStatus.onboarded),
  rejected(ContactRequestStatus.rejected),
  all(null);

  const _Filter(this.status);
  final ContactRequestStatus? status;

  String get label => status?.label ?? 'All';
}

/// Requests tab of Contact Zonix: join requests sent from the mobile app's
/// "Send a Request" form, live from `public.contact_requests`. Reachable
/// whatever the form toggle says, since turning the form off only stops new
/// requests.
class ContactRequestsScreen extends StatefulWidget {
  const ContactRequestsScreen({
    super.key,
    required this.adminRecognised,
    required this.onRecheckAdmin,
    this.service,
  });

  final bool? adminRecognised;
  final VoidCallback onRecheckAdmin;
  final ContactRequestService? service;

  @override
  State<ContactRequestsScreen> createState() => _ContactRequestsScreenState();
}

class _ContactRequestsScreenState extends State<ContactRequestsScreen> {
  late final ContactRequestService _service =
      widget.service ?? ContactRequestService();
  final _feed = contactRequestsFeed;
  final _searchController = TextEditingController();
  _Filter _filter = _Filter.newRequest;

  @override
  void initState() {
    super.initState();
    _feed.addListener(_refresh);
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _feed.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _manualRefresh() async {
    await _feed.refresh();
    if (!mounted) return;
    showSnackBarMessage(
      context,
      _feed.error == null ? 'Requests refreshed' : 'Refresh failed',
    );
  }

  /// Swaps one request in the shared list (optimistic update / rollback).
  void _replaceLocal(ContactRequest updated) {
    final list = _feed.value;
    if (list == null) return;
    _feed.setLocal([for (final r in list) r.id == updated.id ? updated : r]);
  }

  Future<void> _changeStatus(
    ContactRequest request,
    ContactRequestStatus status,
  ) async {
    if (status == request.status) return;
    _replaceLocal(request.copyWith(status: status));
    try {
      final saved = await _service.updateStatus(request.id, status);
      _replaceLocal(saved);
    } catch (e) {
      _replaceLocal(request);
      if (mounted) {
        showSnackBarMessage(
          context,
          'Could not change status: ${describeError(e)}',
        );
      }
    }
  }

  Future<void> _editNote(ContactRequest request) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(initial: request.adminNote ?? ''),
    );
    if (note == null || !mounted) return;
    _replaceLocal(
      request.copyWith(adminNote: () => note.trim().isEmpty ? null : note),
    );
    try {
      final saved = await _service.updateNote(request.id, note);
      _replaceLocal(saved);
      if (mounted) showSnackBarMessage(context, 'Note saved');
    } catch (e) {
      _replaceLocal(request);
      if (mounted) {
        showSnackBarMessage(
          context,
          'Could not save note: ${describeError(e)}',
        );
      }
    }
  }

  Future<void> _delete(ContactRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Delete this request?',
        message:
            'Permanently deletes the request from "${request.shopName}" '
            '(${request.ownerName}). This cannot be undone.',
        confirmLabel: 'Delete',
      ),
    );
    if (confirmed != true || !mounted) return;
    final before = _feed.value;
    if (before != null) {
      _feed.setLocal(before.where((r) => r.id != request.id).toList());
    }
    try {
      await _service.delete(request.id);
      if (mounted) showSnackBarMessage(context, 'Request deleted');
    } catch (e) {
      if (before != null) _feed.setLocal(before);
      if (mounted) {
        showSnackBarMessage(context, 'Could not delete: ${describeError(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _feed.value ?? const <ContactRequest>[];
    int countFor(_Filter f) => f.status == null
        ? all.length
        : all.where((r) => r.status == f.status).length;
    final query = _searchController.text;
    final visible = all
        .where((r) => _filter.status == null || r.status == _filter.status)
        .where((r) => r.matches(query))
        .toList();
    // With data on screen, a dropped realtime stream is shown as a small
    // "Reconnecting" pill in the toolbar instead of a full error banner.
    final loadFailed = _feed.error != null && _feed.value == null;

    return ListView(
      padding: AppDimens.paddingAll24,
      children: [
        if (widget.adminRecognised == false) ...[
          SupabaseSetupBanner(onRetry: widget.onRecheckAdmin),
          const SizedBox(height: AppDimens.spacing16),
        ],
        if (loadFailed) ...[
          ErrorBanner(message: 'Could not load requests: ${_feed.error}'),
          const SizedBox(height: AppDimens.spacing16),
        ],
        _StatStrip(
          selected: _filter,
          countFor: countFor,
          onSelect: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: AppDimens.spacing20),
        _Toolbar(
          controller: _searchController,
          error: _feed.value == null ? null : _feed.error,
          refreshing: _feed.refreshing,
          onRefresh: _manualRefresh,
        ),
        const SizedBox(height: AppDimens.spacing16),
        if (!_feed.loading && all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              left: AppDimens.spacing4,
              bottom: AppDimens.spacing10,
            ),
            child: Text(
              'Showing ${visible.length} of ${countFor(_filter)} '
              '${_filter == _Filter.all ? '' : '${_filter.label.toLowerCase()} '}'
              'request${countFor(_filter) == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: AppDimens.fontLabel,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_feed.loading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (visible.isEmpty)
          Card(child: _emptyState(query, all.isEmpty))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              return Column(
                children: [
                  for (final r in visible)
                    Padding(
                      key: ValueKey(r.id),
                      padding: const EdgeInsets.only(
                        bottom: AppDimens.spacing12,
                      ),
                      child: _RequestCard(
                        request: r,
                        wide: wide,
                        onStatus: (s) => _changeStatus(r, s),
                        onNote: () => _editNote(r),
                        onDelete: () => _delete(r),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _emptyState(String query, bool noneAtAll) {
    if (query.trim().isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'No ${_filter.label.toLowerCase()} requests match "$query".',
      );
    }
    return switch (_filter) {
      _Filter.newRequest => EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No new requests',
        message: noneAtAll
            ? 'Requests sent from the app\'s "Send a Request" form show up '
                  'here live.'
            : 'You\'re all caught up.',
      ),
      _Filter.contacted => const EmptyState(
        icon: Icons.phone_callback_rounded,
        title: 'Nobody marked as contacted',
        message: 'Set a request to Contacted once you have reached the shop.',
      ),
      _Filter.onboarded => const EmptyState(
        icon: Icons.verified_rounded,
        title: 'No onboarded shops yet',
        message: 'Requests that became Zonix shops show up here.',
      ),
      _Filter.rejected => const EmptyState(
        icon: Icons.block_rounded,
        title: 'No rejected requests',
        message: 'Requests you turn down show up here.',
      ),
      _Filter.all => const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No requests yet',
        message:
            'Requests sent from the app\'s "Send a Request" form show up '
            'here live.',
      ),
    };
  }
}

/// Strong accent per status, for the card edge, avatar and stat tiles.
Color _accent(ContactRequestStatus? status, ColorScheme scheme) =>
    switch (status) {
      ContactRequestStatus.newRequest => ZonixColors.chartBlue,
      ContactRequestStatus.contacted => ZonixColors.navy,
      ContactRequestStatus.onboarded => ZonixColors.emerald,
      ContactRequestStatus.rejected => scheme.error,
      null => scheme.onSurfaceVariant,
    };

/// Status counts as large tiles that double as the inbox filter.
class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.selected,
    required this.countFor,
    required this.onSelect,
  });

  final _Filter selected;
  final int Function(_Filter) countFor;
  final ValueChanged<_Filter> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          for (final f in _Filter.values)
            _StatTile(
              filter: f,
              count: countFor(f),
              selected: f == selected,
              onTap: () => onSelect(f),
            ),
        ];
        if (constraints.maxWidth < 760) {
          return Wrap(
            spacing: AppDimens.spacing12,
            runSpacing: AppDimens.spacing12,
            children: [
              for (final t in tiles)
                SizedBox(width: AppDimens.statTileWidth, child: t),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppDimens.spacing12),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _Filter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(filter.status, scheme);
    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.07) : Colors.white,
        borderRadius: radius,
        border: Border.all(
          color: selected ? accent : ZonixColors.navy.withValues(alpha: 0.08),
          width: selected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ZonixColors.navy.withValues(alpha: selected ? 0.10 : 0.05),
            blurRadius: selected ? 18 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: AppDimens.paddingH16V14,
            child: Row(
              children: [
                Container(
                  width: AppDimens.avatarBoxLarge,
                  height: AppDimens.avatarBoxLarge,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
                  ),
                  child: Icon(
                    filter.status?.icon ?? Icons.all_inbox_rounded,
                    color: accent,
                    size: AppDimens.iconXxl,
                  ),
                ),
                const SizedBox(width: AppDimens.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: ZonixColors.navy,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacing2),
                      Text(
                        filter.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppDimens.fontLabel,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: selected ? accent : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Search, live-connection state and manual refresh.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.error,
    required this.refreshing,
    required this.onRefresh,
  });

  final TextEditingController controller;

  /// Set when the live stream dropped while data is still on screen.
  final String? error;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = controller.text;
    final search = TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Search shop, owner, phone or city',
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          borderSide: BorderSide(
            color: ZonixColors.navy.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          borderSide: BorderSide(
            color: ZonixColors.navy.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          borderSide: const BorderSide(
            color: ZonixColors.chartBlue,
            width: 1.6,
          ),
        ),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: controller.clear,
              ),
      ),
    );

    final live = error == null
        ? const _LivePill(
            label: 'Live',
            fg: ZonixColors.onEmeraldContainer,
            bg: ZonixColors.emeraldContainer,
            dot: ZonixColors.emerald,
            tooltip: 'New requests appear here automatically',
          )
        : _LivePill(
            label: 'Reconnecting…',
            fg: scheme.onErrorContainer,
            bg: scheme.errorContainer,
            dot: scheme.error,
            tooltip:
                'Live updates were interrupted ($error). Retrying '
                'automatically. The list may be out of date until then; '
                'press Refresh to reload now.',
          );

    final refresh = FilledButton.tonalIcon(
      onPressed: refreshing ? null : onRefresh,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        ),
      ),
      icon: refreshing
          ? const SizedBox(
              width: AppDimens.iconSm,
              height: AppDimens.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: AppDimens.iconLg),
      label: const Text('Refresh'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppDimens.spacing10),
              Row(children: [live, const Spacer(), refresh]),
            ],
          );
        }
        return Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SizedBox(width: constraints.maxWidth * 0.5, child: search),
            ),
            const Spacer(),
            live,
            const SizedBox(width: AppDimens.spacing12),
            refresh,
          ],
        );
      },
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({
    required this.label,
    required this.fg,
    required this.bg,
    required this.dot,
    required this.tooltip,
  });

  final String label;
  final Color fg;
  final Color bg;
  final Color dot;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacing12,
          vertical: AppDimens.spacing6,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: dot.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spacing8),
            Text(
              label,
              style: TextStyle(
                fontSize: AppDimens.fontLabel,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One request as a card: a single row on wide screens, stacked on narrow.
class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.request,
    required this.wide,
    required this.onStatus,
    required this.onNote,
    required this.onDelete,
  });

  final ContactRequest request;
  final bool wide;
  final ValueChanged<ContactRequestStatus> onStatus;
  final VoidCallback onNote;
  final VoidCallback onDelete;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _expanded = false;
  bool _hover = false;

  ContactRequest get r => widget.request;

  Future<void> _open(Uri? uri) async {
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnackBarMessage(context, 'Could not open $uri');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: r.phone));
    if (mounted) showSnackBarMessage(context, 'Number copied');
  }

  String get _initials {
    final words = r.shopName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w.characters.first).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(r.status, scheme);
    final muted = TextStyle(
      fontSize: AppDimens.fontLabel,
      color: scheme.onSurfaceVariant,
    );

    final avatar = Container(
      width: AppDimens.avatarBoxLarge,
      height: AppDimens.avatarBoxLarge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: accent,
        ),
      ),
    );

    final shop = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: AppDimens.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.shopName.isEmpty ? '(no shop name)' : r.shopName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ZonixColors.navy,
                ),
              ),
              const SizedBox(height: AppDimens.spacing2),
              _IconText(
                icon: Icons.person_outline_rounded,
                text: r.ownerName.isEmpty ? 'Unknown owner' : r.ownerName,
              ),
              const SizedBox(height: AppDimens.spacing2),
              Tooltip(
                message: formatShortDateTime(r.createdAt),
                child: _IconText(
                  icon: Icons.schedule_rounded,
                  text: _ago(r.createdAt),
                  style: muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final platform = r.platform?.toLowerCase();
    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          displaySriLankaPhone(r.phone),
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: ZonixColors.navy,
          ),
        ),
        const SizedBox(height: AppDimens.spacing6),
        Wrap(
          spacing: AppDimens.spacing6,
          runSpacing: AppDimens.spacing6,
          children: [
            if (r.city != null)
              _MetaChip(icon: Icons.place_outlined, label: r.city!),
            if (r.platform != null || r.appVersion != null)
              _MetaChip(
                icon: platform == 'android'
                    ? Icons.android_rounded
                    : platform == 'ios'
                    ? Icons.phone_iphone_rounded
                    : Icons.devices_rounded,
                label: [
                  if (r.platform != null) r.platform!,
                  if (r.appVersion != null) 'v${r.appVersion}',
                ].join(' · '),
              ),
          ],
        ),
      ],
    );

    final longMessage =
        r.message != null &&
        (r.message!.length > 140 || '\n'.allMatches(r.message!).length > 2);
    final message = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: ZonixColors.navy.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: AppDimens.iconLg,
                color: ZonixColors.navy.withValues(alpha: 0.3),
              ),
              const SizedBox(width: AppDimens.spacing6),
              Expanded(
                child: r.message == null
                    ? Text(
                        'No message',
                        style: muted.copyWith(fontStyle: FontStyle.italic),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.message!,
                            maxLines: _expanded ? null : 3,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppDimens.fontBodyLg,
                              height: 1.4,
                            ),
                          ),
                          if (longMessage)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                              child: Text(
                                _expanded ? 'Show less' : 'Show more',
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        if (r.adminNote != null) ...[
          const SizedBox(height: AppDimens.spacing8),
          InkWell(
            onTap: widget.onNote,
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: ZonixColors.cyanContainer,
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                border: Border.all(
                  color: ZonixColors.cyan.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: AppDimens.iconSm,
                    color: ZonixColors.chartBlue,
                  ),
                  const SizedBox(width: AppDimens.spacing8),
                  Expanded(
                    child: Text(
                      r.adminNote!,
                      style: const TextStyle(
                        fontSize: AppDimens.fontLabelLg,
                        color: ZonixColors.onCyanContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    final status = _StatusMenu(status: r.status, onChanged: widget.onStatus);

    final tel = sriLankaTelUri(r.phone);
    final whatsApp = sriLankaWhatsAppUri(r.phone);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          tooltip: 'Call',
          icon: Icons.call_rounded,
          color: ZonixColors.chartBlue,
          onPressed: tel == null ? null : () => _open(tel),
        ),
        const SizedBox(width: AppDimens.spacing6),
        _ActionButton(
          tooltip: whatsApp == null
              ? 'WhatsApp (mobile numbers only)'
              : 'WhatsApp',
          icon: Icons.chat_rounded,
          color: ZonixColors.emerald,
          onPressed: whatsApp == null ? null : () => _open(whatsApp),
        ),
        const SizedBox(width: AppDimens.spacing2),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          ),
          onSelected: (v) => switch (v) {
            'copy' => _copy(),
            'note' => widget.onNote(),
            'delete' => widget.onDelete(),
            _ => null,
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'copy',
              child: _MenuLabel(icon: Icons.copy_rounded, label: 'Copy number'),
            ),
            PopupMenuItem(
              value: 'note',
              child: _MenuLabel(
                icon: Icons.edit_note_rounded,
                label: r.adminNote == null ? 'Add note' : 'Edit note',
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: _MenuLabel(
                icon: Icons.delete_outline_rounded,
                label: 'Delete request',
                color: scheme.error,
              ),
            ),
          ],
        ),
      ],
    );

    final Widget body;
    if (widget.wide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: shop),
          const SizedBox(width: AppDimens.spacing20),
          Expanded(flex: 3, child: contact),
          const SizedBox(width: AppDimens.spacing20),
          Expanded(flex: 4, child: message),
          const SizedBox(width: AppDimens.spacing20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              status,
              const SizedBox(height: AppDimens.spacing12),
              actions,
            ],
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: shop),
              const SizedBox(width: AppDimens.spacing8),
              status,
            ],
          ),
          const SizedBox(height: AppDimens.spacing14),
          contact,
          const SizedBox(height: AppDimens.spacing12),
          message,
          const SizedBox(height: AppDimens.spacing8),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }

    final radius = BorderRadius.circular(AppDimens.radiusCard);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(
            color: _hover
                ? accent.withValues(alpha: 0.35)
                : ZonixColors.navy.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: ZonixColors.navy.withValues(alpha: _hover ? 0.12 : 0.05),
              blurRadius: _hover ? 22 : 12,
              offset: Offset(0, _hover ? 8 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 16, 18),
                child: body,
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "2 h ago"-style, falling back to the date after a week.
  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return formatShortDate(d);
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.style});

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconXs, color: color),
        const SizedBox(width: AppDimens.spacing4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style ?? const TextStyle(fontSize: AppDimens.fontBody),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing8,
        vertical: AppDimens.spacing4,
      ),
      decoration: BoxDecoration(
        color: ZonixColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.iconXs, color: color),
          const SizedBox(width: AppDimens.spacing4),
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

/// Round tinted icon button for the primary contact actions.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: enabled ? 0.10 : 0.04),
        foregroundColor: color,
        hoverColor: color.withValues(alpha: 0.18),
        fixedSize: const Size(40, 40),
      ),
      icon: Icon(icon, size: AppDimens.iconLg),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconLg, color: color),
        const SizedBox(width: AppDimens.spacing10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// The status pill, which opens a menu to change it.
class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.status, required this.onChanged});

  final ContactRequestStatus status;
  final ValueChanged<ContactRequestStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fg, bg) = status.colors(scheme);
    return PopupMenuButton<ContactRequestStatus>(
      tooltip: 'Change status',
      initialValue: status,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      ),
      itemBuilder: (_) => [
        for (final s in ContactRequestStatus.values)
          PopupMenuItem(
            value: s,
            child: _MenuLabel(
              icon: s.icon,
              label: s.label,
              color: _accent(s, scheme),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: AppDimens.iconSm, color: fg),
            const SizedBox(width: AppDimens.spacing6),
            Text(
              status.label,
              style: TextStyle(
                fontSize: AppDimens.fontLabelLg,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: AppDimens.iconLg, color: fg),
          ],
        ),
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});

  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.isEmpty ? 'Add note' : 'Edit note'),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: ContactRequest.noteMaxLength,
          decoration: const InputDecoration(
            labelText: 'Admin note',
            hintText: 'Only admins see this',
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save note'),
        ),
      ],
    );
  }
}
