import 'package:flutter/material.dart';

import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/date_format.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/utils/snackbar.dart';
import 'package:zonixweb/core/widgets/error_banner.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/core/widgets/zonix_chrome.dart';
import 'package:zonixweb/features/contact_zonix/models/join_contact_config.dart';
import 'package:zonixweb/features/contact_zonix/services/contact_request_service.dart';
import 'package:zonixweb/features/contact_zonix/services/join_contact_config_service.dart';
import 'package:zonixweb/features/contact_zonix/utils/sri_lanka_phone.dart';
import 'package:zonixweb/features/contact_zonix/widgets/join_contact_preview.dart';
import 'package:zonixweb/features/contact_zonix/widgets/supabase_setup_banner.dart';

/// Settings tab of Contact Zonix: the two independent toggles (phone
/// contact, request form), the number and the message, saved to the single
/// Supabase row `public.join_contact_config` (id = 1).
class ContactZonixSettingsScreen extends StatefulWidget {
  const ContactZonixSettingsScreen({
    super.key,
    required this.adminRecognised,
    required this.onRecheckAdmin,
    required this.onOpenRequests,
    this.service,
  });

  /// Result of `is_platform_admin()` for this page load; null while
  /// checking. Save is disabled unless true.
  final bool? adminRecognised;
  final VoidCallback onRecheckAdmin;
  final VoidCallback onOpenRequests;
  final JoinContactConfigService? service;

  @override
  State<ContactZonixSettingsScreen> createState() =>
      _ContactZonixSettingsScreenState();
}

