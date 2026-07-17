import 'package:flutter/material.dart';

import '../services/shop_service.dart';
import '../theme/app_dimens.dart';
import '../utils/error_utils.dart';
import '../utils/slug.dart';
import '../widgets/credential_row.dart';

class CreateShopScreen extends StatefulWidget {
  const CreateShopScreen({super.key, required this.shopService});

  final ShopService shopService;

  @override
  State<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends State<CreateShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _slugController = TextEditingController();
  final _ownerDisplayNameController = TextEditingController();
  final _ownerUsernameController = TextEditingController();
  final _ownerPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _error;
  ShopCreationResult? _result;

  @override
  void dispose() {
    _shopNameController.dispose();
    _slugController.dispose();
    _ownerDisplayNameController.dispose();
    _ownerUsernameController.dispose();
    _ownerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await widget.shopService.createShop(
        slug: _slugController.text.trim(),
        shopName: _shopNameController.text.trim(),
        ownerDisplayName: _ownerDisplayNameController.text.trim(),
        ownerUsername: _ownerUsernameController.text.trim(),
        ownerPassword: _ownerPasswordController.text,
      );
      if (mounted) setState(() => _result = result);
    } on ShopCodeTakenException {
      if (mounted) setState(() => _error = 'That shop code is already taken.');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to create shop: ${describeError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _SuccessView(result: _result!);
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create shop')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.spacing24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spacing20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionHeader(
                            icon: Icons.storefront_outlined,
                            label: 'Shop details',
                          ),
                          const SizedBox(height: AppDimens.spacing16),
                          TextFormField(
                            controller: _shopNameController,
                            decoration: const InputDecoration(
                              labelText: 'Shop name',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: AppDimens.spacing14),
                          TextFormField(
                            controller: _slugController,
                            decoration: const InputDecoration(
                              labelText: 'Shop code',
                              prefixIcon: Icon(Icons.tag_outlined),
                              helperText:
                                  'Lowercase letters, numbers, hyphens only. Becomes the shop ID.',
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Required';
                              if (!isValidSlug(value)) {
                                return 'Only lowercase letters, numbers, and hyphens';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.spacing16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spacing20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionHeader(
                            icon: Icons.person_outline,
                            label: 'Owner account',
                          ),
                          const SizedBox(height: AppDimens.spacing16),
                          TextFormField(
                            controller: _ownerDisplayNameController,
                            decoration: const InputDecoration(
                              labelText: 'Owner display name',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: AppDimens.spacing14),
                          TextFormField(
                            controller: _ownerUsernameController,
                            decoration: const InputDecoration(
                              labelText: 'Owner username',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                          const SizedBox(height: AppDimens.spacing14),
                          TextFormField(
                            controller: _ownerPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Owner initial password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            validator: (v) => (v == null || v.length < 6)
                                ? 'At least 6 characters'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppDimens.spacing16),
                    Container(
                      padding: const EdgeInsets.all(AppDimens.spacing12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(
                          AppDimens.radiusMedium,
                        ),
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
                              _error!,
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppDimens.spacing20),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create shop'),
                  ),
                ],
              ),
            ),
          ),
        ),
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

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.result});

  final ShopCreationResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Shop created')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spacing24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.check_rounded,
                            color: colorScheme.onTertiaryContainer,
                            size: AppDimens.icon2xl,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacing16),
                      Text(
                        'Shop "${result.slug}" created',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimens.spacing8),
                      Text(
                        'Relay these credentials to the shop owner so they can log '
                        'into the mobile app:',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimens.spacing20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusLarge,
                          ),
                        ),
                        child: Column(
                          children: [
                            CredentialRow(
                              label: 'Shop code',
                              value: result.slug,
                            ),
                            const Divider(height: 1),
                            CredentialRow(
                              label: 'Username',
                              value: result.ownerUsername,
                            ),
                            const Divider(height: 1),
                            CredentialRow(
                              label: 'Password',
                              value: result.ownerPassword,
                              isSensitive: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimens.spacing24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to shop list'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
