import 'package:flutter/material.dart';

import '../../../models/device_login.dart';
import '../../../services/device_login_service.dart';
import '../../../services/shop_service.dart';
import '../../../theme/app_dimens.dart';
import '../../../utils/device_login_badges.dart';
import '../../../utils/error_utils.dart';
import '../../../widgets/device_login_tile.dart';
import '../../device_logins_screen.dart';

/// The shop's last few first-logins-per-install, with a link to the full
/// Device logins screen filtered to this shop. Self-contained: it does its
/// own single read (no listener) and a failure here never affects the rest
/// of the shop page.
class RecentDeviceLoginsSection extends StatefulWidget {
  const RecentDeviceLoginsSection({
    super.key,
    required this.shopId,
    required this.shopService,
    this.deviceLoginService,
  });

  final String shopId;
  final ShopService shopService;
  final DeviceLoginService? deviceLoginService;

  static const count = 5;

  @override
  State<RecentDeviceLoginsSection> createState() =>
      _RecentDeviceLoginsSectionState();
}

class _RecentDeviceLoginsSectionState extends State<RecentDeviceLoginsSection> {
  late final DeviceLoginService _service =
      widget.deviceLoginService ?? DeviceLoginService();

  List<DeviceLogin> _logins = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.fetchPage(
        shopId: widget.shopId,
        limit: RecentDeviceLoginsSection.count,
      );
      if (mounted) setState(() => _logins = page.logins);
    } catch (e) {
      // Shown verbatim: a missing composite index fails with a message that
      // contains the link to create it.
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _viewAll() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceLoginsScreen.subPage(
          shopService: widget.shopService,
          initialShopId: widget.shopId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.phonelink_lock_rounded,
              size: AppDimens.iconLg,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppDimens.spacing8),
            Text(
              'Recent device logins',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded, size: AppDimens.iconLg),
            ),
            TextButton(onPressed: _viewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: AppDimens.spacing10),
        Card(clipBehavior: Clip.antiAlias, child: _buildContent(colorScheme)),
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    if (_loading) {
      return const Padding(
        padding: AppDimens.paddingAll20,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: AppDimens.paddingAll20,
        child: SelectableText(
          'Could not load device logins: $_error',
          style: TextStyle(
            fontSize: AppDimens.fontBody,
            color: colorScheme.error,
          ),
        ),
      );
    }
    if (_logins.isEmpty) {
      return Padding(
        padding: AppDimens.paddingAll20,
        child: Text(
          'No device logins yet.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    final repeats = repeatInstallKeys(_logins);
    return Column(
      children: [
        for (var i = 0; i < _logins.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          DeviceLoginTile(
            login: _logins[i],
            showShop: false,
            repeatInstall: isRepeatInstall(_logins[i], repeats),
          ),
        ],
      ],
    );
  }
}
