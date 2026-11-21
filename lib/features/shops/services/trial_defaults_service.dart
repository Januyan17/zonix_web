import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:zonixweb/features/shops/models/trial_defaults.dart';

/// Reads and writes `platform_config/trialDefaults`: the lock message and
/// payment contact used for every shop whose own trial fields are blank.
/// The mobile app reads this document (unauthenticated `get`) when it builds
/// the trial-ended popup.
class TrialDefaultsService {
  TrialDefaultsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('platform_config').doc('trialDefaults');

  /// Live value; a missing document reads as [TrialDefaults.empty].
  Stream<TrialDefaults> watch() =>
      _ref.snapshots().map(TrialDefaults.fromSnapshot);

  /// Blank values are stored as empty strings so the app falls back to its
  /// default copy. Merge creates the document on the first save.
  Future<void> save({String? message, String? contact}) async {
    await _ref.set({
      'message': message?.trim() ?? '',
      'contact': contact?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));
  }
}