class _ContactZonixSettingsScreenState
    extends State<ContactZonixSettingsScreen> {
  late final JoinContactConfigService _service =
      widget.service ?? JoinContactConfigService();
  final _feed = joinContactConfigFeed;

  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _phoneEnabled = false;
  bool _formEnabled = false;

  /// The row the form was last seeded from; edits are compared against it.
  JoinContactConfig? _baseline;

  /// The live row moved while there were unsaved edits.
  bool _changedElsewhere = false;

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // Seed before adding listeners: setState isn't allowed during initState.
    _applyFeed();
    _phoneController.addListener(_refresh);
    _messageController.addListener(_refresh);
    _feed.addListener(_onFeed);
    contactRequestsFeed.addListener(_refresh);
  }

  @override
  void dispose() {
    _feed.removeListener(_onFeed);
    contactRequestsFeed.removeListener(_refresh);
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  JoinContactConfig get _edited => JoinContactConfig(
    phoneEnabled: _phoneEnabled,
    phone: _phoneController.text.trim(),
    requestFormEnabled: _formEnabled,
    message: _messageController.text.trim(),
  );

  bool get _dirty {
    final base = _baseline;
    return base != null && !_edited.sameValuesAs(base);
  }

  /// Seeds the form from the live row, but never over unsaved edits: then
  /// it only flags that another admin changed it.
  void _onFeed() {
    _applyFeed();
    _refresh();
  }

  void _applyFeed() {
    final live = _feed.value;
    if (live == null) return;
    final base = _baseline;
    if (base == null || !_dirty) {
      _seed(live);
    } else if (!live.sameValuesAs(base)) {
      _changedElsewhere = !live.sameValuesAs(_edited);
      _baseline = JoinContactConfig(
        phoneEnabled: base.phoneEnabled,
        phone: base.phone,
        requestFormEnabled: base.requestFormEnabled,
        message: base.message,
        updatedAt: live.updatedAt,
      );
    }
  }

  void _seed(JoinContactConfig config) {
    _baseline = config;
    _changedElsewhere = false;
    _phoneEnabled = config.phoneEnabled;
    _formEnabled = config.requestFormEnabled;
    // Only touch the text when it differs, so the cursor isn't reset.
    if (_phoneController.text != config.phone) {
      _phoneController.text = config.phone;
    }
    if (_messageController.text != (config.message ?? '')) {
      _messageController.text = config.message ?? '';
    }
    _saveError = null;
  }

  void _reload() {
    final live = _feed.value;
    if (live != null) setState(() => _seed(live));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final saved = await _service.save(
        phoneEnabled: _phoneEnabled,
        phone: _phoneController.text,
        requestFormEnabled: _formEnabled,
        message: _messageController.text,
      );
      if (!mounted) return;
      setState(() => _seed(saved));
      showSnackBarMessage(context, 'Contact Zonix settings saved');
    } catch (e) {
      if (!mounted) return;
      final message =
          'Failed to save: ${describeError(e)}. If this keeps happening, '
          'Supabase may not recognise this admin.';
      setState(() => _saveError = message);
      showSnackBarMessage(context, 'Failed to save Contact Zonix settings');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recognised = widget.adminRecognised;
    final live = _feed.value;

    Widget content;
    if (_feed.loading) {
      content = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (live == null && _baseline == null) {
      content = ErrorBanner(
        message: _feed.error != null
            ? 'Could not load the settings: ${_feed.error}'
            : 'The join_contact_config row (id = 1) was not found. Run the '
                  'join_contact_config migration in Supabase.',
      );
    } else {
      content = _buildForm(recognised == true);
    }

    return SingleChildScrollView(
      padding: AppDimens.paddingAll24,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recognised == false) ...[
                SupabaseSetupBanner(onRetry: widget.onRecheckAdmin),
                const SizedBox(height: AppDimens.spacing16),
              ],
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool canSave) {
    final colorScheme = Theme.of(context).colorScheme;
    final updatedAt = _baseline?.updatedAt;
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_changedElsewhere) ...[
            Card(
              color: colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.sync_problem_rounded),
                title: const Text('Updated by another admin, reload?'),
                subtitle: const Text('Reloading discards your unsaved edits.'),
                trailing: TextButton(
                  onPressed: _reload,
                  child: const Text('Reload'),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
          ],
          _buildPhoneCard(),
          const SizedBox(height: AppDimens.spacing16),
          _buildFormCard(),
          const SizedBox(height: AppDimens.spacing16),
          _buildMessageCard(),
          const SizedBox(height: AppDimens.spacing16),
          _buildPreviewCard(),
          if (_saveError != null) ...[
            const SizedBox(height: AppDimens.spacing16),
            ErrorBanner(message: _saveError!),
          ],
          const SizedBox(height: AppDimens.spacing20),
          Row(
            children: [
              Expanded(
                child: Text(
                  updatedAt == null
                      ? 'Never updated'
                      : 'Last updated ${formatRelativeDate(updatedAt.toLocal())}',
                  style: TextStyle(
                    fontSize: AppDimens.fontLabel,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: canSave && _dirty && !_saving ? _save : null,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppDimens.spacing2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.spacing12),
        NeonSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildPhoneCard() {
    final formatted = formatSriLankaPhone(_phoneController.text);
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.call_outlined,
              label: 'Phone contact',
            ),
            const SizedBox(height: AppDimens.spacing12),
            _switchRow(
              title: 'Phone contact (Call & WhatsApp)',
              subtitle:
                  'Shows the number with Call Now and WhatsApp buttons. '
                  'Turning it off keeps the number saved.',
              value: _phoneEnabled,
              onChanged: (v) {
                setState(() => _phoneEnabled = v);
                _formKey.currentState?.validate();
              },
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: JoinContactConfig.phoneMaxLength,
              decoration: InputDecoration(
                labelText: 'Contact number',
                hintText: '0771234567',
                prefixIcon: const Icon(Icons.phone_outlined),
                helperText: formatted != null
                    ? 'Shown in the app as $formatted'
                    : 'Required while phone contact is on',
              ),
              validator: (v) {
                if (!_phoneEnabled) return null;
                if ((v ?? '').trim().isEmpty) {
                  return 'Enter a number, or turn phone contact off';
                }
                return isValidSriLankaPhone(v)
                    ? null
                    : 'Enter a valid Sri Lankan number, e.g. 0771234567';
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final newCount = newContactRequestCount();
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.assignment_outlined,
              label: 'Request form',
            ),
            const SizedBox(height: AppDimens.spacing12),
            _switchRow(
              title: 'Request form',
              subtitle:
                  'Shows "Send a Request". While off, new requests are '
                  'refused, even from an app that still has the form open. '
                  'Requests already sent stay in the inbox.',
              value: _formEnabled,
              onChanged: (v) => setState(() => _formEnabled = v),
            ),
            const SizedBox(height: AppDimens.spacing12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onOpenRequests,
                icon: Badge(
                  isLabelVisible: newCount > 0,
                  label: Text('$newCount'),
                  child: const Icon(Icons.inbox_outlined),
                ),
                label: Text(
                  newCount == 0
                      ? 'Open Contact Requests'
                      : 'Open Contact Requests · $newCount new',
                ),
              ),
            ),
            if (contactRequestsFeed.error != null)
              Text(
                'Requests could not be loaded: ${contactRequestsFeed.error}',
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard() {
    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
            ),
            const SizedBox(height: AppDimens.spacing16),
            TextFormField(
              controller: _messageController,
              minLines: 3,
              maxLines: 6,
              maxLength: JoinContactConfig.messageMaxLength,
              decoration: const InputDecoration(
                labelText: 'Message at the top of the sheet (optional)',
                helperText:
                    "Leave empty to use the app's default text, which is "
                    'already worded for phone only, form only or both.',
                helperMaxLines: 2,
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
        padding: AppDimens.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              icon: Icons.visibility_outlined,
              label: 'Preview in the app',
            ),
            const SizedBox(height: AppDimens.spacing4),
            Text(
              'Reflects your unsaved changes.',
              style: TextStyle(
                fontSize: AppDimens.fontLabel,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimens.spacing16),
            JoinContactPreview(
              phoneEnabled: _phoneEnabled,
              phone: _phoneController.text,
              requestFormEnabled: _formEnabled,
              message: _messageController.text,
            ),
          ],
        ),
      ),
    );
  }
}
