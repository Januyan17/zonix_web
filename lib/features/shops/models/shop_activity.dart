/// One stored document — its id plus the raw map as written by the mobile
/// app. Kept unparsed because the same document backs several different
/// views (stat tiles, trend chart, transaction list, product grid), each
/// reading a different subset of its fields.
class ActivityDoc {
  const ActivityDoc({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

/// One shop's transaction collections, fetched once and then re-filtered
/// locally for every date range the admin picks.
///
/// Every figure on the shop detail page — totals, daily trend, itemized
/// transactions, product count — is derived from these same documents, so
/// switching between Day/Week/Month/All-time costs no further reads. The
/// alternative (a fetch per filter click) re-downloaded every sale the
/// shop had ever made just to throw all but one day of them away.
class ShopActivity {
  const ShopActivity({
    required this.sales,
    required this.expenses,
    required this.additionalIncome,
    required this.products,
    this.from,
    this.to,
  });

  final List<ActivityDoc> sales;
  final List<ActivityDoc> expenses;
  final List<ActivityDoc> additionalIncome;

  /// Empty when fetched for a view that doesn't need the catalog (the
  /// transactions sheet); the product count is the only figure that reads
  /// it.
  final List<ActivityDoc> products;

  /// The day range these documents were fetched for, inclusive of both
  /// ends. A null end means unbounded on that side — an all-time fetch has
  /// both null and therefore covers every question that can be asked.
  final DateTime? from;
  final DateTime? to;

  /// Whether every document in [from, to] is already in hand, so the
  /// caller can re-filter locally instead of going back to the network.
  /// A narrower question than what was fetched is always answerable; a
  /// wider one never is.
  bool covers({DateTime? from, DateTime? to}) {
    final fetchedFrom = this.from;
    final fetchedTo = this.to;
    if (fetchedFrom != null && (from == null || from.isBefore(fetchedFrom))) {
      return false;
    }
    if (fetchedTo != null && (to == null || to.isAfter(fetchedTo))) {
      return false;
    }
    return true;
  }

  /// The same activity with a freshly-read product catalog, for after the
  /// admin adds/edits/deletes a product — the transaction documents are
  /// untouched by those edits, so they don't need re-reading.
  ShopActivity withProducts(List<ActivityDoc> products) {
    return ShopActivity(
      sales: sales,
      expenses: expenses,
      additionalIncome: additionalIncome,
      products: products,
      from: from,
      to: to,
    );
  }
}
