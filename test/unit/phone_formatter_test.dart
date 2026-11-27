import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/formatting/phone_formatter.dart';

void main() {
  group('PhoneFormatter Unit Tests', () {
    test('format converts local 08... prefix to +628...', () {
      expect(PhoneFormatter.format('081234567890'), '+6281234567890');
    });

    test('format converts 8... prefix to +628...', () {
      expect(PhoneFormatter.format('81234567890'), '+6281234567890');
    });

    test('format cleans accidental +620... to +62...', () {
      expect(PhoneFormatter.format('+62081234567890'), '+6281234567890');
    });

    test('format preserves already formatted +628...', () {
      expect(PhoneFormatter.format('+6281234567890'), '+6281234567890');
    });

    test('format handles spaces, dashes, and parentheses', () {
      expect(PhoneFormatter.format('0812-3456-7890'), '+6281234567890');
      expect(PhoneFormatter.format('(0812) 3456 7890'), '+6281234567890');
    });

    test('format returns null on empty or null input', () {
      expect(PhoneFormatter.format(null), isNull);
      expect(PhoneFormatter.format(''), isNull);
      expect(PhoneFormatter.format('   '), isNull);
    });
  });

  group('IndonesianPhoneInputFormatter Tests (Auto +62 on typing 0)', () {
    const formatter = IndonesianPhoneInputFormatter();

    test('Typing "0" into empty field automatically becomes "+62"', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '+62');
      expect(result.selection.baseOffset, 3);
    });

    test('Pasting "081234567890" automatically transforms to "+6281234567890"', () {
      const oldValue = TextEditingValue.empty;
      const newValue = TextEditingValue(
        text: '081234567890',
        selection: TextSelection.collapsed(offset: 12),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '+6281234567890');
      expect(result.selection.baseOffset, 14);
    });

    test('Typing digits after "+62" continues smoothly', () {
      const oldValue = TextEditingValue(
        text: '+62',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '+628',
        selection: TextSelection.collapsed(offset: 4),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '+628');
      expect(result.selection.baseOffset, 4);
    });

    test('Accidental typing of "0" right after "+62" (+620...) strips the 0', () {
      const oldValue = TextEditingValue(
        text: '+62',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '+620',
        selection: TextSelection.collapsed(offset: 4),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '+62');
      expect(result.selection.baseOffset, 3);
    });

    test('Backspace deletion on "+62" is allowed (does not lock user)', () {
      const oldValue = TextEditingValue(
        text: '+62',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '+6',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '+6');
      expect(result.selection.baseOffset, 2);
    });
  });
}
