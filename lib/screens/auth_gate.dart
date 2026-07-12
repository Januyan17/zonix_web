import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/shop_service.dart';
import 'login_screen.dart';
import 'shop_list_screen.dart';
import 'signup_screen.dart';

/// Checks once on startup whether an admin is already signed in, then shows
/// Signup, Login, or the dashboard. After that, each screen navigates
/// forward directly once its own action succeeds — no reactive listening,
/// so there's nothing to race against an in-flight write.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.shopService,
  });

  final AuthService authService;
  final ShopService shopService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final claimed = await widget.authService.checkBootstrapClaimed();
    final user = widget.authService.currentUser;
    if (user != null && !await widget.authService.isUidAdmin(user.uid)) {
      await widget.authService.signOut();
    }
    if (mounted) {
      setState(() {
        _claimed = claimed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.authService.currentUser != null) {
      return ShopListScreen(authService: widget.authService, shopService: widget.shopService);
    }
    if (!_claimed) {
      return SignupScreen(authService: widget.authService, shopService: widget.shopService);
    }
    return LoginScreen(authService: widget.authService, shopService: widget.shopService);
  }
}
