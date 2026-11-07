import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_version_config.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../theme/app_dimens.dart';
import '../utils/app_version_validation.dart';
import '../utils/date_format.dart';
import '../utils/error_utils.dart';
import '../widgets/admin_shell.dart';
import 'shop_detail/widgets/info_rows.dart';

/// Controls the forced-update gate in the Zonix mobile app, by writing the
/// single document `platform_config/appVersion`. The app is already shipped
/// and reads this on cold start and on every resume from background.
///
/// The two numbers on this page are BUILD NUMBERS — the integer after "+" in
/// the app's pubspec version, also its Android versionCode. Raising the
/// floor above a build people cannot download yet locks every device out
/// with nothing to install, which is what the typed confirmation exists to
/// prevent.
class AppVersionScreen extends StatefulWidget {
  const AppVersionScreen({
    super.key,
    required this.authService,
    required this.shopService,
    this.appVersionService,
  });

  final AuthService authService;
  final ShopService shopService;
  final AppVersionService? appVersionService;

  @override
  State<AppVersionScreen> createState() => _AppVersionScreenState();
}

class _AppVersionScreenState extends State<AppVersionScreen> {
  late final AppVersionService _service =
      widget.appVersionService ?? AppVersionService();

  final _formKey = GlobalKey<FormState>();
  final _minController = TextEditingController();
  final _latestController = TextEditingController();
  final _androidUrlController = TextEditingController();
  final _iosUrlController = TextEditingController();
  final _messageController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;

