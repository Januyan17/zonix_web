import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/models/shop_activity.dart';
import 'package:zonixweb/models/shop_stats.dart';
import 'package:zonixweb/utils/shop_activity_aggregate.dart';

/// The analytics layered on top of the totals — per-product performance,
/// trading rhythm, voids, and the previous-period comparison. All of it is
/// derived from the same fetched documents, so the arithmetic is the only
/// thing that can be wrong.
void main() {
  var nextId = 0;
  ActivityDoc doc(Map<String, dynamic> data) =>
      ActivityDoc(id: 'doc${nextId++}', data: data);

  ActivityDoc sale(
    String date,
    double total, {
    bool deleted = false,
    List<Map<String, dynamic>>? items,
  }) => doc({
    'created_at': DateTime.parse(date).toIso8601String(),
    'total': total,
    'is_deleted': deleted,
    'items': ?items,
  });

  ActivityDoc product(String name, {bool deleted = false}) =>
      doc({'name': name, 'is_deleted': deleted});

  ShopActivity activity({
    List<ActivityDoc> sales = const [],
    List<ActivityDoc> expenses = const [],
    List<ActivityDoc> additionalIncome = const [],
    List<ActivityDoc> products = const [],
    DateTime? from,
    DateTime? to,
  }) => ShopActivity(
    sales: sales,
    expenses: expenses,
    additionalIncome: additionalIncome,
    products: products,
    from: from,
    to: to,
  );

  group('derived stat getters', () {
    test('average order value and margins divide by the right things', () {
      final stats = statsFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              100,
              items: [
                {'unit_cost': 20, 'quantity': 2},
              ],
            ),
            sale(
              '2026-08-01',
              300,
              items: [
                {'unit_cost': 10, 'quantity': 6},
              ],
            ),
          ],
          expenses: [
            doc({
              'created_at': DateTime(2026, 8, 1).toIso8601String(),
              'amount': 50,
            }),
          ],
        ),
      );

      expect(stats.totalRevenue, 400);
      expect(stats.totalCogs, 100);
      expect(stats.unitsSold, 8);
      expect(stats.averageOrderValue, 200);
      expect(stats.averageBasketSize, 4);
      expect(stats.grossMargin, closeTo(0.75, 1e-9));
      // 400 - 100 cogs - 50 expenses = 250.
      expect(stats.netMargin, closeTo(0.625, 1e-9));
    });

    test('averages over nothing are null rather than zero', () {
      final stats = statsFrom(activity());
      expect(stats.averageOrderValue, isNull);
      expect(stats.averageBasketSize, isNull);
      expect(stats.grossMargin, isNull);
      expect(stats.netMargin, isNull);
    });

    test('an item with no quantity still counts as one unit', () {
      final stats = statsFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              30,
              items: [
                {'unit_cost': 4},
              ],
            ),
          ],
        ),
      );
      expect(stats.unitsSold, 1);
      expect(stats.totalCogs, 4);
    });

    test('selling below cost reports a negative margin, not a floor', () {
      final stats = statsFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              50,
              items: [
                {'unit_cost': 80, 'quantity': 1},
              ],
            ),
          ],
        ),
      );
      expect(stats.grossMargin, closeTo(-0.6, 1e-9));
    });
  });

  group('productPerformanceFrom', () {
    test('groups line items by product and ranks by revenue', () {
      final result = productPerformanceFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              130,
              items: [
                {
                  'product_id': 'p1',
                  'name': 'Tea',
                  'quantity': 2,
                  'unit_price': 15,
                  'unit_cost': 5,
                },
                {
                  'product_id': 'p2',
                  'name': 'Cake',
                  'quantity': 1,
                  'unit_price': 100,
                  'unit_cost': 40,
                },
              ],
            ),
            sale(
              '2026-08-02',
              45,
              items: [
                {
                  'product_id': 'p1',
                  'name': 'Tea',
                  'quantity': 3,
                  'unit_price': 15,
                  'unit_cost': 5,
                },
              ],
            ),
          ],
        ),
      );

      expect(result.map((p) => p.name), ['Cake', 'Tea']);

      final tea = result.firstWhere((p) => p.name == 'Tea');
      expect(tea.unitsSold, 5);
      expect(tea.revenue, 75);
      expect(tea.cogs, 25);
      expect(tea.grossProfit, 50);
      expect(tea.saleCount, 2);
      expect(tea.margin, closeTo(2 / 3, 1e-9));
    });

    test('an explicit line total wins over price x quantity', () {
      final result = productPerformanceFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              90,
              items: [
                // Discounted: 2 x 50 would be 100, but the app already
                // worked out what was charged.
                {'name': 'Tea', 'quantity': 2, 'unit_price': 50, 'total': 90},
              ],
            ),
          ],
        ),
      );
      expect(result.single.revenue, 90);
    });

    test('items carrying only a name still group together', () {
      final result = productPerformanceFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              20,
              items: [
                {'name': 'Tea', 'quantity': 1, 'unit_price': 10},
              ],
            ),
            sale(
              '2026-08-01',
              20,
              items: [
                {'name': 'tea', 'quantity': 1, 'unit_price': 10},
              ],
            ),
          ],
        ),
      );
      expect(result, hasLength(1));
      expect(result.single.unitsSold, 2);
      expect(result.single.saleCount, 2);
    });

    test('two lines of one product in one basket are one sale', () {
      final result = productPerformanceFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              20,
              items: [
                {'product_id': 'p1', 'name': 'Tea', 'quantity': 1},
                {'product_id': 'p1', 'name': 'Tea', 'quantity': 1},
              ],
            ),
          ],
        ),
      );
      expect(result.single.saleCount, 1);
      expect(result.single.unitsSold, 2);
    });

    test('deleted sales and out-of-range sales contribute nothing', () {
      final subject = activity(
        sales: [
          sale(
            '2026-08-01',
            20,
            deleted: true,
            items: [
              {'name': 'Tea', 'quantity': 1, 'unit_price': 20},
            ],
          ),
          sale(
            '2026-07-01',
            20,
            items: [
              {'name': 'Cake', 'quantity': 1, 'unit_price': 20},
            ],
          ),
        ],
      );
      final august = StatsDateRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 31),
      );
      expect(productPerformanceFrom(subject, range: august), isEmpty);
    });
  });

  group('deadStockFrom', () {
    test('lists catalog products with no sales in the range', () {
      final result = deadStockFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              20,
              items: [
                {'name': 'Tea', 'quantity': 1, 'unit_price': 20},
              ],
            ),
          ],
          products: [
            product('Tea'),
            product('Cake'),
            product('Scone', deleted: true),
          ],
        ),
      );
      // Tea sold; Scone is deleted from the catalog and so isn't stock at
      // all. Only Cake is sitting there.
      expect(result.map((p) => p.name), ['Cake']);
    });
  });

  group('hourlySalesFrom / weekdaySalesFrom', () {
    test('buckets by clock hour with every slot present', () {
      final hours = hourlySalesFrom(
        activity(
          sales: [
            sale('2026-08-01T09:15:00', 10),
            sale('2026-08-01T09:45:00', 20),
            sale('2026-08-01T17:05:00', 5),
            sale('2026-08-01T09:00:00', 100, deleted: true),
          ],
        ),
      );

      expect(hours, hasLength(24));
      expect(hours[9].salesCount, 2);
      expect(hours[9].revenue, 30);
      expect(hours[17].salesCount, 1);
      expect(hours[0].salesCount, 0);
    });

    test('buckets by weekday, Monday first', () {
      // 2026-08-01 is a Saturday; 2026-08-03 a Monday.
      final days = weekdaySalesFrom(
        activity(
          sales: [sale('2026-08-01T10:00:00', 10), sale('2026-08-03T10:00:00', 40)],
        ),
      );

      expect(days, hasLength(7));
      expect(days.first.weekday, DateTime.monday);
      expect(days[DateTime.monday - 1].revenue, 40);
      expect(days[DateTime.saturday - 1].revenue, 10);
      expect(days[DateTime.sunday - 1].salesCount, 0);
    });
  });

  group('voidedSalesFrom', () {
    test('counts deleted sales against those that stood', () {
      final voids = voidedSalesFrom(
        activity(
          sales: [
            sale('2026-08-01', 100),
            sale('2026-08-01', 60, deleted: true),
            sale('2026-08-01', 40, deleted: true),
          ],
        ),
      );

      expect(voids.count, 2);
      expect(voids.value, 100);
      expect(voids.keptCount, 1);
      expect(voids.rate, closeTo(2 / 3, 1e-9));
    });

    test('no sales at all leaves the rate undefined', () {
      expect(voidedSalesFrom(activity()).rate, isNull);
    });
  });

  group('precedingRange', () {
    test('is the same length, ending the day before', () {
      final previous = precedingRange(
        StatsDateRange(start: DateTime(2026, 8, 10), end: DateTime(2026, 8, 16)),
      );
      expect(previous!.start, DateTime(2026, 8, 3));
      expect(previous.end, DateTime(2026, 8, 9));
      expect(previous.dayCount, 7);
    });

    test('rolls back over a month boundary', () {
      final previous = precedingRange(
        StatsDateRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 1)),
      );
      expect(previous!.start, DateTime(2026, 7, 31));
      expect(previous.end, DateTime(2026, 7, 31));
    });

    test('all time has nothing before it', () {
      expect(precedingRange(null), isNull);
    });
  });

  group('comparisonFrom', () {
    final thisWeek = StatsDateRange(
      start: DateTime(2026, 8, 10),
      end: DateTime(2026, 8, 16),
    );

    test('sets the range against the one before it', () {
      final comparison = comparisonFrom(
        activity(
          sales: [sale('2026-08-11', 150), sale('2026-08-04', 100)],
          from: DateTime(2026, 8, 3),
          to: DateTime(2026, 8, 16),
        ),
        range: thisWeek,
      );

      expect(comparison!.current.totalRevenue, 150);
      expect(comparison.previous.totalRevenue, 100);
      expect(comparison.revenueChange, closeTo(0.5, 1e-9));
    });

    test('growth from a period with nothing in it is undefined', () {
      final comparison = comparisonFrom(
        activity(
          sales: [sale('2026-08-11', 150)],
          from: DateTime(2026, 8, 3),
          to: DateTime(2026, 8, 16),
        ),
        range: thisWeek,
      );
      expect(comparison!.revenueChange, isNull);
    });

    test('an unfetched previous period yields no comparison at all', () {
      // Without this guard the previous period reads as empty simply
      // because it was never downloaded, and every tile claims growth.
      final comparison = comparisonFrom(
        activity(
          sales: [sale('2026-08-11', 150)],
          from: DateTime(2026, 8, 10),
          to: DateTime(2026, 8, 16),
        ),
        range: thisWeek,
      );
      expect(comparison, isNull);
    });

    test('all time has no comparison', () {
      expect(comparisonFrom(activity(), range: null), isNull);
    });
  });
}
