import 'package:flutter/material.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/utils/snackbar.dart';
import 'package:zonixweb/core/widgets/delete_confirm_dialog.dart';
import 'package:zonixweb/features/device_logins/models/device_login.dart';
import 'package:zonixweb/features/device_logins/services/device_login_service.dart';

/// Asks for confirmation, then deletes [installs] from `device_logins`.
/// Returns true only when the delete went through, so the caller can drop
/// the rows locally instead of re-reading the list (no extra reads).
Future<bool> confirmAndDeleteDeviceHistory(
  BuildContext context, {
  required DeviceLoginService service,
  required List<DeviceLogin> installs,
}) async {
  if (installs.isEmpty) return false;
  final first = installs.first;
  final device = first.deviceName.isNotEmpty ? first.deviceName : 'this device';
  final installCount = {
    for (final l in installs) l.deviceId.isNotEmpty ? l.deviceId : l.id,
  }.length;
  final single = installCount == 1;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => DeleteConfirmDialog(
      title: single ? 'Delete install record?' : 'Delete device history?',
      message:
          '${single ? 'This install record' : 'All $installCount install records'} '
          'of ${first.userLabel} on $device will be permanently deleted. '
          'This only removes history — it does not sign anyone out. '
          'If they reinstall the app, it will be logged again.',
      confirmLabel: 'Delete',
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    await service.deleteLogins(installs.map((l) => l.id));
    if (context.mounted) {
      showSnackBarMessage(
        context,
        single ? 'Install record deleted.' : 'Device history deleted.',
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      showSnackBarMessage(context, 'Could not delete: ${describeError(e)}');
    }
    return false;
  }
}