  /// The last values read back from Firestore, or null when the document
  /// does not exist yet. Also the baseline for "is the floor increasing?".
  AppVersionConfig? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minController.dispose();
    _latestController.dispose();
    _androidUrlController.dispose();
    _iosUrlController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final config = await _service.read();
      if (!mounted) return;
      setState(() {
        _saved = config;
        // An absent document is not an error — until it exists the app
        // blocks nobody. Start the form at the "block nobody" resting
        // state rather than inventing a floor.
        _minController.text = '${config?.minSupportedBuild ?? 0}';
        _latestController.text = config == null ? '' : '${config.latestBuild}';
        _androidUrlController.text = config?.androidDownloadUrl ?? '';
        _iosUrlController.text = config?.iosDownloadUrl ?? '';
        _messageController.text = config?.message ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = describeError(e);
        _loading = false;
      });
    }
  }

  int get _currentMin => _saved?.minSupportedBuild ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newMin = int.parse(_minController.text.trim());
    final newLatest = int.parse(_latestController.text.trim());

    // Only an increase to the floor locks anyone out. Lowering it, or
    // editing any other field, saves straight away.
    if (newMin > _currentMin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmRaiseFloorDialog(
          newMinSupportedBuild: newMin,
          androidDownloadUrl: _androidUrlController.text.trim(),
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _service.save(
        minSupportedBuild: newMin,
        latestBuild: newLatest,
        androidDownloadUrl: _androidUrlController.text.trim(),
        iosDownloadUrl: _iosUrlController.text.trim(),
        message: _messageController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App version settings saved')),
      );
      await _load();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(
        () => _saveError = e.code == 'permission-denied'
            ? 'Firestore rejected the write (permission-denied). Check that '
                  'the platform_config/appVersion rules are deployed and that '
                  'this account is a super admin.'
            : 'Failed to save: ${describeError(e)}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveError = 'Failed to save: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: widget.authService,
      shopService: widget.shopService,
      current: AdminPage.appVersion,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: AppDimens.paddingAll24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load app version settings.\n$_loadError'),
              const SizedBox(height: AppDimens.spacing16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppDimens.paddingAll24,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CurrentStateCard(saved: _saved),
                const SizedBox(height: AppDimens.spacing16),
                const _ReleaseOrderCard(),
                const SizedBox(height: AppDimens.spacing16),
                _buildBuildNumbersCard(),
                const SizedBox(height: AppDimens.spacing16),
                _buildDownloadCard(),
                const SizedBox(height: AppDimens.spacing16),
                _buildMessageCard(),
                if (_saveError != null) ...[
                  const SizedBox(height: AppDimens.spacing16),
                  _ErrorBanner(message: _saveError!),
                ],
                const SizedBox(height: AppDimens.spacing20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save app version settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuildNumbersCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.numbers_rounded,
              label: 'Build numbers',
            ),
            const SizedBox(height: AppDimens.spacing8),
            Text(
              'These are build numbers — the integer after the "+" in the '
              'app\'s pubspec version, which is also its Android '
              'versionCode. Never the dotted "1.0.3" string: as text, '
              '"1.0.10" sorts below "1.0.9". One floor covers both '
              'platforms, because both are built from that same version.',
              style: TextStyle(
                fontSize: AppDimens.fontBody,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _minController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Block versions below',
                prefixIcon: Icon(Icons.block_rounded, color: colorScheme.error),
                helperText:
                    'Hard block. Devices on a lower build get a full-screen '
                    '"Update required" and cannot use Zonix at all. 0 blocks '
                    'nobody.',
                helperMaxLines: 3,
              ),
              validator: (v) {
                final error = buildNumberError(v, min: 0);
                if (error != null) return error;
                final latest = int.tryParse(_latestController.text.trim());
                if (latest == null) return null;
                return buildOrderError(
                  minSupportedBuild: int.parse(v!.trim()),
                  latestBuild: latest,
                );
              },
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _latestController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Suggest updating below',
                prefixIcon: Icon(Icons.upgrade_rounded),
                helperText:
                    'The newest build that has been distributed. Devices on a '
                    'lower build get a dismissible nudge — not a block.',
                helperMaxLines: 3,
              ),
              // Revalidate the floor too: the order error belongs to the pair,
              // and editing this field can clear or cause it.
              onChanged: (_) => _formKey.currentState?.validate(),
              validator: (v) => buildNumberError(v, min: 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.download_rounded,
              label: 'Where the update comes from',
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _androidUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Android download URL',
                prefixIcon: Icon(Icons.android_rounded),
                helperText:
                    'A direct .apk link today, a Play listing later. The app '
                    'opens it externally either way. Required once the block '
                    'is above 0.',
                helperMaxLines: 3,
              ),
              validator: (v) => androidDownloadUrlError(
                v,
                minSupportedBuild:
                    int.tryParse(_minController.text.trim()) ?? 0,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _iosUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'iOS download URL (optional)',
                prefixIcon: Icon(Icons.apple_rounded),
                helperText:
                    'A TestFlight link today. Leave empty until there is an '
                    'iOS build.',
                helperMaxLines: 2,
              ),
              validator: iosDownloadUrlError,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Custom message',
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message shown in the app (optional)',
                helperText:
                    'Replaces the app\'s default copy on both the block '
                    'screen and the nudge. Leave empty for the default.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is live right now, so a second admin can see the state before
/// touching it.
class _CurrentStateCard extends StatelessWidget {
  const _CurrentStateCard({required this.saved});

  final AppVersionConfig? saved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = saved;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.fact_check_outlined,
              label: 'Currently live',
            ),
            const SizedBox(height: AppDimens.spacing16),
            if (config == null)
              Text(
                'No settings have been published yet — the '
                'platform_config/appVersion document does not exist. Until '
                'it does, the app blocks nobody, which is the correct '
                'default. Saving below creates it.',
                style: TextStyle(
                  fontSize: AppDimens.fontBody,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              InfoRow(
                icon: Icons.block_rounded,
                label: 'Blocking',
                value: config.minSupportedBuild == 0
                    ? 'Nobody (floor is 0)'
                    : 'Builds below ${config.minSupportedBuild}',
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.upgrade_rounded,
                label: 'Nudging',
                value: 'Builds below ${config.latestBuild}',
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.android_rounded,
                label: 'Android',
                value: config.androidDownloadUrl.isEmpty
                    ? 'Not set'
                    : config.androidDownloadUrl,
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.apple_rounded,
                label: 'iOS',
                value: config.iosDownloadUrl.isEmpty
                    ? 'Not set'
                    : config.iosDownloadUrl,
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.history_rounded,
                label: 'Last change',
                value: config.updatedAt == null
                    ? 'Unknown'
                    : '${formatRelativeDate(config.updatedAt!)} '
                          '(${formatShortDate(config.updatedAt!)})',
              ),
              const SizedBox(height: AppDimens.spacing10),
              InfoRow(
                icon: Icons.person_outline,
                label: 'Changed by',
                value: config.updatedBy ?? 'Unknown',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Static help text. The order matters: raising the floor before the build
/// is actually downloadable locks every device out with nothing to install.
class _ReleaseOrderCard extends StatelessWidget {
  const _ReleaseOrderCard();

  static const _steps = [
    'Build the app, and note the build number after the "+" in pubspec.',
    'Upload the APK and open the link on a phone to confirm it downloads.',
    'Only then raise "Block versions below" here.',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              icon: Icons.checklist_rtl_rounded,
              label: 'Release order',
            ),
            const SizedBox(height: AppDimens.spacing12),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spacing8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: AppDimens.fontCaption,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimens.spacing10),
                    Expanded(
                      child: Text(
                        _steps[i],
                        style: const TextStyle(fontSize: AppDimens.fontBody),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Typed confirmation for raising the floor — the only edit on this page
/// that can lock a device out. The admin has to retype the build number.
class _ConfirmRaiseFloorDialog extends StatefulWidget {
  const _ConfirmRaiseFloorDialog({
    required this.newMinSupportedBuild,
    required this.androidDownloadUrl,
  });

  final int newMinSupportedBuild;
  final String androidDownloadUrl;

  @override
  State<_ConfirmRaiseFloorDialog> createState() =>
      _ConfirmRaiseFloorDialogState();
}

class _ConfirmRaiseFloorDialogState extends State<_ConfirmRaiseFloorDialog> {
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacing12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: AppDimens.iconXl,
          ),
          const SizedBox(width: AppDimens.spacing8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconLg, color: colorScheme.primary),
        const SizedBox(width: AppDimens.spacing8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
