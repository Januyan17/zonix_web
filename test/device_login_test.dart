import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/features/device_logins/models/device_login.dart';
import 'package:zonixweb/features/device_logins/models/device_session.dart';
import 'package:zonixweb/features/device_logins/utils/device_grouping.dart';
import 'package:zonixweb/features/device_logins/utils/device_login_badges.dart';

void main() {
  group('DeviceLogin.fromMap', () {
    test('parses a complete document', () {
      final created = DateTime.utc(2026, 11, 9, 8, 30);
      final l = DeviceLogin.fromMap('abc', {
        'shop_id': 'demo-shop',
        'shop_slug': 'demo-shop',
        'shop_name': 'Demo Shop',
        'user_id': 'uid1',
        'username': 'kumar',
        'display_name': 'Kumar',
        'role': 'staff',
        'device_id': 'dev-1',
        'device_name': 'samsung SM-A155F',
        'platform': 'android',
        'os_version': 'Android 15',
        'app_version': '1.0.1',
        'app_build': 7,
        'created_at': Timestamp.fromDate(created),
      });
      expect(l.id, 'abc');
      expect(l.shopId, 'demo-shop');
      expect(l.shopName, 'Demo Shop');
      expect(l.displayName, 'Kumar');
      expect(l.role, 'staff');
      expect(l.deviceName, 'samsung SM-A155F');
      expect(l.platform, 'android');
      expect(l.osVersion, 'Android 15');
      expect(l.appVersion, '1.0.1');
      expect(l.appBuild, 7);
      expect(l.createdAt!.isAtSameMomentAs(created), isTrue);
    });

    test('tolerates an empty document', () {
      final l = DeviceLogin.fromMap('x', {});
      expect(l.id, 'x');
      expect(l.shopId, '');
      expect(l.displayName, '');
      expect(l.appBuild, isNull);
      expect(l.createdAt, isNull);
      expect(l.shopLabel, '—');
      expect(l.userLabel, '—');
    });

    test('tolerates wrong types and a pending timestamp', () {
      final l = DeviceLogin.fromMap('x', {
        'app_build': '12',
        'created_at': null,
        'role': 3,
        'display_name': null,
      });
      expect(l.appBuild, 12);
      expect(l.createdAt, isNull);
      expect(l.role, '3');
      expect(l.displayName, '');

      final bad = DeviceLogin.fromMap('y', {'app_build': 'abc'});
      expect(bad.appBuild, isNull);
    });

    test('app_build stored as a double still reads as an int', () {
      expect(DeviceLogin.fromMap('x', {'app_build': 9.0}).appBuild, 9);
    });

    test('labels fall back through name, slug/username, id', () {
      expect(
        DeviceLogin.fromMap('x', {
          'shop_slug': 'slug',
          'shop_id': 'id',
        }).shopLabel,
        'slug',
      );
      expect(DeviceLogin.fromMap('x', {'shop_id': 'id'}).shopLabel, 'id');
      expect(
        DeviceLogin.fromMap('x', {'username': 'kumar'}).userLabel,
        'kumar',
      );
    });
  });

  group('isOldBuild', () {
    test('flags a build below the floor', () {
      expect(isOldBuild(appBuild: 4, minSupportedBuild: 5), isTrue);
    });

    test('does not flag a build at or above the floor', () {
      expect(isOldBuild(appBuild: 5, minSupportedBuild: 5), isFalse);
      expect(isOldBuild(appBuild: 6, minSupportedBuild: 5), isFalse);
    });

    test('never flags when either side is unknown or the floor is 0', () {
      expect(isOldBuild(appBuild: null, minSupportedBuild: 5), isFalse);
      expect(isOldBuild(appBuild: 1, minSupportedBuild: null), isFalse);
      expect(isOldBuild(appBuild: 0, minSupportedBuild: 0), isFalse);
    });
  });

  group('groupDeviceLogins', () {
    DeviceLogin install(
      String id, {
      String shopId = 's1',
      String userId = 'u1',
      String deviceId = '',
      String deviceName = 'Xiaomi 2201117TG',
      String platform = 'android',
    }) => DeviceLogin(
      id: id,
      shopId: shopId,
      userId: userId,
      deviceId: deviceId.isEmpty ? 'dev-$id' : deviceId,
      deviceName: deviceName,
      platform: platform,
    );

    test('folds reinstalls on the same phone into one group, newest first', () {
      final groups = groupDeviceLogins([
        install('a', deviceName: 'Google Pixel 10'),
        install('b'),
        install('c'),
        install('d'),
      ]);
      expect(groups, hasLength(2));
      expect(groups[0].latest.id, 'a');
      expect(groups[1].installs.map((l) => l.id), ['b', 'c', 'd']);
      expect(groups[1].installCount, 3);
      expect(groups[1].earliest.id, 'd');
    });

    test('model name match ignores case but not platform, user or shop', () {
      final groups = groupDeviceLogins([
        install('a', deviceName: 'XIAOMI 2201117TG'),
        install('b'),
        install('c', platform: 'ios'),
        install('d', userId: 'u2'),
        install('e', shopId: 's2'),
      ]);
      expect(groups.map((g) => g.installCount), [2, 1, 1, 1]);
    });

    test('the same install reported twice counts once, keeping the oldest', () {
      final group = groupDeviceLogins([
        install('newer-report', deviceId: 'dev-x'),
        install('other-install', deviceId: 'dev-y'),
        install('first-report', deviceId: 'dev-x'),
      ]).single;
      expect(group.installCount, 2);
      expect(group.installs.map((l) => l.id), [
        'other-install',
        'first-report',
      ]);
      // A delete still removes the hidden repeat.
      expect(group.records, hasLength(3));
      expect(group.recordsOf(group.installs.last).map((l) => l.id), [
        'newer-report',
        'first-report',
      ]);
    });

    test('rows without a model name never merge', () {
      final groups = groupDeviceLogins([
        install('a', deviceName: ''),
        install('b', deviceName: ''),
      ]);
      expect(groups, hasLength(2));
    });

    test('rows missing shop or user never merge with each other', () {
      final groups = groupDeviceLogins([
        install('a', userId: ''),
        install('b', userId: ''),
      ]);
      expect(groups, hasLength(2));
      expect(groups.first.userKey, isNull);
      expect(userKeysOf(groups), isEmpty);
    });

    test('userKeysOf is one key per person per shop', () {
      final groups = groupDeviceLogins([
        install('a', deviceName: 'Pixel'),
        install('b'),
        install('c', userId: 'u2'),
      ]);
      expect(userKeysOf(groups), {'s1/u1', 's1/u2'});
    });
  });

  group('DeviceGroup.activeSessionIn', () {
    final group = groupDeviceLogins([
      const DeviceLogin(
        id: 'a',
        shopId: 's1',
        userId: 'u1',
        deviceId: 'new',
        deviceName: 'Pixel',
      ),
      const DeviceLogin(
        id: 'b',
        shopId: 's1',
        userId: 'u1',
        deviceId: 'old',
        deviceName: 'Pixel',
      ),
    ]).single;

    test('null sessions means unknown, not signed out', () {
      expect(group.activeSessionIn(null), isNull);
    });

    test('matches a session on any install of the device', () {
      final s = group.activeSessionIn([
        DeviceSession(deviceId: 'other', loggedInAt: DateTime(2026, 11, 15)),
        DeviceSession(deviceId: 'old', loggedInAt: DateTime(2026, 11, 14)),
      ]);
      expect(s?.deviceId, 'old');
    });

    test('picks the most recent login when several installs are live', () {
      final s = group.activeSessionIn([
        DeviceSession(deviceId: 'old', loggedInAt: DateTime(2026, 11, 14)),
        DeviceSession(deviceId: 'new', loggedInAt: DateTime(2026, 11, 15)),
      ]);
      expect(s?.deviceId, 'new');
    });

    test('no matching session means signed out', () {
      expect(
        group.activeSessionIn([const DeviceSession(deviceId: 'other')]),
        isNull,
      );
    });
  });

  group('DeviceSession.fromMap', () {
    test('falls back to the document id and tolerates bad fields', () {
      final s = DeviceSession.fromMap('doc-id', {
        'device_name': 3,
        'logged_in_at': 'nope',
      });
      expect(s.deviceId, 'doc-id');
      expect(s.deviceName, '');
      expect(s.loggedInAt, isNull);
    });

    test('parses a Timestamp', () {
      final at = DateTime.utc(2026, 11, 14, 18, 0);
      final s = DeviceSession.fromMap('x', {
        'device_id': 'dev-1',
        'logged_in_at': Timestamp.fromDate(at),
      });
      expect(s.deviceId, 'dev-1');
      expect(s.loggedInAt!.isAtSameMomentAs(at), isTrue);
    });
  });
}
