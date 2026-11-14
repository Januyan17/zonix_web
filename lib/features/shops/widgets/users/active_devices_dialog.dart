import 'package:flutter/material.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/delete_confirm_dialog.dart';
import 'package:zonixweb/core/widgets/dialog_header.dart';
import 'package:zonixweb/features/shops/models/shop_user.dart';
import 'package:zonixweb/features/shops/models/user_session.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

/// List of a user's currently-logged-in devices, each with a "Logout"
/// button. A session doc existing means that device is presently active —
/// there's no historical list to page through. Logging out a device just
/// deletes its session doc; the mobile app listens to that doc in real
/// time and force-signs-out immediately once it's gone.
class ActiveDevicesDialog extends StatefulWidget {
  const ActiveDevicesDialog({
    super.key,
    required this.shopService,
    required this.slug,
    required this.user,
    required this.maxActiveDevices,
  });

  final ShopService shopService;
  final String slug;
  final ShopUser user;

  /// The shop's configured cap for this user's role (max_active_devices_staff
  /// or _owner), shown here for context — editing it happens on the shop
  /// settings panel, not this dialog.
  final int maxActiveDevices;

  @override
  State<ActiveDevicesDialog> createState() => _ActiveDevicesDialogState();
}

class _ActiveDevicesDialogState extends State<ActiveDevicesDialog> {
  bool _loading = true;
  Object? _error;
  List<UserSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sessions = await widget.shopService.getUserSessions(
        slug: widget.slug,
        uid: widget.user.id,
      );
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout(UserSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmDialog(
        title: 'Log out this device?',
        message:
            '"${session.deviceName}" will be signed out immediately. '
            'They can sign back in as long as they\'re under the device limit.',
        confirmLabel: 'Log out',
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.shopService.deleteUserSession(
        slug: widget.slug,
        uid: widget.user.id,
        deviceId: session.deviceId,
      );
      if (mounted) {
        setState(
          () => _sessions = _sessions
              .where((s) => s.deviceId != session.deviceId)
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log out device: ${describeError(e)}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogHeader(
                icon: Icons.devices_outlined,
                title: 'Active devices',
                subtitle: widget.user.displayName,
              ),
              const SizedBox(height: 8),
              Text(
                'Device limit: ${widget.maxActiveDevices} '
                '(${widget.user.role == 'owner' ? 'owner/admin' : 'staff'})',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Text(
                  'Failed to load devices: ${describeError(_error!)}',
                  style: TextStyle(color: colorScheme.error, fontSize: 13),
                )
              else if (_sessions.isEmpty)
                Text(
                  'No devices currently logged in.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in _sessions) ...[
                      _SessionRow(session: s, onLogout: () => _logout(s)),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onLogout});

  final UserSession session;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.smartphone_outlined,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.deviceName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                formatRelativeDate(session.loggedInAt),
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onLogout,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.error,
            minimumSize: const Size(40, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }
}
