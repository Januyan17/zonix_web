enum ShopTransactionType { sale, expense, income }

/// A single sale, expense, or additional-income entry
/// (shops/{slug}/{sales,expenses,additional_income}/{id}), normalized for
/// display in an itemized activity list.
///
/// The mobile app that writes these documents isn't part of this repo, so
/// beyond the fields the rest of this admin app already relies on (total /
/// amount, created_at, is_deleted, items), any label field is read
/// defensively across common aliases rather than assumed.
class ShopTransaction {
  const ShopTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.note,
    this.itemCount,
  });

  final String id;
  final ShopTransactionType type;
  final double amount;
  final DateTime? createdAt;
  final String? note;

  /// Number of line items on a sale; null for expenses/income.
  final int? itemCount;

  static String? _pickNote(Map<String, dynamic> map) {
    for (final key in ['note', 'description', 'reason', 'title', 'category']) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  factory ShopTransaction.fromMap(
    String id,
    ShopTransactionType type,
    Map<String, dynamic> map,
  ) {
    final amountKey = type == ShopTransactionType.sale ? 'total' : 'amount';
    final items = map['items'];
    return ShopTransaction(
      id: id,
      type: type,
      amount: (map[amountKey] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      note: _pickNote(map),
      itemCount: type == ShopTransactionType.sale && items is List ? items.length : null,
    );
  }
}
