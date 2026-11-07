import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../models/shop.dart';
import '../../../theme/app_dimens.dart';
import '../../../utils/shop_link_url.dart';

/// The five shop-link values as edited in the section, ready to be written.
/// A cleared input arrives here as null, never as an empty string.
class ShopLinksResult {
  const ShopLinksResult({
    required this.website,
    required this.facebook,
    required this.instagram,
    required this.tiktok,
    required this.linksEnabled,
  });

  final String? website;
  final String? facebook;
  final String? instagram;
  final String? tiktok;
  final bool linksEnabled;
}

/// Editor for the links whose QR codes the mobile app prints on receipts.
/// The four inputs hold raw values — a profile name for the socials, an
/// address for the website — and each shows a live preview of the QR code
/// that value will print, so the admin can see the code change as they type
/// rather than after a save-and-reprint round trip.
class ShopLinksSection extends StatefulWidget {
  const ShopLinksSection({super.key, required this.shop, required this.onSave});

  final Shop shop;

  /// Persists the edited values. Errors are surfaced by the caller; this
  /// widget only needs the future to complete either way.
  final Future<void> Function(ShopLinksResult) onSave;

  @override
  State<ShopLinksSection> createState() => _ShopLinksSectionState();
}

class _ShopLinksSectionState extends State<ShopLinksSection> {
  final _formKey = GlobalKey<FormState>();

  late final Map<ShopLinkPlatform, TextEditingController> _controllers = {
    for (final platform in ShopLinkPlatform.values)
      platform: TextEditingController(text: _storedValue(widget.shop, platform))
        // Every keystroke moves both the QR preview beside the field and
        // the enabled state of the Save button.
        ..addListener(_onChanged),
  };

  late bool _linksEnabled = widget.shop.shopLinksEnabled;
  bool _saving = false;

  static String? _storedValue(Shop shop, ShopLinkPlatform platform) {
    switch (platform) {
      case ShopLinkPlatform.website:
        return shop.website;
      case ShopLinkPlatform.facebook:
        return shop.facebook;
      case ShopLinkPlatform.instagram:
        return shop.instagram;
      case ShopLinkPlatform.tiktok:
        return shop.tiktok;
    }
  }

  void _onChanged() => setState(() {});

  @override
  void didUpdateWidget(ShopLinksSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed only from a shop whose stored values actually moved (a save, or
    // a reload that picked up someone else's write); rebuilds that carry the
    // same values must not clobber what the admin is currently typing.
    for (final platform in ShopLinkPlatform.values) {
      final incoming = _storedValue(widget.shop, platform);
      if (incoming != _storedValue(oldWidget.shop, platform)) {
        _controllers[platform]!.text = incoming ?? '';
      }
    }
    if (widget.shop.shopLinksEnabled != oldWidget.shop.shopLinksEnabled) {
      _linksEnabled = widget.shop.shopLinksEnabled;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _editedValue(ShopLinkPlatform platform) =>
      normalizeShopLink(_controllers[platform]!.text);

  bool get _isDirty {
    if (_linksEnabled != widget.shop.shopLinksEnabled) return true;
    return ShopLinkPlatform.values.any(
      (platform) =>
          _editedValue(platform) != _storedValue(widget.shop, platform),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        ShopLinksResult(
          website: _editedValue(ShopLinkPlatform.website),
          facebook: _editedValue(ShopLinkPlatform.facebook),
          instagram: _editedValue(ShopLinkPlatform.instagram),
          tiktok: _editedValue(ShopLinkPlatform.tiktok),
          linksEnabled: _linksEnabled,
        ),
      );
      // Show what was actually stored, so a value typed with stray padding
      // doesn't keep reading back as unsaved.
      for (final platform in ShopLinkPlatform.values) {
        _controllers[platform]!.text = _editedValue(platform) ?? '';
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: AppDimens.paddingAll20,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Printed as QR codes on this shop\'s receipts. Leave a field '
                'empty to drop its code from the receipt.',
                style: TextStyle(
                  fontSize: AppDimens.fontLabel,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.spacing16),
              _LinkField(
                platform: ShopLinkPlatform.website,
                icon: Icons.language_outlined,
                label: 'Website',
                hint: 'zonix.example.com',
                controller: _controllers[ShopLinkPlatform.website]!,
              ),
              const SizedBox(height: AppDimens.spacing16),
              _LinkField(
                platform: ShopLinkPlatform.facebook,
                icon: Icons.facebook_outlined,
                label: 'Facebook',
                hint: 'profile name, e.g. zonixpos',
                controller: _controllers[ShopLinkPlatform.facebook]!,
              ),
              const SizedBox(height: AppDimens.spacing16),
              _LinkField(
                platform: ShopLinkPlatform.instagram,
                icon: Icons.camera_alt_outlined,
                label: 'Instagram',
                hint: 'profile name, e.g. zonixpos',
                controller: _controllers[ShopLinkPlatform.instagram]!,
              ),
              const SizedBox(height: AppDimens.spacing16),
              _LinkField(
                platform: ShopLinkPlatform.tiktok,
                icon: Icons.music_note_outlined,
                label: 'TikTok',
                hint: 'profile name, e.g. zonixpos',
                controller: _controllers[ShopLinkPlatform.tiktok]!,
              ),
              const SizedBox(height: AppDimens.spacing8),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Let this shop edit their own links'),
                subtitle: const Text(
                  'Opens these four fields for editing in the mobile app. '
                  'Shop owners can never change this switch themselves.',
                ),
                value: _linksEnabled,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _linksEnabled = v),
              ),
              const SizedBox(height: AppDimens.spacing12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving || !_isDirty ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: AppDimens.iconLg,
                          height: AppDimens.iconLg,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: AppDimens.iconLg),
                  label: const Text('Save links'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One link input with the QR preview of the URL it currently resolves to
/// sitting beside it, plus that URL spelled out underneath — the value in
/// the field is a raw handle, so the preview is the only place the admin
/// sees where the printed code actually points.
class _LinkField extends StatelessWidget {
  const _LinkField({
    required this.platform,
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
  });

  final ShopLinkPlatform platform;
  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rawValue = controller.text.trim();
    final hasError = shopLinkError(rawValue) != null;
    final url = rawValue.isEmpty || hasError
        ? null
        : resolveShopLinkUrl(platform, rawValue);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  prefixIcon: Icon(icon),
                ),
                validator: shopLinkError,
              ),
              const SizedBox(height: AppDimens.spacing6),
              Text(
                url ?? 'No QR code on receipts',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppDimens.fontCaption,
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: url == null ? FontStyle.italic : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimens.spacing14),
        _QrPreview(url: url, label: label),
      ],
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.url, required this.label});

  final String? url;
  final String label;

  static const _size = 84.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = this.url;

    return Tooltip(
      message: url ?? 'Nothing to encode yet',
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          // Kept white whatever the surface is: a QR code only scans as
          // dark modules on a light background.
          color: url == null
              ? colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: url == null
            ? Icon(
                Icons.qr_code_2_outlined,
                size: AppDimens.icon2xl,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              )
            : QrImageView(
                data: url,
                size: _size,
                padding: const EdgeInsets.all(AppDimens.spacing6),
                backgroundColor: Colors.white,
                semanticsLabel: '$label QR code',
              ),
      ),
    );
  }
}
