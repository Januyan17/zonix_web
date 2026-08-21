import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/models/shop_activity.dart';
import 'package:zonixweb/models/shop_stats.dart';
import 'package:zonixweb/models/shop_transaction.dart';
import 'package:zonixweb/utils/shop_activity_aggregate.dart';

/// These pin down the arithmetic the shop detail page used to get from a
/// fetch-per-date-filter round trip: one fetch now backs every range, so
/// the filtering itself has to be right.
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

  ActivityDoc entry(String date, double amount, {bool deleted = false}) => doc({
    'created_at': DateTime.parse(date).toIso8601String(),
    'amount': amount,
    'is_deleted': deleted,
  });

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

  group('statsFrom', () {
    final august = StatsDateRange(
      start: DateTime(2026, 8, 1),
      end: DateTime(2026, 8, 3),
    );

    test('a null range totals everything, all time', () {
      final stats = statsFrom(
        activity(
          sales: [sale('2020-01-01', 100), sale('2026-08-02', 25)],
          expenses: [entry('2019-05-05', 5)],
          additionalIncome: [entry('2026-08-02', 7)],
        ),
      );

      expect(stats.totalRevenue, 125);
      expect(stats.salesCount, 2);
      expect(stats.totalExpenses, 5);
      expect(stats.totalAdditionalIncome, 7);
    });

    test('a range includes both end days and excludes either side', () {
      final stats = statsFrom(
        activity(
          sales: [
            sale('2026-07-31', 999),
            sale('2026-08-01', 10),
            sale('2026-08-03', 5),
            sale('2026-08-04', 999),
          ],
        ),
        range: august,
      );

      expect(stats.totalRevenue, 15);
      expect(stats.salesCount, 2);
    });

    test('a same-day range keeps that whole day, not just midnight', () {
      final stats = statsFrom(
        activity(sales: [sale('2026-08-02T23:59:00', 40)]),
        range: StatsDateRange(
          start: DateTime(2026, 8, 2),
          end: DateTime(2026, 8, 2),
        ),
      );

      expect(stats.totalRevenue, 40);
    });

    test('skips soft-deleted documents', () {
      final stats = statsFrom(
        activity(
          sales: [
            sale('2026-08-01', 100, deleted: true),
            sale('2026-08-01', 20),
          ],
          expenses: [entry('2026-08-01', 30, deleted: true)],
        ),
        range: august,
      );

      expect(stats.totalRevenue, 20);
      expect(stats.salesCount, 1);
      expect(stats.totalExpenses, 0);
    });

    test('COGS sums unit_cost x quantity across a sale items', () {
      final stats = statsFrom(
        activity(
          sales: [
            sale(
              '2026-08-01',
              100,
              items: [
                {'unit_cost': 10, 'quantity': 3},
                {'unit_cost': 5.5, 'quantity': 2},
              ],
            ),
          ],
        ),
        range: august,
      );

      expect(stats.totalCogs, 41);
      expect(stats.grossProfit, 59);
    });

    test('product count is all-time, whatever the range', () {
      final products = [
        doc({'name': 'a'}),
        doc({'name': 'b', 'is_deleted': true}),
        doc({'name': 'c'}),
      ];

      expect(statsFrom(activity(products: products)).productCount, 2);
      expect(
        statsFrom(activity(products: products), range: august).productCount,
        2,
      );
    });

    test('a document with no parsable date falls outside a bounded range', () {
      final undated = activity(
        sales: [
          doc({'total': 50, 'is_deleted': false}),
        ],
      );

      expect(statsFrom(undated).totalRevenue, 50);
      expect(statsFrom(undated, range: august).totalRevenue, 0);
    });
  });

  group('dailySeriesFrom', () {
    test('emits one zero-filled point per calendar day', () {
      final series = dailySeriesFrom(
        activity(
          sales: [sale('2026-08-01', 100), sale('2026-08-03', 50)],
          expenses: [entry('2026-08-03', 20)],
        ),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 3),
      );

      expect(series.length, 3);
      expect(series.map((d) => d.revenue).toList(), [100, 0, 50]);
      expect(series.map((d) => d.expenses).toList(), [0, 0, 20]);
    });

    test('ignores activity outside the window and soft-deleted docs', () {
      final series = dailySeriesFrom(
        activity(
          sales: [
            sale('2026-07-31', 999),
            sale('2026-08-01', 10, deleted: true),
            sale('2026-08-02', 7),
          ],
        ),
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 2),
      );

      expect(series.map((d) => d.revenue).toList(), [0, 7]);
    });
  });

  group('transactionsFrom', () {
    test('merges all three collections, newest first', () {
      final transactions = transactionsFrom(
        activity(
          sales: [sale('2026-08-01', 10)],
          expenses: [entry('2026-08-03', 20)],
          additionalIncome: [entry('2026-08-02', 30)],
        ),
      );

      expect(transactions.map((t) => t.amount).toList(), [20, 30, 10]);
      expect(transactions.map((t) => t.type).toList(), [
        ShopTransactionType.expense,
        ShopTransactionType.income,
        ShopTransactionType.sale,
      ]);
    });

    test('applies the same range and soft-delete rules as the totals', () {
      final subject = activity(
        sales: [
          sale('2026-07-31', 999),
          sale('2026-08-02', 10, deleted: true),
          sale('2026-08-02', 5),
        ],
      );
      final range = StatsDateRange(
        start: DateTime(2026, 8, 1),
        end: DateTime(2026, 8, 3),
      );

      expect(transactionsFrom(subject, range: range).length, 1);
      expect(
        transactionsFrom(subject, range: range).single.amount,
        statsFrom(subject, range: range).totalRevenue,
      );
    });
  });

  group('productsFrom', () {
    test('drops deleted products and sorts by name, ignoring case', () {
      final products = productsFrom([
        doc({'name': 'banana'}),
        doc({'name': 'Apple'}),
        doc({'name': 'cherry', 'is_deleted': true}),
      ]);

      expect(products.map((p) => p.name).toList(), ['Apple', 'banana']);
    });
  });

  group('activityQueryBounds', () {
    test('unbounded on a side stays unbounded', () {
      final bounds = activityQueryBounds(from: null, to: null);
      expect(bounds.startAt, isNull);
      expect(bounds.endBefore, isNull);
    });

    test('pads a day of slack on each end, zero-padded', () {
      final bounds = activityQueryBounds(
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 10),
      );
      expect(bounds.startAt, '2026-08-09');
      expect(bounds.endBefore, '2026-08-12');
    });

    test('rolls over month and year boundaries', () {
      expect(
        activityQueryBounds(from: DateTime(2026, 3, 1), to: null).startAt,
        '2026-02-28',
      );
      expect(
        activityQueryBounds(from: null, to: DateTime(2026, 12, 31)).endBefore,
        '2027-01-02',
      );
    });

    /// The whole point of the coarse bound: whichever way the mobile app
    /// serializes its dates, a document inside the range must sort inside
    /// the bounds, because Firestore compares these as plain strings.
    test('keeps in-range documents inside the bounds, UTC or offset', () {
      final bounds = activityQueryBounds(
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 12),
      );

      for (final createdAt in [
        '2026-08-10T00:00:00.000Z',
        '2026-08-10T00:00:00.000000Z',
        '2026-08-12T23:59:59.999Z',
        '2026-08-12T23:59:59.999+05:30',
        '2026-08-10T04:30:00.000-08:00',
      ]) {
        expect(
          createdAt.compareTo(bounds.startAt!) >= 0,
          isTrue,
          reason: '$createdAt sorted below startAt',
        );
        expect(
          createdAt.compareTo(bounds.endBefore!) < 0,
          isTrue,
          reason: '$createdAt sorted at or above endBefore',
        );
      }
    });

    test('excludes documents more than a day outside the range', () {
      final bounds = activityQueryBounds(
        from: DateTime(2026, 8, 10),
        to: DateTime(2026, 8, 12),
      );
      expect('2026-08-08T23:00:00.000Z'.compareTo(bounds.startAt!) < 0, isTrue);
      expect(
        '2026-08-14T01:00:00.000Z'.compareTo(bounds.endBefore!) >= 0,
        isTrue,
      );
    });
  });

  group('ShopActivity.covers', () {
    final fetched = activity(
      from: DateTime(2026, 8, 1),
      to: DateTime(2026, 8, 31),
    );

    test('a narrower question is answerable from what was fetched', () {
      expect(
        fetched.covers(from: DateTime(2026, 8, 10), to: DateTime(2026, 8, 12)),
        isTrue,
      );
      expect(
        fetched.covers(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31)),
        isTrue,
      );
    });

    test('a wider question is not', () {
      expect(
        fetched.covers(from: DateTime(2026, 7, 31), to: DateTime(2026, 8, 31)),
        isFalse,
      );
      expect(
        fetched.covers(from: DateTime(2026, 8, 1), to: DateTime(2026, 9, 1)),
        isFalse,
      );
      expect(fetched.covers(from: null, to: null), isFalse);
    });

    test('an all-time fetch answers everything', () {
      final everything = activity();
      expect(everything.covers(from: null, to: null), isTrue);
      expect(
        everything.covers(from: DateTime(2020), to: DateTime(2030)),
        isTrue,
      );
    });
  });
}
