import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zonixweb/features/contact_zonix/models/contact_request.dart';
import 'package:zonixweb/features/contact_zonix/services/live_feed.dart';

/// `public.contact_requests`: join requests sent from the mobile app.
/// Admins may only read, delete, and update status / admin_note /
/// handled_at / handled_by — nothing else is ever sent in an update.
class ContactRequestService {
  ContactRequestService({SupabaseClient? client, FirebaseAuth? auth})
    : _client = client ?? Supabase.instance.client,
      _auth = auth ?? FirebaseAuth.instance;

  final SupabaseClient _client;
  final FirebaseAuth _auth;

  static const _table = 'contact_requests';

  /// Every request, newest first, live (the table is in the realtime
  /// publication).
  Stream<List<ContactRequest>> watchAll() => _client
      .from(_table)
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((rows) => rows.map(ContactRequest.fromMap).toList());

  /// Sets the status; handled_at is now when it leaves 'new' and cleared
  /// when set back to 'new'. [note] also replaces admin_note when given.
  Future<ContactRequest> updateStatus(
    String id,
    ContactRequestStatus status, {
    String? note,
  }) async {
    final isNew = status == ContactRequestStatus.newRequest;
    return _update(id, {
      'status': status.value,
      'handled_at': isNew ? null : DateTime.now().toUtc().toIso8601String(),
      'handled_by': _auth.currentUser!.uid,
      if (note != null) 'admin_note': _noteOrNull(note),
    });
  }

  /// Changes only the admin note, leaving status and handled_at alone.
  Future<ContactRequest> updateNote(String id, String note) =>
      _update(id, {'admin_note': _noteOrNull(note)});

  Future<void> delete(String id) async {
    final rows = await _client.from(_table).delete().eq('id', id).select();
    if (rows.isEmpty) {
      throw StateError(
        'Nothing was deleted. Supabase may not recognise this admin.',
      );
    }
  }

  static String? _noteOrNull(String note) {
    final t = note.trim();
    return t.isEmpty ? null : t;
  }

  /// `.select().single()` makes a zero-row update (RLS) an error.
  Future<ContactRequest> _update(String id, Map<String, dynamic> values) async {
    final row = await _client
        .from(_table)
        .update(values)
        .eq('id', id)
        .select()
        .single();
    return ContactRequest.fromMap(row);
  }
}

/// The shared live list of requests: the inbox, the nav badge and the
/// overview card all read it.
final contactRequestsFeed = LiveFeed<List<ContactRequest>>(
  () => ContactRequestService().watchAll(),
);

/// Requests still in 'new', for badges. Zero until loaded.
int newContactRequestCount() =>
    contactRequestsFeed.value
        ?.where((r) => r.status == ContactRequestStatus.newRequest)
        .length ??
    0;
