import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminSignupRaceException implements Exception {
  const AdminSignupRaceException();
}

class NotAnAdminException implements Exception {
  const NotAnAdminException();
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> get _bootstrapRef =>
      _firestore.collection('platform_config').doc('adminBootstrap');

  /// Reads platform_config/adminBootstrap, lazily creating it as
  /// {claimed: false} if it doesn't exist yet. Returns whether an admin
  /// account has already been claimed.
  Future<bool> checkBootstrapClaimed() async {
    final snapshot = await _bootstrapRef.get();
    if (!snapshot.exists) {
      await _bootstrapRef.set({'claimed': false});
      return false;
    }
    return snapshot.data()?['claimed'] as bool? ?? false;
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    debugPrint('[SIGNUP] starting createUserWithEmailAndPassword for $email');
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    debugPrint('[SIGNUP] auth user created, uid=${user.uid}');
    if (displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
      debugPrint('[SIGNUP] displayName set');
    }

    try {
      final bootstrapSnapshot = await _bootstrapRef.get();
      debugPrint(
        '[SIGNUP] read bootstrap: exists=${bootstrapSnapshot.exists} '
        'data=${bootstrapSnapshot.data()}',
      );
      if (!bootstrapSnapshot.exists) {
        // The platform_admins create rule reads this doc's `claimed` field,
        // which throws (denying the write) if the doc doesn't exist at all.
        // Recreate it defensively rather than assuming it's always present.
        await _bootstrapRef.set({'claimed': false});
        debugPrint(
          '[SIGNUP] bootstrap doc was missing, recreated as claimed=false',
        );
      }
      final claimed = bootstrapSnapshot.data()?['claimed'] as bool? ?? false;
      if (claimed) {
        throw const AdminSignupRaceException();
      }
      await _firestore.collection('platform_admins').doc(user.uid).set({});
      debugPrint('[SIGNUP] platform_admins doc written');
      await _bootstrapRef.update({'claimed': true});
      debugPrint('[SIGNUP] bootstrap claimed=true written');
    } catch (e, st) {
      debugPrint('[SIGNUP] signup write FAILED: $e');
      debugPrint('[SIGNUP] stack: $st');
      try {
        await user.delete();
        debugPrint('[SIGNUP] rolled back: auth user deleted');
      } catch (deleteError) {
        debugPrint('[SIGNUP] rollback delete FAILED: $deleteError');
      }
      await _auth.signOut();
      rethrow;
    }
    debugPrint('[SIGNUP] signUp() completed successfully');
  }

  Future<void> logIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    final adminDoc = await _firestore
        .collection('platform_admins')
        .doc(user.uid)
        .get();
    if (!adminDoc.exists) {
      await _auth.signOut();
      throw const NotAnAdminException();
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<bool> isUidAdmin(String uid) async {
    final doc = await _firestore.collection('platform_admins').doc(uid).get();
    return doc.exists;
  }
}
