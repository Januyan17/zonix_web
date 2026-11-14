import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/error_banner.dart';
import 'package:zonixweb/core/widgets/page_header.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/app_version/models/app_version_config.dart';
import 'package:zonixweb/features/app_version/services/app_version_service.dart';
import 'package:zonixweb/features/app_version/utils/app_version_validation.dart';
import 'package:zonixweb/features/app_version/widgets/build_numbers_card.dart';
import 'package:zonixweb/features/app_version/widgets/confirm_raise_floor_dialog.dart';
import 'package:zonixweb/features/app_version/widgets/current_state_card.dart';
import 'package:zonixweb/features/app_version/widgets/release_order_card.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

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
        builder: (_) => ConfirmRaiseFloorDialog(
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
                const PageHeader(
                  title: 'App version',
                  subtitle:
                      'Controls the forced-update gate in the Zonix mobile '
                      'app. Both numbers are build numbers.',
                ),
                const SizedBox(height: AppDimens.spacing20),
                CurrentStateCard(saved: _saved),
                const SizedBox(height: AppDimens.spacing16),
                const ReleaseOrderCard(),
                const SizedBox(height: AppDimens.spacing16),
                BuildNumbersCard(
                  minController: _minController,
                  latestController: _latestController,
                  onLatestChanged: () => _formKey.currentState?.validate(),
                ),
                const SizedBox(height: AppDimens.spacing16),
                _buildDownloadCard(),
                const SizedBox(height: AppDimens.spacing16),
                _buildMessageCard(),
                if (_saveError != null) ...[
                  const SizedBox(height: AppDimens.spacing16),
                  ErrorBanner(message: _saveError!),
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

  Widget _buildDownloadCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
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
            const SectionHeader(
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
