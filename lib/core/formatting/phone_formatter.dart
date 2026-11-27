import 'package:flutter/services.dart';

/// Formatter nomor telepon dan TextInputFormatter untuk penomoran Indonesia (+62).
class PhoneFormatter {
  PhoneFormatter._();

  /// Menstandarisasi string nomor telepon ke format E.164 (+62...).
  static String? format(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final clean = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return null;

    if (clean.startsWith('+620')) {
      return '+62${clean.substring(4)}';
    }
    if (clean.startsWith('0')) {
      return '+62${clean.substring(1)}';
    }
    if (clean.startsWith('8')) {
      return '+62$clean';
    }
    if (!clean.startsWith('+')) {
      return '+$clean';
    }
    return clean;
  }
}

/// [TextInputFormatter] real-time untuk input nomor telepon.
///
/// Fitur:
/// - Saat pengguna menginput '0' di awal, otomatis berubah menjadi '+62'.
/// - Jika menempelkan (paste) '08...', otomatis menjadi '+628...'.
/// - Jika tidak sengaja mengetik '0' setelah '+62' (misal '+620...'), angka '0' tersebut otomatis dibersihkan.
class IndonesianPhoneInputFormatter extends TextInputFormatter {
  const IndonesianPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }

    // 1. Jika di awal menginput '0', otomatis ubah '0' di awal menjadi '+62'
    if (text.startsWith('0')) {
      final replaced = '+62${text.substring(1)}';
      return TextEditingValue(
        text: replaced,
        selection: TextSelection.collapsed(offset: replaced.length),
      );
    }

    // 2. Jika setelah '+62' pengguna mengetik '0' (+620...), hilangkan '0' tersebut
    if (text.startsWith('+620')) {
      final cleaned = '+62${text.substring(4)}';
      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }

    return newValue;
  }
}
