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
  ///
  /// Also copies the values onto every shop's `trial_message` /
  /// `trial_contact`, which is what already-installed app builds read, so
  /// the popup shows them on every phone regardless of app version.
  /// Returns how many shops could not be updated.
  Future<int> save({String? message, String? contact}) async {
    await _ref.set({
      'message': message?.trim() ?? '',
      'contact': contact?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    }, SetOptions(merge: true));
    return _copyToAllShops(message: message, contact: contact);
  }

  /// The per-shop fields for [message] / [contact]; blank removes the field
  /// so the app shows its default text.
  static Map<String, Object> shopFields({String? message, String? contact}) {
    Object valueOrDelete(String? v) {
      final trimmed = v?.trim() ?? '';
      return trimmed.isEmpty ? FieldValue.delete() : trimmed;
    }

    return {
      'trial_message': valueOrDelete(message),
      'trial_contact': valueOrDelete(contact),
    };
  }

  /// Reads the current common values as per-shop fields, for writing onto a
  /// shop when its trial starts.
  Future<Map<String, Object>> currentShopFields() async {
    final defaults = TrialDefaults.fromSnapshot(await _ref.get());
    return shopFields(message: defaults.message, contact: defaults.contact);
  }

  /// Uses `update` (never set/merge) so an index entry for a deleted shop
  /// can't recreate its document; those simply count as failed.
  Future<int> _copyToAllShops({String? message, String? contact}) async {
    final index = await _firestore.collection('admin_shop_index').get();
    final fields = shopFields(message: message, contact: contact);
    var failed = 0;
    await Future.wait([
      for (final entry in index.docs)
        _firestore
            .collection('shops')
            .doc(entry.id)
            .update(fields)
            .catchError((Object _) => failed++),
    ]);
    return failed;
  }
}
