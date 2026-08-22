class StatsDateRange {
  const StatsDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  /// Whole days covered, counting both ends — a single-day range is 1.
  int get dayCount {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return endDay.difference(startDay).inDays + 1;
  }
}

class ShopStats {
  const ShopStats({
    required this.salesCount,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalExpenses,
    required this.totalAdditionalIncome,
    required this.productCount,
    this.unitsSold = 0,
  });

  final int salesCount;
  final double totalRevenue;

  /// Cost of goods sold: sum of unit_cost × quantity across every sold
  /// item. Revenue alone isn't profit — this is what those items actually
  /// cost to stock.
  final double totalCogs;
  final double totalExpenses;
  final double totalAdditionalIncome;
  final int productCount;

  /// Line-item quantity summed across every sale. Fractional because a
  /// quantity can be a weight rather than a count. Zero when the sale
  /// documents carry no items at all, which is why it never divides
  /// anything without a null guard.
  final double unitsSold;

  double get grossProfit => totalRevenue - totalCogs;

  double get netProfit =>
      totalRevenue - totalCogs - totalExpenses + totalAdditionalIncome;

  /// What an average basket is worth. Null with no sales — an average over
  /// nothing is not zero, and printing "Rs 0.00" would read as "customers
  /// spent nothing" rather than "nobody came".
  double? get averageOrderValue =>
      salesCount == 0 ? null : totalRevenue / salesCount;

  /// Items per basket. Null when nothing sold, or when the sale documents
  /// carry no line items to count.
  double? get averageBasketSize =>
      (salesCount == 0 || unitsSold == 0) ? null : unitsSold / salesCount;

  /// Gross margin as a fraction of revenue (0.4 = 40%). Null with no
  /// revenue to take a margin on.
  ///
  /// Can be negative — selling below cost is a thing shops do by accident,
  /// and the number should say so rather than clamp.
  double? get grossMargin =>
      totalRevenue == 0 ? null : grossProfit / totalRevenue;

  /// Net margin: what survives expenses and other income, per rupee of
  /// revenue.
  double? get netMargin => totalRevenue == 0 ? null : netProfit / totalRevenue;
}

class DailyStat {
  const DailyStat({
    required this.day,
    required this.revenue,
    required this.expenses,
  });

  final DateTime day;
  final double revenue;
  final double expenses;
}
