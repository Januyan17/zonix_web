import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/features/shops/models/shop.dart';
import 'package:zonixweb/features/shops/models/shop_trial.dart';
import 'package:zonixweb/features/shops/widgets/trial_status_badge.dart';

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
    required this.onExtend,
    this.onStartFor,
  });

  final Shop shop;

  /// Each callback persists one change and reports success/failure itself;
  /// this widget only needs the future to complete either way.
  final Future<void> Function(bool enabled) onToggle;
  final Future<void> Function(int days) onExtend;

  /// Starts a trial of a custom length (minutes). When null, the start
  /// dialog only offers the default [kDefaultTrialDays]-day trial.
  final Future<void> Function(Duration length)? onStartFor;

  @override
  State<TrialSection> createState() => _TrialSectionState();
}

class _TrialSectionState extends State<TrialSection> {
  bool _toggling = false;
  bool _extending = false;

  bool get _busy => _toggling || _extending;

  Future<void> _toggle(bool enable) async {
    Duration? customLength;
    if (enable) {
      final choice = await showDialog<_StartTrialChoice>(
        context: context,
        builder: (_) => _StartTrialDialog(
          shopName: widget.shop.name,
          allowMinutes: widget.onStartFor != null,
        ),
      );
      if (choice == null || !mounted) return;
      customLength = choice.customLength;
    }
    setState(() => _toggling = true);
    try {
      if (customLength != null) {
        await widget.onStartFor!(customLength);
      } else {
        await widget.onToggle(enable);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
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
              Text(
                'The lock message and payment contact are set once for '
                'all shops in Trial settings.',
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: colorScheme.onSurfaceVariant,
                ),
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
                ],
              ),
            ],
          ],
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

/// What the start dialog returns: [customLength] is null for the default
/// [kDefaultTrialDays]-day trial.
class _StartTrialChoice {
  const _StartTrialChoice(this.customLength);

  final Duration? customLength;
}

/// Confirms starting a trial, with an optional custom length in minutes
/// (handy for testing the mobile app's lock without waiting days).
class _StartTrialDialog extends StatefulWidget {
  const _StartTrialDialog({required this.shopName, required this.allowMinutes});

  final String shopName;
  final bool allowMinutes;

  @override
  State<_StartTrialDialog> createState() => _StartTrialDialogState();
}

class _StartTrialDialogState extends State<_StartTrialDialog> {
  bool _useMinutes = false;
  final _minutesController = TextEditingController(text: '5');
  String? _error;

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_useMinutes) {
      Navigator.of(context).pop(const _StartTrialChoice(null));
      return;
    }
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1 || minutes > 60 * 24 * 365) {
      setState(() => _error = 'Enter minutes (1 or more)');
      return;
    }
    Navigator.of(context).pop(_StartTrialChoice(Duration(minutes: minutes)));
  }

  @override
  Widget build(BuildContext context) {
    final length = _useMinutes
        ? '${_minutesController.text.trim()}-minute'
        : '$kDefaultTrialDays-day';
    return AlertDialog(
      title: const Text('Start free trial?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start a $length trial for ${widget.shopName}? '
            'When it ends, the app will be locked until you turn this off.',
          ),
          if (widget.allowMinutes) ...[
            const SizedBox(height: AppDimens.spacing16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('$kDefaultTrialDays days'),
                  icon: Icon(Icons.calendar_today_outlined, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Minutes'),
                  icon: Icon(Icons.timer_outlined, size: 16),
                ),
              ],
              selected: {_useMinutes},
              onSelectionChanged: (v) => setState(() {
                _useMinutes = v.first;
                _error = null;
              }),
              showSelectedIcon: false,
            ),
            if (_useMinutes) ...[
              const SizedBox(height: AppDimens.spacing16),
              TextField(
                controller: _minutesController,
                autofocus: true,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Trial length (minutes)',
                  helperText: 'For testing the lock screen',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.timer_outlined),
                ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Start trial')),
      ],
    );
  }
}
