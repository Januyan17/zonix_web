import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/utils/error_utils.dart';
import 'package:zonixweb/core/widgets/section_header.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';
import 'package:zonixweb/features/shops/utils/slug.dart';
import 'package:zonixweb/features/shops/widgets/shop_created_view.dart';

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
      return ShopCreatedView(result: _result!);
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
                          SectionHeader(
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
                          SectionHeader(
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
