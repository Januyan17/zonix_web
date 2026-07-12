import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase project connection details, used for image storage. Loaded from
/// the .env file (see .env.example) — call dotenv.load() before reading
/// these.
///
/// The anon key is safe to ship in client code by design — same as the
/// Firebase web config in firebase_options.dart — access is governed by the
/// bucket's row-level security policies on the Supabase side, not by
/// keeping this key secret. It's kept in .env rather than committed as a
/// literal so it can be swapped per environment without touching code.
class SupabaseOptions {
  static String get url => _require('SUPABASE_URL');
  static String get anonKey => _require('SUPABASE_ANON_KEY');

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing $key in .env — copy .env.example to .env and fill it in.');
    }
    return value;
  }
}
