import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';

/// Typed confirmation for raising the floor — the only edit on this page
/// that can lock a device out. The admin has to retype the build number.
class ConfirmRaiseFloorDialog extends StatefulWidget {
  const ConfirmRaiseFloorDialog({
    super.key,
    required this.newMinSupportedBuild,
    required this.androidDownloadUrl,
  });

  final int newMinSupportedBuild;
  final String androidDownloadUrl;

  @override
  State<ConfirmRaiseFloorDialog> createState() =>
      _ConfirmRaiseFloorDialogState();
}

class _ConfirmRaiseFloorDialogState extends State<ConfirmRaiseFloorDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final expected = '${widget.newMinSupportedBuild}';
    final matches = _controller.text.trim() == expected;
    final blockedAtOrBelow = widget.newMinSupportedBuild - 1;

    return AlertDialog(
      title: const Text('Lock out older builds?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Every device on build $blockedAtOrBelow or lower will be '
              'locked out of Zonix until it updates. Confirm the new build '
              'is actually downloadable at the link above.',
            ),
            const SizedBox(height: AppDimens.spacing12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.spacing10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              ),
              child: Text(
                widget.androidDownloadUrl.isEmpty
                    ? 'No Android download URL set'
                    : widget.androidDownloadUrl,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppDimens.fontBody,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            Text('Type $expected to confirm.'),
            const SizedBox(height: AppDimens.spacing8),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Build number'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Lock out older builds'),
        ),
      ],
    );
  }
}
