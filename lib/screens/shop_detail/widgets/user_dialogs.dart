import 'package:flutter/material.dart';

import '../../../models/shop_user.dart';
import '../../../models/user_session.dart';
import '../../../services/shop_service.dart';
import '../../../utils/date_format.dart';
import '../../../utils/error_utils.dart';
import '../../../widgets/credential_row.dart';
import 'delete_dialogs.dart';
import 'info_rows.dart';

class AddUserRequest {
  const AddUserRequest({
    required this.role,
    required this.displayName,
    required this.username,
    required this.password,
  });

  final String role;
  final String displayName;
  final String username;
  final String password;
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => AddUserDialogState();
}

class AddUserDialogState extends State<AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'staff';

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DialogHeader(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Add owner or staff',
                  subtitle: 'Creates a new login for this shop',
                ),
                const SizedBox(height: 22),
                RoleSelector(
                  role: _role,
                  onChanged: (v) => setState(() => _role = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          AddUserRequest(
                            role: _role,
                            displayName: _displayNameController.text.trim(),
                            username: _usernameController.text.trim(),
                            password: _passwordController.text,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add user'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Password input with a visibility-toggle icon, shared by the add-user and
/// reissue-login dialogs. Owns its own obscure/reveal state.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;

  @override
  State<PasswordField> createState() => PasswordFieldState();
}

class PasswordFieldState extends State<PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      obscureText: _obscureText,
      validator: (v) =>
          (v == null || v.length < 6) ? 'At least 6 characters' : null,
    );
  }
}

class EditUserRequest {
  const EditUserRequest({
    required this.displayName,
    required this.role,
    required this.isEnabled,
  });

  final String displayName;
  final String role;
  final bool isEnabled;
}

class EditUserDialog extends StatefulWidget {
  const EditUserDialog({super.key, required this.user});

  final ShopUser user;

  @override
  State<EditUserDialog> createState() => EditUserDialogState();
}

class EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _displayNameController = TextEditingController(
    text: widget.user.displayName,
  );
  late String _role = widget.user.role;
  late bool _isEnabled = widget.user.isEnabled;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DialogHeader(
                  icon: Icons.edit_outlined,
                  title: 'Edit user',
                  subtitle: widget.user.username,
                ),
                const SizedBox(height: 22),
                RoleSelector(
                  role: _role,
                  onChanged: (v) => setState(() => _role = v),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                Material(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: SwitchListTile(
                    title: const Text('Enabled'),
                    subtitle: const Text(
                      'Disabled users keep their record but can\'t sign in',
                    ),
                    value: _isEnabled,
                    onChanged: (v) => setState(() => _isEnabled = v),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          EditUserRequest(
                            displayName: _displayNameController.text.trim(),
                            role: _role,
                            isEnabled: _isEnabled,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReissueRequest {
  const ReissueRequest({required this.username, required this.password});

  final String username;
  final String password;
}

class ReissueLoginDialog extends StatefulWidget {
  const ReissueLoginDialog({super.key, required this.user});

  final ShopUser user;

  @override
  State<ReissueLoginDialog> createState() => ReissueLoginDialogState();
}

class ReissueLoginDialogState extends State<ReissueLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Reissue login for ${widget.user.displayName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The current login "${widget.user.username}" will stop working '
              'immediately. Give them a new username and password to sign in with.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'New username'),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Required';
                if (value == widget.user.username) {
                  return 'Must differ from the current username';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            PasswordField(
              controller: _passwordController,
              label: 'New password',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              ReissueRequest(
                username: _usernameController.text.trim(),
                password: _passwordController.text,
              ),
            );
          },
          child: const Text('Reissue login'),
        ),
      ],
    );
  }
}

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
  State<ActiveDevicesDialog> createState() => ActiveDevicesDialogState();
}

class ActiveDevicesDialogState extends State<ActiveDevicesDialog> {
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

class ReissueSuccessDialog extends StatelessWidget {
  const ReissueSuccessDialog({super.key, required this.result});

  final ReissueLoginResult result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Login reissued'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Relay these new credentials to them — the old login no longer works:',
          ),
          const SizedBox(height: 12),
          CredentialRow(label: 'Username', value: result.username),
          CredentialRow(
            label: 'Password',
            value: result.password,
            isSensitive: true,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
