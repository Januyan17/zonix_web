import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/error_banner.dart';
import 'package:zonixweb/core/widgets/page_header.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/join_contact/models/join_contact_config.dart';
import 'package:zonixweb/features/join_contact/services/join_contact_service.dart';
import 'package:zonixweb/features/join_contact/widgets/join_contact_preview.dart';
import 'package:zonixweb/features/shell/widgets/admin_shell.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

/// Controls the "Contact Zonix — I would like to join" button on the mobile
/// app's shop code screen, through `platform_config/joinContact`.
class JoinContactScreen extends StatefulWidget {
  const JoinContactScreen({
    super.key,
    required this.authService,
    required this.shopService,
    this.joinContactService,
  });

  final AuthService authService;
  final ShopService shopService;
  final JoinContactService? joinContactService;

  @override
  State<JoinContactScreen> createState() => _JoinContactScreenState();
}

class _JoinContactScreenState extends State<JoinContactScreen> {
  late final JoinContactService _service =
      widget.joinContactService ?? JoinContactService();

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _enabled = false;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_refresh);
    _messageController.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Keeps the preview and the character counter live.
  void _refresh() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final config = await _service.read();
      if (!mounted) return;
      setState(() {
        _enabled = config.enabled;
        _phoneController.text = config.phone;
        _messageController.text = config.message;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await _service.save(
        enabled: _enabled,
        phone: _phoneController.text,
        message: _messageController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join contact settings saved')),
      );
      await _load();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = e.code == 'permission-denied'
          ? 'Firestore rejected the write (permission-denied). Check that '
                'the platform_config/joinContact rules are deployed and that '
                'this account is a platform admin.'
          : 'Failed to save: ${describeError(e)}';
      setState(() => _saveError = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      final message = 'Failed to save: ${describeError(e)}';
      setState(() => _saveError = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      authService: widget.authService,
      shopService: widget.shopService,
      current: AdminPage.joinContact,
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
              Text('Could not load join contact settings.\n$_loadError'),
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
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeader(
                  icon: Icons.support_agent_rounded,
                  tag: 'Onboarding',
                  title: 'Join contact',
                  subtitle:
                      'The "Contact Zonix — I would like to join" button on '
                      'the mobile app\'s shop code screen.',
                ),
                const SizedBox(height: AppDimens.spacing20),
                _buildSettingsCard(),
                const SizedBox(height: AppDimens.spacing16),
                _buildPreviewCard(),
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
                      : const Text('Save join contact settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.call_outlined,
              label: 'Button and contact',
            ),
            const SizedBox(height: AppDimens.spacing8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Show 'Contact Zonix' button on the shop code screen",
              ),
              value: _enabled,
              onChanged: (v) {
                setState(() => _enabled = v);
                // Re-check the phone: it is only required while shown.
                _formKey.currentState?.validate();
              },
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: JoinContactConfig.phoneMaxLength,
              decoration: InputDecoration(
                labelText: _enabled
                    ? 'Phone number'
                    : 'Phone number (optional)',
                hintText: '+94 77 123 4567',
                prefixIcon: const Icon(Icons.phone_outlined),
                helperText: 'Required while the button is shown',
              ),
              validator: (v) => joinContactPhoneError(v, enabled: _enabled),
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _messageController,
              minLines: 3,
              maxLines: 6,
              maxLength: JoinContactConfig.messageMaxLength,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'Shown above the number in the popup',
                helperText: "Leave empty to use the app's default text",
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.visibility_outlined,
              label: 'Preview',
            ),
            const SizedBox(height: AppDimens.spacing8),
            Text(
              _enabled
                  ? 'How the popup looks in the app.'
                  : 'The button is hidden, so the app won\'t show this popup.',
              style: TextStyle(
                fontSize: AppDimens.fontLabel,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            Opacity(
              opacity: _enabled ? 1 : 0.5,
              child: JoinContactPreview(
                phone: _phoneController.text,
                message: _messageController.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
