import 'package:cloud_firestore/cloud_firestore.dart';
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
  // Keep a local (IndexedDB on web) cache of everything read. Mobile and
  // desktop SDKs do this by default; web doesn't, which made every page
  // refresh re-download every document. With the cache, a listener that
  // resumes within 30 minutes is billed only for documents that changed.
  // Must be set before the first Firestore call. Multi-tab so several
  // portal tabs can share the cache instead of failing over to memory.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
  await Supabase.initialize(
    url: SupabaseOptions.url,
    publishableKey: SupabaseOptions.anonKey,
  );
  runApp(const ZonixAdminApp());
}
