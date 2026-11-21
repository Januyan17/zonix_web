import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether Supabase recognises the signed-in Firebase admin, via
/// `public.is_platform_admin()`. False when it returns false, and also when
/// the call fails (Third-Party Auth not set up, no role claim, migration not
/// run) — the page then shows the setup banner.
Future<bool> supabaseRecognisesAdmin({SupabaseClient? client}) async {
  if (FirebaseAuth.instance.currentUser == null) return false;
  try {
    final result = await (client ?? Supabase.instance.client).rpc(
      'is_platform_admin',
    );
    return result == true;
  } catch (_) {
    return false;
  }
}
