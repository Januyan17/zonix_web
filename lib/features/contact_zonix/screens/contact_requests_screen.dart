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
import 'package:zonixweb/core/widgets/filter_row.dart';
import 'package:zonixweb/core/widgets/status_pill.dart';
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

    return ListView(
      padding: AppDimens.paddingAll24,
      children: [
        if (widget.adminRecognised == false) ...[
          SupabaseSetupBanner(onRetry: widget.onRecheckAdmin),
          const SizedBox(height: AppDimens.spacing16),
        ],
        if (_feed.error != null) ...[
          ErrorBanner(message: 'Could not load requests: ${_feed.error}'),
          const SizedBox(height: AppDimens.spacing16),
        ],
        Wrap(
          spacing: AppDimens.spacing16,
          runSpacing: AppDimens.spacing12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterRow<_Filter>(
              options: [
                for (final f in _Filter.values)
                  FilterOption(value: f, label: '${f.label} (${countFor(f)})'),
              ],
              selected: _filter,
              onSelect: (f) => setState(() => _filter = f),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search shop, owner, phone or city',
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _searchController.clear,
                        ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _feed.refreshing ? null : _manualRefresh,
              icon: _feed.refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spacing16),
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
              final wide = constraints.maxWidth >= 900;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (wide) const _TableHeader(),
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0 || wide) const Divider(height: 1),
                      _RequestRow(
                        key: ValueKey(visible[i].id),
                        request: visible[i],
                        wide: wide,
                        onStatus: (s) => _changeStatus(visible[i], s),
                        onNote: () => _editNote(visible[i]),
                        onDelete: () => _delete(visible[i]),
                      ),
                    ],
                  ],
                ),
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

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: AppDimens.fontLabel,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacing16,
        vertical: AppDimens.spacing10,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('SHOP', style: style)),
          Expanded(flex: 3, child: Text('CONTACT', style: style)),
          Expanded(flex: 4, child: Text('MESSAGE', style: style)),
          SizedBox(width: 150, child: Text('STATUS', style: style)),
          SizedBox(width: 196, child: Text('ACTIONS', style: style)),
        ],
      ),
    );
  }
}

/// One request: a table row on wide screens, a stacked card on narrow.
class _RequestRow extends StatefulWidget {
  const _RequestRow({
    super.key,
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
  State<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends State<_RequestRow> {
  bool _expanded = false;

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final muted = TextStyle(
      fontSize: AppDimens.fontLabel,
      color: colorScheme.onSurfaceVariant,
    );

    final shop = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          r.shopName.isEmpty ? '(no shop name)' : r.shopName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: ZonixColors.navy,
          ),
        ),
        const SizedBox(height: AppDimens.spacing2),
        Text(r.ownerName),
        const SizedBox(height: AppDimens.spacing2),
        Tooltip(
          message: formatShortDateTime(r.createdAt),
          child: Text(_ago(r.createdAt), style: muted),
        ),
      ],
    );

    final meta = [
      if (r.platform != null) r.platform!,
      if (r.appVersion != null) 'v${r.appVersion}',
    ].join(' · ');

    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          displaySriLankaPhone(r.phone),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (r.city != null) ...[
          const SizedBox(height: AppDimens.spacing2),
          Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: AppDimens.iconXs,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimens.spacing2),
              Flexible(child: Text(r.city!)),
            ],
          ),
        ],
        if (meta.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spacing2),
          Text(meta, style: muted),
        ],
      ],
    );

    final message = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.message == null)
          Text('No message', style: muted.copyWith(fontStyle: FontStyle.italic))
        else ...[
          Text(
            r.message!,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (r.message!.length > 140 || '\n'.allMatches(r.message!).length > 2)
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Show less' : 'Show more'),
            ),
        ],
        if (r.adminNote != null) ...[
          const SizedBox(height: AppDimens.spacing6),
          Container(
            padding: const EdgeInsets.all(AppDimens.spacing8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: AppDimens.iconXs,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimens.spacing6),
                Expanded(child: Text(r.adminNote!, style: muted)),
              ],
            ),
          ),
        ],
      ],
    );

    final status = _StatusMenu(status: r.status, onChanged: widget.onStatus);

    final whatsApp = sriLankaWhatsAppUri(r.phone);
    final actions = Wrap(
      spacing: 0,
      children: [
        IconButton(
          tooltip: 'Call',
          icon: const Icon(Icons.call_outlined),
          onPressed: sriLankaTelUri(r.phone) == null
              ? null
              : () => _open(sriLankaTelUri(r.phone)),
        ),
        IconButton(
          tooltip: whatsApp == null
              ? 'WhatsApp (mobile numbers only)'
              : 'WhatsApp',
          icon: const Icon(Icons.chat_outlined),
          onPressed: whatsApp == null ? null : () => _open(whatsApp),
        ),
        IconButton(
          tooltip: 'Copy number',
          icon: const Icon(Icons.copy_rounded),
          onPressed: _copy,
        ),
        IconButton(
          tooltip: r.adminNote == null ? 'Add note' : 'Edit note',
          icon: const Icon(Icons.edit_note_rounded),
          onPressed: widget.onNote,
        ),
        IconButton(
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
          onPressed: widget.onDelete,
        ),
      ],
    );

    if (widget.wide) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacing16,
          vertical: AppDimens.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: shop),
            const SizedBox(width: AppDimens.spacing12),
            Expanded(flex: 3, child: contact),
            const SizedBox(width: AppDimens.spacing12),
            Expanded(flex: 4, child: message),
            const SizedBox(width: AppDimens.spacing12),
            SizedBox(
              width: 138,
              child: Align(alignment: Alignment.topLeft, child: status),
            ),
            const SizedBox(width: AppDimens.spacing12),
            SizedBox(width: 196, child: actions),
          ],
        ),
      );
    }

    return Padding(
      padding: AppDimens.paddingAll14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: shop),
              status,
            ],
          ),
          const SizedBox(height: AppDimens.spacing10),
          contact,
          const SizedBox(height: AppDimens.spacing10),
          message,
          const SizedBox(height: AppDimens.spacing6),
          actions,
        ],
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
      itemBuilder: (_) => [
        for (final s in ContactRequestStatus.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(s.icon, size: 18),
                const SizedBox(width: AppDimens.spacing8),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill(label: status.label, fg: fg, bg: bg, icon: status.icon),
          Icon(Icons.arrow_drop_down_rounded, color: fg),
        ],
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
