import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zonixweb/features/contact_zonix/models/join_contact_config.dart';
import 'package:zonixweb/features/contact_zonix/services/live_feed.dart';

/// Reads and updates the single `public.join_contact_config` row (id = 1).
/// The row is created by the migration; the portal never inserts or
/// deletes it, and only sends the columns RLS lets admins update.
class JoinContactConfigService {
  JoinContactConfigService({SupabaseClient? client, FirebaseAuth? auth})
    : _client = client ?? Supabase.instance.client,
      _auth = auth ?? FirebaseAuth.instance;

  final SupabaseClient _client;
  final FirebaseAuth _auth;

  static const _table = 'join_contact_config';

  /// Live row; null while the row doesn't exist (migration not run).
  Stream<JoinContactConfig?> watch() => _client
      .from(_table)
      .stream(primaryKey: ['id'])
      .eq('id', 1)
      .map(
        (rows) => rows.isEmpty ? null : JoinContactConfig.fromMap(rows.first),
      );

  /// `.select().single()` turns a zero-row update (RLS refused a non-admin,
  /// without an error) into an error the page can show.
  Future<JoinContactConfig> save({
    required bool phoneEnabled,
    required String phone,
    required bool requestFormEnabled,
    required String? message,
  }) async {
    final trimmedMessage = message?.trim() ?? '';
    final row = await _client
        .from(_table)
        .update({
          'phone_enabled': phoneEnabled,
          'phone': phone.trim(),
          'request_form_enabled': requestFormEnabled,
          'message': trimmedMessage.isEmpty ? null : trimmedMessage,
          'updated_by': _auth.currentUser!.uid,
        })
        .eq('id', 1)
        .select()
        .single();
    return JoinContactConfig.fromMap(row);
  }
}

/// The shared live config, used by the settings page and the overview card.
final joinContactConfigFeed = LiveFeed<JoinContactConfig?>(
  () => JoinContactConfigService().watch(),
);
