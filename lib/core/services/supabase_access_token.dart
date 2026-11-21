import 'package:firebase_auth/firebase_auth.dart';

/// Supplies the signed-in admin's Firebase ID token to Supabase (Supabase
/// Third-Party Auth for Firebase, project zonix-93c4a), so queries run as
/// role `authenticated` and `public.is_platform_admin()` can check the uid.
///
/// Supabase rejects a Firebase token that lacks the custom claim
/// `role: "authenticated"`. Until an admin has that claim (see
/// tool/set_supabase_role_claim.js) this returns null, so requests keep
/// going out as anon — exactly as before — instead of every Supabase call,
/// product image uploads included, failing.
class SupabaseAccessToken {
  SupabaseAccessToken._();

  /// The uid whose token has already been force-refreshed once this session,
  /// so a claim set after sign-in is picked up without signing out.
  static String? _refreshedUid;

  static Future<String?> get() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      var result = await user.getIdTokenResult();
      if (!_hasRole(result) && _refreshedUid != user.uid) {
        _refreshedUid = user.uid;
        result = await user.getIdTokenResult(true);
      }
      return _hasRole(result) ? result.token : null;
    } catch (_) {
      return null;
    }
  }

  /// Call once right after sign-in: forces a fresh token so a newly set
  /// custom claim takes effect without a sign-out.
  static Future<void> refreshAfterSignIn(User user) async {
    _refreshedUid = user.uid;
    try {
      await user.getIdToken(true);
    } catch (_) {}
  }

  static bool _hasRole(IdTokenResult result) =>
      result.claims?['role'] == 'authenticated';
}
