import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/snackbar.dart';
import 'package:zonixweb/features/shops/models/trial_defaults.dart';
import 'package:zonixweb/features/shops/services/trial_defaults_service.dart';
import 'package:zonixweb/features/shops/widgets/settings/trial_section.dart';

/// Shows and edits the lock message and payment contact shared by every
/// shop's free trial. Set once here instead of on each shop; a shop's own
/// values (in the trial section) still take priority when filled in.
class TrialDefaultsCard extends StatefulWidget {
  const TrialDefaultsCard({super.key, this.service});

  /// Seam for tests. Defaults to a [TrialDefaultsService] on the default app.
  final TrialDefaultsService? service;

  @override
  State<TrialDefaultsCard> createState() => _TrialDefaultsCardState();
}

class _TrialDefaultsCardState extends State<TrialDefaultsCard> {
  late final TrialDefaultsService _service =
      widget.service ?? TrialDefaultsService();
  late final Stream<TrialDefaults> _stream = _service.watch();

  Future<void> _edit(TrialDefaults current) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditTrialDefaultsDialog(
        initial: current,
        onSave: (message, contact) =>
            _service.save(message: message, contact: contact),
      ),
    );
    if (saved == true && mounted) {
      showSnackBarMessage(context, 'Common trial details saved for all shops');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<TrialDefaults>(
      stream: _stream,
      builder: (context, snapshot) {
        final defaults = snapshot.data ?? TrialDefaults.empty;
        final loading = !snapshot.hasData && !snapshot.hasError;
        return Card(
          child: Padding(
            padding: AppDimens.paddingAll20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.public,
                      size: AppDimens.iconLg,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppDimens.spacing10),
                    const Expanded(
                      child: Text(
                        'Common for all shops',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: loading || snapshot.hasError
                          ? null
                          : () => _edit(defaults),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: AppDimens.iconLg,
                      ),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spacing6),
                Text(
                  'Shown on the trial-ended popup of every shop that has no '
                  'message or contact of its own.',
                  style: TextStyle(
                    fontSize: AppDimens.fontLabel,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimens.spacing16),
                if (snapshot.hasError)
                  Text(
                    snapshot.error.toString().contains('permission-denied')
                        ? 'Could not load common trial details: permission '
                              'denied. Deploy the Firestore rules that include '
                              'platform_config/trialDefaults.'
                        : 'Could not load common trial details.\n'
                              '${snapshot.error}',
                    style: TextStyle(color: colorScheme.error),
                  )
                else if (loading)
                  const LinearProgressIndicator()
                else ...[
                  _ValueRow(
                    icon: Icons.contact_phone_outlined,
                    label: 'Contact',
                    value: defaults.contact,
                  ),
                  const SizedBox(height: AppDimens.spacing10),
                  _ValueRow(
                    icon: Icons.message_outlined,
                    label: 'Message',
                    value: defaults.message,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimens.iconLg, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppDimens.spacing10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value ?? 'Not set (app default)',
                style: value == null
                    ? TextStyle(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditTrialDefaultsDialog extends StatefulWidget {
  const _EditTrialDefaultsDialog({required this.initial, required this.onSave});

  final TrialDefaults initial;
  final Future<void> Function(String? message, String? contact) onSave;

  @override
  State<_EditTrialDefaultsDialog> createState() =>
      _EditTrialDefaultsDialogState();
}

class _EditTrialDefaultsDialogState extends State<_EditTrialDefaultsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _contactController = TextEditingController(
    text: widget.initial.contact ?? '',
  );
  late final _messageController = TextEditingController(
    text: widget.initial.message ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_messageController.text, _contactController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnackBarMessage(context, 'Failed to save common trial details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Common trial details'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Used for every shop. A shop with its own message or contact '
                'keeps using its own.',
              ),
              const SizedBox(height: AppDimens.spacing16),
              TextFormField(
                controller: _contactController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Payment contact',
                  hintText: '+94 77 123 4567 or https://wa.me/...',
                  helperText: 'Shown as a "Contact us to pay" button',
                  prefixIcon: Icon(Icons.contact_phone_outlined),
                ),
                validator: trialContactError,
              ),
              const SizedBox(height: AppDimens.spacing16),
              TextFormField(
                controller: _messageController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Lock message',
                  hintText: 'e.g. payment instructions',
                  helperText: 'Leave empty to use the app\'s default text',
                  prefixIcon: Icon(Icons.message_outlined),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: AppDimens.iconLg,
                  height: AppDimens.iconLg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save for all shops'),
        ),
      ],
    );
  }
}
