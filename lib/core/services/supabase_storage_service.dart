import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  SupabaseStorageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _bucket = 'product-images';

  /// Uploads a product image and returns its public URL. The path is keyed
  /// by product id (for organization) plus a timestamp, so replacing an
  /// image on edit always lands at a fresh URL instead of one a
  /// browser/CDN may have already cached under the old contents.
  Future<String> uploadProductImage({
    required String slug,
    required String productId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final path =
        '$slug/${productId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage.from(_bucket).uploadBinary(path, bytes);
    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
