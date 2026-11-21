import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:zonixweb/features/auth/screens/login_screen.dart';
import 'package:zonixweb/features/auth/services/auth_service.dart';
import 'package:zonixweb/features/shops/services/shop_service.dart';

/// Sends the admin back to the login screen when Firebase ends their
/// session from outside the app: password changed in the console, account
/// disabled or deleted. Works the same on web and mobile.
///
/// - Listens to [FirebaseAuth.authStateChanges] (local to the SDK, no
///   network calls, no Firestore reads).
/// - On app start and whenever the app returns to the foreground, force-
///   refreshes the ID token (one Firebase Auth call, not Firestore). A
///   password change revokes the refresh token, so this fails right away
///   instead of up to an hour later when the current token expires.
class SessionWatcher extends StatefulWidget {
  const SessionWatcher({
    super.key,
    required this.navigatorKey,
    required this.authService,
    required this.shopService,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final AuthService authService;
  final ShopService shopService;
  final Widget child;

  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher>
    with WidgetsBindingObserver {
  /// Foreground checks closer together than this are skipped, since web
  /// fires focus changes often.
  static const _minCheckGap = Duration(seconds: 30);

  /// Errors meaning the session is gone for good. Network errors are not
  /// here: being offline must not log the admin out.
  static const _endedCodes = {
    'user-token-expired',
    'invalid-user-token',
    'user-disabled',
    'user-not-found',
  };

  StreamSubscription<User?>? _authSub;
  DateTime? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    _verifySession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifySession();
  }

  void _onAuthChanged(User? user) {
    final active = AuthService.activeAdminUid;
    if (active == null || user?.uid == active) return;
    _endSession();
  }

  Future<void> _verifySession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _checking) return;
    final now = DateTime.now();
    if (_lastCheck != null && now.difference(_lastCheck!) < _minCheckGap) {
      return;
    }
    _lastCheck = now;
    _checking = true;
    try {
      await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      if (_endedCodes.contains(e.code)) {
        // The SDK usually signs out by itself here; make sure, which also
        // fires authStateChanges -> _endSession.
        await FirebaseAuth.instance.signOut();
        if (AuthService.activeAdminUid != null) _endSession();
      }
    } catch (_) {
      // Offline or transient: keep the session, try again next time.
    } finally {
      _checking = false;
    }
  }

  void _endSession() {
    if (AuthService.activeAdminUid == null) return;
    AuthService.activeAdminUid = null;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authService: widget.authService,
          shopService: widget.shopService,
          message:
              'Your session has ended (password changed or account '
              'disabled). Please log in again.',
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
