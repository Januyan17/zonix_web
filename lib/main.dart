import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zonixweb/app/zonix_admin_app.dart';
import 'package:zonixweb/core/config/supabase_options.dart';
import 'package:zonixweb/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: SupabaseOptions.url,
    publishableKey: SupabaseOptions.anonKey,
  );
  runApp(const ZonixAdminApp());
}
