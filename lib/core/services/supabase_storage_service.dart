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

  /// Removes a deleted shop's product images: the ones referenced by its
  /// products ([imageUrls]) plus anything else left in its `slug/` folder.
  /// Returns how many files could not be removed (0 when all are gone).
  Future<int> deleteShopImages({
    required String slug,
    required List<String> imageUrls,
  }) async {
    final bucket = _client.storage.from(_bucket);
    final paths = <String>{
      for (final url in imageUrls) ?_pathFromPublicUrl(url),
    };

    // Also sweep the folder, for images whose product was already deleted.
    // Listing may be blocked by storage policies; the URLs above still work.
    try {
      const pageSize = 1000;
      for (var offset = 0; ; offset += pageSize) {
        final files = await bucket.list(
          path: slug,
          searchOptions: SearchOptions(limit: pageSize, offset: offset),
        );
        // Folder placeholders have no id; only real files are removed.
        paths.addAll([
          for (final f in files)
            if (f.id != null) '$slug/${f.name}',
        ]);
        if (files.length < pageSize) break;
      }
    } catch (_) {}

    var failed = 0;
    final all = paths.toList();
    for (var i = 0; i < all.length; i += 100) {
      final chunk = all.sublist(i, i + 100 > all.length ? all.length : i + 100);
      try {
        final removed = await bucket.remove(chunk);
        failed += chunk.length - removed.length;
      } catch (_) {
        failed += chunk.length;
      }
    }
    return failed;
  }

  /// `.../storage/v1/object/public/product-images/<path>` → `<path>`, or
  /// null for a URL that isn't in this bucket.
  static String? _pathFromPublicUrl(String url) {
    const marker = '/storage/v1/object/public/$_bucket/';
    final index = url.indexOf(marker);
    if (index < 0) return null;
    final path = Uri.decodeComponent(
      url.substring(index + marker.length).split('?').first,
    );
    return path.isEmpty ? null : path;
  }
}
