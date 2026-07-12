class StatsDateRange {
  const StatsDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class ShopStats {
  const ShopStats({
    required this.salesCount,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalExpenses,
    required this.totalAdditionalIncome,
    required this.productCount,
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

  double get grossProfit => totalRevenue - totalCogs;

  double get netProfit => totalRevenue - totalCogs - totalExpenses + totalAdditionalIncome;
}

class DailyStat {
  const DailyStat({required this.day, required this.revenue, required this.expenses});

  final DateTime day;
  final double revenue;
  final double expenses;
}
