import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/features/device_logins/models/device_login.dart';
import 'package:zonixweb/features/device_logins/utils/device_login_badges.dart';

DeviceLogin login(String id, {String shopId = 's1', String userId = 'u1'}) =>
    DeviceLogin(id: id, shopId: shopId, userId: userId);

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

  group('repeat install', () {
    test('flags every row of a shop+user seen more than once', () {
      final logins = [login('a'), login('b', userId: 'u2'), login('c')];
      final keys = repeatInstallKeys(logins);
      expect(keys, {'s1/u1'});
      expect(isRepeatInstall(logins[0], keys), isTrue);
      expect(isRepeatInstall(logins[1], keys), isFalse);
      expect(isRepeatInstall(logins[2], keys), isTrue);
    });

    test('the same user in different shops is not a repeat', () {
      final logins = [login('a', shopId: 's1'), login('b', shopId: 's2')];
      expect(repeatInstallKeys(logins), isEmpty);
    });

    test('rows missing shop_id or user_id never match', () {
      final logins = [
        login('a', userId: ''),
        login('b', userId: ''),
        login('c', shopId: ''),
        login('d', shopId: ''),
      ];
      final keys = repeatInstallKeys(logins);
      expect(keys, isEmpty);
      expect(logins.any((l) => isRepeatInstall(l, keys)), isFalse);
    });

    test('empty list has no repeats', () {
      expect(repeatInstallKeys(const []), isEmpty);
    });
  });
}
