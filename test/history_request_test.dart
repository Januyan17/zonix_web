import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/models/history_request.dart';
import 'package:zonixweb/services/history_request_service.dart';
import 'package:zonixweb/utils/history_request_state.dart';
import 'package:zonixweb/widgets/history_request_tile.dart';

/// Never called in these tests — the tile only touches the service when
/// the switch is tapped.
class _FakeService implements HistoryRequestService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HistoryRequest _req(String status, {DateTime? approvedAt}) =>
    HistoryRequest(ref: null, status: status, approvedAt: approvedAt);

void main() {
  group('HistoryRequest.fromMap', () {
    test('parses a complete document', () {
      final requested = DateTime.utc(2026, 11, 9, 8);
      final approved = DateTime.utc(2026, 11, 9, 9);
      final r = HistoryRequest.fromMap({
        'shop_id': 'demo-shop',
        'shop_name': 'Demo Shop',
        'device_id': 'dev-1',
        'device_name': 'samsung SM-A155F',
        'user_id': 'u1',
        'username': 'kumar',
        'display_name': 'Kumar',
        'role': 'staff',
        'status': 'approved',
        'requested_at': Timestamp.fromDate(requested),
        'approved_at': Timestamp.fromDate(approved),
        'approved_by': 'admin1',
      });
      expect(r.shopId, 'demo-shop');
      expect(r.shopName, 'Demo Shop');
      expect(r.deviceId, 'dev-1');
      expect(r.deviceName, 'samsung SM-A155F');
      expect(r.displayName, 'Kumar');
      expect(r.role, 'staff');
      expect(r.status, 'approved');
      expect(r.requestedAt!.isAtSameMomentAs(requested), isTrue);
      expect(r.approvedAt!.isAtSameMomentAs(approved), isTrue);
      expect(r.approvedBy, 'admin1');
    });

    test('tolerates an empty document', () {
      final r = HistoryRequest.fromMap({});
      expect(r.ref, isNull);
      expect(r.shopId, '');
      expect(r.status, '');
      expect(r.requestedAt, isNull);
      expect(r.approvedAt, isNull);
      expect(r.approvedBy, isNull);
      expect(r.shopLabel, '—');
      expect(r.userLabel, '—');
      expect(r.deviceLabel, 'this phone');
    });

    test('tolerates nulls and wrong types', () {
      final r = HistoryRequest.fromMap({
        'requested_at': null,
        'approved_at': 'not a date',
        'approved_by': 42,
        'role': 1,
        'device_name': null,
      });
      expect(r.requestedAt, isNull);
      expect(r.approvedAt, isNull);
      expect(r.approvedBy, isNull);
      expect(r.role, '1');
      expect(r.deviceName, '');
    });

    test('labels fall back to ids', () {
      final r = HistoryRequest.fromMap({
        'shop_id': 's1',
        'username': 'kumar',
        'device_id': 'dev-9',
      });
      expect(r.shopLabel, 's1');
      expect(r.userLabel, 'kumar');
      expect(r.deviceLabel, 'dev-9');
    });
  });

  group('historyRequestStatus', () {
    final approvedAt = DateTime(2026, 11, 9, 10);
    final expiry = approvedAt.add(const Duration(hours: 24));

    test('pending, including missing or unknown status', () {
      for (final status in ['pending', '', 'something-else']) {
        final s = historyRequestStatus(
          status: status,
          approvedAt: approvedAt,
          now: approvedAt,
        );
        expect(s.state, HistoryRequestState.pending, reason: status);
        expect(s.expiresAt, isNull);
      }
    });

    test('approved within 24h, with expiresAt = approved_at + 24h', () {
      final s = historyRequestStatus(
        status: 'approved',
        approvedAt: approvedAt,
        now: approvedAt.add(const Duration(hours: 23, minutes: 59)),
      );
      expect(s.state, HistoryRequestState.approved);
      expect(s.expiresAt, expiry);
    });

    test('expired at exactly 24h (valid only while now < expiry)', () {
      final s = historyRequestStatus(
        status: 'approved',
        approvedAt: approvedAt,
        now: expiry,
      );
      expect(s.state, HistoryRequestState.expired);
      expect(s.expiresAt, expiry);
    });

    test('one millisecond before 24h is still approved', () {
      final s = historyRequestStatus(
        status: 'approved',
        approvedAt: approvedAt,
        now: expiry.subtract(const Duration(milliseconds: 1)),
      );
      expect(s.state, HistoryRequestState.approved);
    });

    test(
      'approved with a pending server timestamp is approved, not expired',
      () {
        final s = historyRequestStatus(
          status: 'approved',
          approvedAt: null,
          now: approvedAt,
        );
        expect(s.state, HistoryRequestState.approved);
        expect(s.expiresAt, isNull);
      },
    );

    test('denied, even with an old approved_at left over', () {
      final s = historyRequestStatus(
        status: 'denied',
        approvedAt: approvedAt,
        now: approvedAt,
      );
      expect(s.state, HistoryRequestState.denied);
      expect(s.expiresAt, isNull);
    });
  });

  group('expiresInLabel', () {
    final now = DateTime(2026, 11, 9, 10);

    test('hours and minutes', () {
      expect(
        expiresInLabel(
          expiresAt: now.add(const Duration(hours: 5, minutes: 12)),
          now: now,
        ),
        'Expires in 5h 12m',
      );
      expect(
        expiresInLabel(expiresAt: now.add(const Duration(hours: 24)), now: now),
        'Expires in 24h 0m',
      );
    });

    test('under an hour shows minutes only', () {
      expect(
        expiresInLabel(
          expiresAt: now.add(const Duration(minutes: 45)),
          now: now,
        ),
        'Expires in 45m',
      );
    });

    test('rounds partial minutes up, never "0m" while valid', () {
      expect(
        expiresInLabel(
          expiresAt: now.add(const Duration(seconds: 10)),
          now: now,
        ),
        'Expires in 1m',
      );
      expect(
        expiresInLabel(
          expiresAt: now.add(const Duration(hours: 1, seconds: 1)),
          now: now,
        ),
        'Expires in 1h 1m',
      );
    });

    test('expired at or after the expiry', () {
      expect(expiresInLabel(expiresAt: now, now: now), 'Expired');
      expect(
        expiresInLabel(
          expiresAt: now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        'Expired',
      );
    });
  });

  group('splitExpired / hasLiveApproval', () {
    final now = DateTime(2026, 11, 10, 12);
    final live = _req(
      'approved',
      approvedAt: now.subtract(const Duration(hours: 1)),
    );
    final expired = _req(
      'approved',
      approvedAt: now.subtract(const Duration(hours: 24)),
    );
    final pending = _req('pending');
    final denied = _req('denied');

    test('moves only expired approvals out, keeping order', () {
      final groups = splitExpired([pending, expired, live, denied], now);
      expect(groups.current, [pending, live, denied]);
      expect(groups.expired, [expired]);
    });

    test('empty input gives two empty groups', () {
      final groups = splitExpired(const [], now);
      expect(groups.current, isEmpty);
      expect(groups.expired, isEmpty);
    });

    test('live approval detection', () {
      expect(hasLiveApproval([pending, live], now), isTrue);
      expect(hasLiveApproval([pending, expired, denied], now), isFalse);
      // The same request stops being live once its 24 hours pass.
      expect(
        hasLiveApproval([live], now.add(const Duration(hours: 23))),
        isFalse,
      );
    });
  });

  group('HistoryRequestTile', () {
    Widget host(HistoryRequest request) => MaterialApp(
      home: Scaffold(
        body: HistoryRequestTile(request: request, service: _FakeService()),
      ),
    );

    bool switchValue(WidgetTester tester) =>
        tester.widget<Switch>(find.byType(Switch)).value;

    testWidgets('switch is on while approved, off once 24h pass', (
      tester,
    ) async {
      // Approved so that the 24 hours run out ~300ms of real time from now.
      final approvedAt = DateTime.now()
          .subtract(historyApprovalWindow)
          .add(const Duration(milliseconds: 300));
      await tester.pumpWidget(host(_req('approved', approvedAt: approvedAt)));

      expect(switchValue(tester), isTrue);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.textContaining('Expires in'), findsOneWidget);

      // Let real time pass the expiry, then fire the tile's 30s ticker.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(seconds: 30));

      expect(switchValue(tester), isFalse);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.textContaining('Expires in'), findsNothing);
    });

    testWidgets('switch is off for pending, denied and expired', (
      tester,
    ) async {
      for (final request in [
        _req('pending'),
        _req('denied'),
        _req(
          'approved',
          approvedAt: DateTime.now().subtract(const Duration(hours: 25)),
        ),
      ]) {
        await tester.pumpWidget(host(request));
        expect(switchValue(tester), isFalse, reason: request.status);
      }
    });
  });
}
