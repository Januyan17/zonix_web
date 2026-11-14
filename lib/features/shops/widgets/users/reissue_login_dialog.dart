import 'package:flutter/material.dart';
import 'package:zonixweb/core/widgets/credential_row.dart';
import 'package:zonixweb/core/widgets/password_field.dart';
import 'package:zonixweb/features/shops/models/shop_user.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

class ReissueRequest {
  const ReissueRequest({required this.username, required this.password});

  final String username;
  final String password;
}

class ReissueLoginDialog extends StatefulWidget {
  const ReissueLoginDialog({super.key, required this.user});

  final ShopUser user;

  @override
  State<ReissueLoginDialog> createState() => _ReissueLoginDialogState();
}

class _ReissueLoginDialogState extends State<ReissueLoginDialog> {
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
