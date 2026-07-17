import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../theme/app_dimens.dart';
import '../utils/error_utils.dart';
import '../widgets/auth_shell.dart';
import 'login_screen.dart';
import 'shop_list_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.authService,
    required this.shopService,
  });

  final AuthService authService;
  final ShopService shopService;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    debugPrint('[SIGNUP-UI] submit tapped');
    if (!_formKey.currentState!.validate()) {
      debugPrint('[SIGNUP-UI] validation failed, aborting');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.authService.signUp(
        email: _emailController.text.trim(),

        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );

      debugPrint(
        '[SIGNUP-UI] signUp() succeeded, mounted=$mounted, navigating to dashboard',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ShopListScreen(
              authService: widget.authService,
              shopService: widget.shopService,
            ),
          ),
        );
      }
    } on AdminSignupRaceException {
      debugPrint(
        '[SIGNUP-UI] caught AdminSignupRaceException, mounted=$mounted',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              authService: widget.authService,
              shopService: widget.shopService,
              message:
                  'An admin account already exists — please log in instead.',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[SIGNUP-UI] caught FirebaseAuthException: ${e.code} ${e.message}, mounted=$mounted',
      );
      if (mounted) setState(() => _error = e.message ?? 'Sign up failed.');
    } catch (e) {
      debugPrint(
        '[SIGNUP-UI] caught generic error: ${describeError(e)}, mounted=$mounted',
      );
      if (mounted) {
        setState(() => _error = 'Sign up failed: ${describeError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      formKey: _formKey,
      title: 'Zonix Admin',
      subtitle: 'Create the first platform admin account',
      children: [
        TextFormField(
          controller: _displayNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Display name',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: AppDimens.spacing14),
        TextFormField(
          controller: _emailController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: AppDimens.spacing14),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          obscureText: _obscurePassword,
          onFieldSubmitted: (_) => _submit(),
          validator: (v) =>
              (v == null || v.length < 6) ? 'At least 6 characters' : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppDimens.spacing16),
          AuthErrorBanner(message: _error!),
        ],
        const SizedBox(height: AppDimens.spacing24),
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
              : const Text('Create admin account'),
        ),
      ],
    );
  }
}
