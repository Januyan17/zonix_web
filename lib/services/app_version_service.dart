import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_version_config.dart';

class NotSignedInException implements Exception {
  const NotSignedInException();
}

/// Reads and writes `platform_config/appVersion`, the forced-update gate for
/// the mobile app. Security rules grant write only to isSuperAdmin() and
/// reject any write where minSupportedBuild > latestBuild, so a
/// permission-denied here means those rules are the first thing to check —
/// not a reason to restructure the document.
class AppVersionService {
  AppVersionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('platform_config').doc('appVersion');

  /// The currently saved config, or null when the document does not exist
  /// yet. Read from the server rather than the cache: a second admin needs
  /// to see what the first one actually published before touching the floor.
  Future<AppVersionConfig?> read() async {
    final snapshot = await _ref.get(
      const GetOptions(source: Source.server),
    );
    return AppVersionConfig.fromSnapshot(snapshot);
  }

  /// Writes with merge, which creates the document on the first save — it
  /// does not exist until an admin saves here for the first time.
  Future<void> save({
    required int minSupportedBuild,
    required int latestBuild,
    required String androidDownloadUrl,
    required String iosDownloadUrl,
    required String message,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const NotSignedInException();

    await _ref.set({
      'minSupportedBuild': minSupportedBuild,
      'latestBuild': latestBuild,
      'androidDownloadUrl': androidDownloadUrl,
      'iosDownloadUrl': iosDownloadUrl,
      'message': message,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }
}
