import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/models/shop_billing.dart';
import 'package:zonixweb/widgets/billing_widgets.dart';

void main() {
  group('addMonths', () {
    test('keeps the same day', () {
      expect(addMonths(DateTime(2026, 11, 10), 1), DateTime(2026, 12, 10));
    });
    test('rolls over the year', () {
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
    });
    test('clamps to the end of a shorter month', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });
  });

  group('period keys', () {
    test('round-trip', () {
      final d = DateTime(2026, 3);
      expect(periodKey(d), '2026-03');
      expect(parsePeriodKey('2026-03'), d);
    });
    test('reject junk', () {
      expect(parsePeriodKey('2026-13'), isNull);
      expect(parsePeriodKey('nope'), isNull);
      expect(parsePeriodKey(null), isNull);
    });
  });

  group('dueStateAt', () {
    final now = DateTime(2026, 11, 10, 15, 30);
    ShopBilling due(DateTime d) => ShopBilling(nextDueAt: d);

    test('not set', () {
      expect(const ShopBilling().dueStateAt(now), BillingDueState.notSet);
    });
    test('overdue by calendar day, not by hour', () {
      expect(
        due(DateTime(2026, 11, 9, 23)).dueStateAt(now),
        BillingDueState.overdue,
      );
      expect(due(DateTime(2026, 11, 9)).daysUntilDue(now), -1);
    });
    test('due today even if earlier the same day', () {
      expect(
        due(DateTime(2026, 11, 10)).dueStateAt(now),
        BillingDueState.dueToday,
      );
    });
    test('due soon within the window', () {
      expect(
        due(DateTime(2026, 11, 10 + kBillingDueSoonDays)).dueStateAt(now),
        BillingDueState.dueSoon,
      );
    });
    test('upcoming beyond the window', () {
      expect(
        due(DateTime(2026, 11, 11 + kBillingDueSoonDays)).dueStateAt(now),
        BillingDueState.upcoming,
      );
      expect(due(DateTime(2026, 12, 10)).needsAttentionAt(now), isFalse);
    });
  });

  test('fromMap parses payments newest first and tolerates junk', () {
    final billing = ShopBilling.fromMap({
      'billing_amount': 1500,
      'billing_next_due_at': Timestamp.fromDate(DateTime(2026, 12, 10)),
      'billing_payments': [
        {
          'id': 'a',
          'amount': 1500,
          'paid_at': Timestamp.fromDate(DateTime(2026, 10, 10)),
          'period': '2026-10',
        },
        'junk',
        {
          'id': 'b',
          'amount': 1500.5,
          'paid_at': Timestamp.fromDate(DateTime(2026, 11, 10)),
          'period': '2026-11',
          'note': 'cash',
        },
      ],
    });
    expect(billing.monthlyAmount, 1500);
    expect(billing.payments.map((p) => p.id), ['b', 'a']);
    expect(billing.isPaidFor(DateTime(2026, 11)), isTrue);
    expect(billing.isPaidFor(DateTime(2026, 9)), isFalse);
    expect(billing.totalPaid, 3000.5);
    expect(billing.lastPayment!.note, 'cash');
  });

  test('fromMap on a doc without billing fields', () {
    final billing = ShopBilling.fromMap({'name': 'Shop', 'createdAt': 'x'});
    expect(billing.isSetUp, isFalse);
    expect(billing.payments, isEmpty);
  });

  group('amount parsing', () {
    test('accepts commas and decimals', () {
      expect(parseAmount('1,500'), 1500);
      expect(parseAmount(' 99.50 '), 99.5);
    });
    test('validation', () {
      expect(amountError(''), isNotNull);
      expect(amountError('', required: false), isNull);
      expect(amountError('abc'), isNotNull);
      expect(amountError('0'), isNotNull);
      expect(amountError('2500'), isNull);
    });
  });

  group('multi-month payments', () {
    ShopBilling withPayments(List<Map<String, dynamic>> payments) =>
        ShopBilling.fromMap({'billing_payments': payments});

    test('old payments without months read as one month', () {
      final b = withPayments([
        {
          'id': 'old',
          'amount': 1000,
          'paid_at': Timestamp.fromDate(DateTime(2026, 5, 3)),
          'period': '2026-05',
        },
      ]);
      expect(b.payments.single.months, 1);
      expect(b.isPaidFor(DateTime(2026, 5)), isTrue);
      expect(b.isPaidFor(DateTime(2026, 6)), isFalse);
      expect(b.paidThrough, DateTime(2026, 5));
      expect(b.payments.single.coverageLabel, 'May 2026');
    });

    test('a 4-month payment covers every month in its range', () {
      final b = withPayments([
        {
          'id': 'p',
          'amount': 6000,
          'paid_at': Timestamp.fromDate(DateTime(2026, 11, 10)),
          'period': '2026-11',
          'months': 4,
        },
      ]);
      final p = b.payments.single;
      expect(b.isPaidFor(DateTime(2026, 10)), isFalse);
      for (final m in [
        DateTime(2026, 11),
        DateTime(2026, 12),
        DateTime(2027, 1),
        DateTime(2027, 2),
      ]) {
        expect(b.isPaidFor(m), isTrue, reason: '$m');
      }
      expect(b.isPaidFor(DateTime(2027, 3)), isFalse);
      expect(p.lastPeriod, DateTime(2027, 2));
      expect(b.paidThrough, DateTime(2027, 2));
      expect(p.coverageLabel, 'Nov 2026 – Feb 2027');
    });

    test('next due after a 7-month payment', () {
      expect(addMonths(DateTime(2026, 11, 10), 7), DateTime(2027, 6, 10));
      expect(addMonths(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
    });

    test('months is clamped to a sane range', () {
      final b = withPayments([
        {
          'id': 'x',
          'amount': 1,
          'paid_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'period': '2026-01',
          'months': 0,
        },
      ]);
      expect(b.payments.single.months, 1);
    });
  });

  group('picked months', () {
    test('non-consecutive months are stored and read back', () {
      final p = ShopPayment(
        id: 'g',
        amount: 3000,
        paidAt: DateTime(2026, 11, 10),
        periods: [DateTime(2027, 1), DateTime(2026, 11), DateTime(2026, 11)],
      );
      expect(p.periods, [DateTime(2026, 11), DateTime(2027, 1)]);
      expect(p.months, 2);
      expect(p.coverageLabel, 'Nov 2026, Jan 2027');

      final map = p.toMap();
      expect(map['periods'], ['2026-11', '2027-01']);
      expect(map['period'], '2026-11');
      expect(map['months'], 2);

      final b = ShopBilling.fromMap({
        'billing_payments': [map],
      });
      expect(b.isPaidFor(DateTime(2026, 11)), isTrue);
      expect(b.isPaidFor(DateTime(2026, 12)), isFalse);
      expect(b.isPaidFor(DateTime(2027, 1)), isTrue);
      expect(b.paidThrough, DateTime(2027, 1));
    });

    test('consecutive picks read as a range', () {
      expect(
        describePeriods([DateTime(2026, 12), DateTime(2026, 11)]),
        'Nov 2026 – Dec 2026',
      );
    });

    test('next due: one month keeps the one-month-after rule', () {
      expect(
        defaultNextDue(
          paidAt: DateTime(2026, 11, 10),
          selected: [DateTime(2026, 11)],
          billing: const ShopBilling(),
        ),
        DateTime(2026, 12, 10),
      );
    });

    test('next due: a run of 7 months', () {
      expect(
        defaultNextDue(
          paidAt: DateTime(2026, 11, 10),
          selected: [for (var i = 0; i < 7; i++) DateTime(2026, 11 + i)],
          billing: const ShopBilling(),
        ),
        DateTime(2027, 6, 10),
      );
    });

    test('next due: a gap gets reminded', () {
      expect(
        defaultNextDue(
          paidAt: DateTime(2026, 11, 10),
          selected: [DateTime(2026, 11), DateTime(2027, 1)],
          billing: const ShopBilling(),
        ),
        DateTime(2026, 12, 10),
      );
    });

    test('next due: a gap already paid earlier is skipped', () {
      final billing = ShopBilling.fromMap({
        'billing_payments': [
          {
            'id': 'dec',
            'amount': 1,
            'paid_at': Timestamp.fromDate(DateTime(2026, 10, 1)),
            'period': '2026-12',
          },
        ],
      });
      expect(
        defaultNextDue(
          paidAt: DateTime(2026, 11, 31 - 1),
          selected: [DateTime(2026, 11), DateTime(2027, 1)],
          billing: billing,
        ),
        DateTime(2027, 2, 28),
      );
    });
  });
}
