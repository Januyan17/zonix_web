import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:zonixweb/features/join_contact/models/join_contact_config.dart';

/// Reads and writes `platform_config/joinContact`. Security rules allow
/// writes only from platform admins and only with the keys enabled, phone,
/// message and updatedAt, so [save] overwrites the whole document (no merge)
/// to leave no stray keys behind.
class JoinContactService {
  JoinContactService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _firestore.collection('platform_config').doc('joinContact');

  /// The saved settings, or [JoinContactConfig.empty] when the document
  /// doesn't exist yet. Read from the server so a second admin sees what was
  /// actually published.
  Future<JoinContactConfig> read() async {
    final snapshot = await _ref.get(const GetOptions(source: Source.server));
    return JoinContactConfig.fromSnapshot(snapshot);
  }

  Future<void> save({
    required bool enabled,
    required String phone,
    required String message,
  }) async {
    await _ref.set({
      'enabled': enabled,
      'phone': phone.trim(),
      'message': message.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
