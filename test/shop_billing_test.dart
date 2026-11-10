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
}
