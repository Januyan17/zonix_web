import 'package:flutter_test/flutter_test.dart';
import 'package:zonixweb/features/contact_zonix/utils/sri_lanka_phone.dart';

void main() {
  test('accepts the documented formats and normalises them', () {
    for (final input in [
      '0771234567',
      '771234567',
      '+94 77 123 4567',
      '+94771234567',
      '0094 77 123 4567',
      '94771234567',
      '077-123-4567',
      ' (077) 123 4567 ',
    ]) {
      expect(formatSriLankaPhone(input), '+94 77 123 4567', reason: input);
    }
  });

  test('accepts landlines but only offers WhatsApp for mobiles', () {
    expect(formatSriLankaPhone('0112345678'), '+94 11 234 5678');
    expect(sriLankaWhatsAppUri('0112345678'), isNull);
    expect(
      sriLankaWhatsAppUri('+94771234567').toString(),
      'https://wa.me/94771234567',
    );
    expect(sriLankaTelUri('0771234567').toString(), 'tel:+94771234567');
  });

  test('rejects invalid numbers', () {
    for (final input in [
      '',
      '12345',
      '07712345678',
      '+1 555 123 4567',
      '+0771234567',
      'abc0771234567',
      '0071234567',
    ]) {
      expect(isValidSriLankaPhone(input), isFalse, reason: input);
    }
  });
}
