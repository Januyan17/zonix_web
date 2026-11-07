import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/utils/app_version_validation.dart';

void main() {
  group('isAbsoluteHttpUrl', () {
    test('accepts absolute http(s) URLs', () {
      expect(isAbsoluteHttpUrl('https://builds.zonix.app/zonix-5.apk'), isTrue);
      expect(isAbsoluteHttpUrl('http://example.com/a.apk'), isTrue);
      expect(
        isAbsoluteHttpUrl('https://play.google.com/store/apps/details?id=x'),
        isTrue,
      );
      expect(isAbsoluteHttpUrl('  https://example.com/a.apk  '), isTrue);
    });

    test('rejects anything the OS could not open on its own', () {
      expect(isAbsoluteHttpUrl(''), isFalse);
      expect(isAbsoluteHttpUrl('builds.zonix.app/zonix.apk'), isFalse);
      expect(isAbsoluteHttpUrl('/downloads/zonix.apk'), isFalse);
      expect(isAbsoluteHttpUrl('javascript:alert(1)'), isFalse);
      expect(isAbsoluteHttpUrl('ftp://example.com/a.apk'), isFalse);
    });
  });

  group('buildNumberError', () {
    test('accepts the resting floor of 0 but not a distributed build 0', () {
      expect(buildNumberError('0', min: 0), isNull);
      expect(buildNumberError('0', min: 1), isNotNull);
    });

    test('rejects empty, non-numeric, and dotted version strings', () {
      expect(buildNumberError('', min: 0), 'Required');
      expect(buildNumberError('  ', min: 0), 'Required');
      expect(buildNumberError(null, min: 0), 'Required');
      expect(buildNumberError('1.0.3', min: 0), isNotNull);
      expect(buildNumberError('v5', min: 0), isNotNull);
    });

    test('rejects negatives', () {
      expect(buildNumberError('-1', min: 0), isNotNull);
    });

    test('accepts ordinary build numbers', () {
      expect(buildNumberError('5', min: 0), isNull);
      expect(buildNumberError(' 12 ', min: 1), isNull);
    });
  });

  group('buildOrderError', () {
    test('allows a floor at or below the newest distributed build', () {
      expect(buildOrderError(minSupportedBuild: 5, latestBuild: 5), isNull);
      expect(buildOrderError(minSupportedBuild: 3, latestBuild: 5), isNull);
      expect(buildOrderError(minSupportedBuild: 0, latestBuild: 1), isNull);
    });

    test('rejects a floor above anything downloadable', () {
      expect(buildOrderError(minSupportedBuild: 6, latestBuild: 5), isNotNull);
    });
  });

  group('androidDownloadUrlError', () {
    test('is required once the floor blocks anyone', () {
      expect(androidDownloadUrlError('', minSupportedBuild: 1), isNotNull);
      expect(androidDownloadUrlError(null, minSupportedBuild: 9), isNotNull);
    });

    test('is optional while the floor blocks nobody', () {
      expect(androidDownloadUrlError('', minSupportedBuild: 0), isNull);
    });

    test('still rejects a malformed URL even at floor 0', () {
      expect(
        androidDownloadUrlError('not a url', minSupportedBuild: 0),
        isNotNull,
      );
    });

    test('accepts a valid link', () {
      expect(
        androidDownloadUrlError(
          'https://builds.zonix.app/zonix-5.apk',
          minSupportedBuild: 5,
        ),
        isNull,
      );
    });
  });

  group('iosDownloadUrlError', () {
    test('allows empty regardless of the floor', () {
      expect(iosDownloadUrlError(''), isNull);
      expect(iosDownloadUrlError(null), isNull);
    });

    test('validates the shape when set', () {
      expect(iosDownloadUrlError('testflight.apple.com/join/x'), isNotNull);
      expect(iosDownloadUrlError('https://testflight.apple.com/join/x'), isNull);
    });
  });
}
