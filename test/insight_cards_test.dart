import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/models/product.dart';
import 'package:zonixweb/models/shop_insights.dart';
import 'package:zonixweb/models/shop_stats.dart';
import 'package:zonixweb/screens/shop_detail/widgets/product_performance_card.dart';
import 'package:zonixweb/screens/shop_detail/widgets/sales_rhythm_card.dart';
import 'package:zonixweb/screens/shop_detail/widgets/stat_widgets.dart';

/// Rendering checks for the analytics cards. Layout overflow and a null
/// dereference in a rarely-hit branch both fail a widget test but neither
/// fails `flutter analyze`, and these cards each have an empty state that
/// only shows up on shops with no data.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 900, child: child),
      ),
    ),
  );

  const stats = ShopStats(
    salesCount: 4,
    totalRevenue: 400,
    totalCogs: 120,
    totalExpenses: 50,
    totalAdditionalIncome: 0,
    productCount: 3,
    unitsSold: 12,
  );

  testWidgets('stat tiles show derived figures and period deltas', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        StatsSection(
          loading: false,
          stats: stats,
          comparison: StatsComparison(
            current: stats,
            previous: const ShopStats(
              salesCount: 2,
              totalRevenue: 200,
              totalCogs: 50,
              totalExpenses: 100,
              totalAdditionalIncome: 0,
              productCount: 3,
              unitsSold: 6,
            ),
            previousRange: StatsDateRange(
              start: _aug3,
              end: _aug9,
            ),
          ),
          voids: const VoidStats(count: 1, value: 30, keptCount: 4),
        ),
      ),
    );

    expect(find.text('Avg order value'), findsOneWidget);
    // Average order value: 400 over 4 sales.
    expect(find.text('Rs 100.00'), findsOneWidget);
    expect(find.text('3 items each'), findsOneWidget);
    expect(find.text('Gross margin'), findsOneWidget);
    expect(find.text('70.0%'), findsOneWidget);
    expect(find.text('Units sold'), findsOneWidget);
    // Revenue doubled.
    expect(find.text('+100%'), findsWidgets);
    // Expenses halved — a good move for a cost, so it is not an error read.
    expect(find.text('-50%'), findsOneWidget);
    expect(find.text('Voided sales'), findsOneWidget);
  });

  testWidgets('no sales leaves averages dashed rather than zeroed', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const StatsSection(
          loading: false,
          stats: ShopStats(
            salesCount: 0,
            totalRevenue: 0,
            totalCogs: 0,
            totalExpenses: 0,
            totalAdditionalIncome: 0,
            productCount: 3,
          ),
        ),
      ),
    );

    expect(find.text('—'), findsWidgets);
    // Nothing to void, so the tile stays off the page entirely.
    expect(find.text('Voided sales'), findsNothing);
  });

  testWidgets('product card ranks by revenue and switches to units', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ProductPerformanceCard(
          loading: false,
          performance: const [
            ProductPerformance(
              key: 'p2',
              name: 'Cake',
              unitsSold: 1,
              revenue: 100,
              cogs: 40,
              saleCount: 1,
            ),
            ProductPerformance(
              key: 'p1',
              name: 'Tea',
              unitsSold: 5,
              revenue: 75,
              cogs: 25,
              saleCount: 2,
            ),
          ],
          deadStock: const [Product(id: 'p3', name: 'Scone')],
          rangeLabel: 'this week',
        ),
      ),
    );

    expect(find.text('Top products · this week'), findsOneWidget);
    expect(find.text('Rs 100.00'), findsOneWidget);
    expect(find.text('60% margin'), findsOneWidget);
    expect(find.text('1 product sold nothing in this period'), findsOneWidget);

    await tester.tap(find.text('Units'));
    await tester.pumpAndSettle();
    expect(find.text('5 sold'), findsOneWidget);
  });

  testWidgets('product card says so when sales carry no line items', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ProductPerformanceCard(
          loading: false,
          performance: [],
          deadStock: [],
          rangeLabel: 'today',
        ),
      ),
    );
    expect(find.textContaining('No itemized sales'), findsOneWidget);
  });

  testWidgets('rhythm card names the busiest hour', (tester) async {
    await tester.pumpWidget(
      host(
        SalesRhythmCard(
          loading: false,
          hours: [
            for (var hour = 0; hour < 24; hour++)
              HourBucket(
                hour: hour,
                salesCount: hour == 9 ? 3 : 0,
                revenue: hour == 9 ? 120 : 0,
              ),
          ],
          weekdays: [
            for (var day = 1; day <= 7; day++)
              WeekdayBucket(
                weekday: day,
                salesCount: day == 1 ? 3 : 0,
                revenue: day == 1 ? 120 : 0,
              ),
          ],
          rangeLabel: 'this week',
        ),
      ),
    );

    expect(
      find.text('Busiest hour: 9am–10am · 3 sales · Rs 120.00'),
      findsOneWidget,
    );
    expect(find.text('Mon'), findsOneWidget);
  });

  testWidgets('rhythm card handles a period with no sales', (tester) async {
    await tester.pumpWidget(
      host(
        SalesRhythmCard(
          loading: false,
          hours: [
            for (var hour = 0; hour < 24; hour++)
              HourBucket(hour: hour, salesCount: 0, revenue: 0),
          ],
          weekdays: [
            for (var day = 1; day <= 7; day++)
              WeekdayBucket(weekday: day, salesCount: 0, revenue: 0),
          ],
          rangeLabel: 'today',
          showWeekdays: false,
        ),
      ),
    );

    expect(find.text('No sales in this period.'), findsOneWidget);
    expect(find.text('Mon'), findsNothing);
  });
}

final _aug3 = DateTime(2026, 8, 3);
final _aug9 = DateTime(2026, 8, 9);
