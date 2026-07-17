import 'package:flutter/material.dart';

import '../../../models/shop_user.dart';
import '../../../services/shop_service.dart';
import '../../../widgets/credential_row.dart';
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
