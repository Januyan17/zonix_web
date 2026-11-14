import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';
import 'package:zonixweb/features/shops/widgets/trial_status_badge.dart';

/// The lock popup's optional text and contact, as edited in the section.
/// Blank values arrive as null.
class TrialDetailsResult {
  const TrialDetailsResult({required this.message, required this.contact});

  final String? message;
  final String? contact;
}

/// Accepts blank, a phone number, or an https:// link (wa.me, a payment
/// page). The mobile app calls a number and opens a link, so anything else
/// would leave the "Contact us to pay" button dead.
String? trialContactError(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (v.toLowerCase().startsWith('http')) {
    final uri = Uri.tryParse(v);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'Links must start with https://';
    }
    return null;
  }
  if (!RegExp(r'^\+?[0-9][0-9 ()\-]{5,}$').hasMatch(v)) {
    return 'Enter a phone number or an https:// link';
  }
  return null;
}

/// Per-shop free-trial controls. When the trial is on and its end passes,
/// the mobile app shows a lock popup that blocks the whole app until the
/// toggle is switched off here.
class TrialSection extends StatefulWidget {
  const TrialSection({
    super.key,
    required this.shop,
    required this.onToggle,
    required this.onSaveDetails,
    required this.onExtend,
  });

  final Shop shop;

  /// Each callback persists one change and reports success/failure itself;
  /// this widget only needs the future to complete either way.
  final Future<void> Function(bool enabled) onToggle;
  final Future<void> Function(TrialDetailsResult) onSaveDetails;
  final Future<void> Function(int days) onExtend;

  @override
  State<TrialSection> createState() => _TrialSectionState();
}

class _TrialSectionState extends State<TrialSection> {
  final _formKey = GlobalKey<FormState>();

  late final _messageController = TextEditingController(
    text: widget.shop.trial.message ?? '',
  )..addListener(_onChanged);
  late final _contactController = TextEditingController(
    text: widget.shop.trial.contact ?? '',
  )..addListener(_onChanged);

  bool _toggling = false;
  bool _savingDetails = false;
  bool _extending = false;

  bool get _busy => _toggling || _savingDetails || _extending;

  void _onChanged() => setState(() {});

  @override
  void didUpdateWidget(TrialSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed only when the stored value actually moved, so a reload of an
    // unrelated field doesn't clobber what the admin is typing.
    final trial = widget.shop.trial;
    final old = oldWidget.shop.trial;
    if (trial.message != old.message) {
      _messageController.text = trial.message ?? '';
    }
    if (trial.contact != old.contact) {
      _contactController.text = trial.contact ?? '';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  static String? _blankToNull(String v) => v.trim().isEmpty ? null : v.trim();

  bool get _detailsDirty {
    final trial = widget.shop.trial;
    return _blankToNull(_messageController.text) !=
            _blankToNull(trial.message ?? '') ||
        _blankToNull(_contactController.text) !=
            _blankToNull(trial.contact ?? '');
  }

  Future<void> _toggle(bool enable) async {
    if (enable) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start free trial?'),
          content: Text(
            'Start a $kDefaultTrialDays-day trial for ${widget.shop.name}? '
            'When it ends, the app will be locked until you turn this off.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start trial'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _toggling = true);
    try {
      await widget.onToggle(enable);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingDetails = true);
    try {
      await widget.onSaveDetails(
        TrialDetailsResult(
          message: _blankToNull(_messageController.text),
          contact: _blankToNull(_contactController.text),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingDetails = false);
    }
  }

  Future<void> _extend() async {
    final days = await showDialog<int>(
      context: context,
      builder: (_) => const _ExtendTrialDialog(),
    );
    if (days == null || !mounted) return;
    setState(() => _extending = true);
    try {
      await widget.onExtend(days);
    } finally {
      if (mounted) setState(() => _extending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trial = widget.shop.trial;
    final now = DateTime.now();
    final state = trial.stateAt(now);
    final end = trial.endsAt;

    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppDimens.spacing10,
                runSpacing: AppDimens.spacing6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TrialStatusBadge(trial: trial),
                  if (state != ShopTrialState.off && end != null)
                    Text(
                      '${state == ShopTrialState.ended ? 'Ended' : 'Ends'} '
                      '${formatShortDateTime(end)}',
                      style: TextStyle(
                        fontSize: AppDimens.fontLabel,
                        color: state == ShopTrialState.ended
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('$kDefaultTrialDays-day free trial'),
                subtitle: const Text(
                  'When the trial ends, the mobile app is locked until you '
                  'turn this off. Turn it off once the shop has paid.',
                ),
                value: trial.trialEnabled,
                onChanged: _busy ? null : _toggle,
              ),
              if (trial.trialEnabled) ...[
                const Divider(height: 1),
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
                const SizedBox(height: AppDimens.spacing16),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Payment contact',
                    hintText: '+94 77 123 4567 or https://wa.me/...',
                    helperText: 'Shown as a "Contact us to pay" button',
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                  validator: trialContactError,
                ),
                const SizedBox(height: AppDimens.spacing16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppDimens.spacing10,
                  runSpacing: AppDimens.spacing10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _extend,
                      icon: _extending
                          ? const SizedBox(
                              width: AppDimens.iconLg,
                              height: AppDimens.iconLg,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.more_time_outlined,
                              size: AppDimens.iconLg,
                            ),
                      label: const Text('Extend trial'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || !_detailsDirty ? null : _saveDetails,
                      icon: _savingDetails
                          ? const SizedBox(
                              width: AppDimens.iconLg,
                              height: AppDimens.iconLg,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.save_outlined,
                              size: AppDimens.iconLg,
                            ),
                      label: const Text('Save details'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks how many days to add to the trial.
class _ExtendTrialDialog extends StatefulWidget {
  const _ExtendTrialDialog();

  @override
  State<_ExtendTrialDialog> createState() => _ExtendTrialDialogState();
}

class _ExtendTrialDialogState extends State<_ExtendTrialDialog> {
  final _controller = TextEditingController(text: '$kDefaultTrialDays');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Extend trial'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Adds days to the current trial end. If the trial has already '
            'ended, the days count from now and the app unlocks.',
          ),
          const SizedBox(height: AppDimens.spacing16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Days to add'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final days = int.tryParse(_controller.text.trim());
            if (days == null || days < 1 || days > 3650) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enter a number of days (1 or more)'),
                ),
              );
              return;
            }
            Navigator.of(context).pop(days);
          },
          child: const Text('Extend'),
        ),
      ],
    );
  }
}
