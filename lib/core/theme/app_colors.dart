import 'package:flutter/material.dart';

/// Palet warna aplikasi yang mematuhi pedoman Apple Human Interface Guidelines (HIG).
///
/// Aturan:
/// - Warna semantik berpasangan untuk Light Mode & Dark Mode.
/// - Emerald/Green untuk kondisi positif (pemasukan/surplus).
/// - Crimson/Red untuk pengeluaran/peringatan.
/// - Navy & Neutral sebagai warna dasar permukaan dan teks.
/// - Rasio kontras terjamin >= 4.5:1 untuk teks standar.
class AppColors {
  AppColors._();

  // === Emerald Green (Income / Positive / Surplus) ===
  static const Color incomeLight = Color(0xFF0E7A4A);
  static const Color incomeDark = Color(0xFF2ED573);
  static const Color incomeContainerLight = Color(0xFFE6F7EF);
  static const Color incomeContainerDark = Color(0xFF0F3B24);

  // === Crimson Red (Expense / Warning / Over-budget) ===
  static const Color expenseLight = Color(0xFFD63031);
  static const Color expenseDark = Color(0xFFFF5252);
  static const Color expenseContainerLight = Color(0xFFFFEEEE);
  static const Color expenseContainerDark = Color(0xFF4A1010);

  // === Transfer / Neutral Blue ===
  static const Color transferLight = Color(0xFF0984E3);
  static const Color transferDark = Color(0xFF70A1FF);
  static const Color transferContainerLight = Color(0xFFEBF5FB);
  static const Color transferContainerDark = Color(0xFF0E3254);

  // === Warning / Near-limit ===
  static const Color warningLight = Color(0xFFE67E22);
  static const Color warningDark = Color(0xFFFFA502);
  static const Color warningContainerLight = Color(0xFFFEF5E7);
  static const Color warningContainerDark = Color(0xFF4E2E08);

  // === Primary Navy Brand ===
  static const Color primaryNavy = Color(0xFF1E272E);
  static const Color primaryNavyLight = Color(0xFF2C3E50);

  // === Semantic Aliases ===
  static const Color primary = incomeLight;
  static const Color primaryLight = incomeDark;
  static const Color error = expenseLight;
  static const Color errorLight = expenseDark;
  static const Color accent = transferLight;
  static const Color accentLight = transferDark;
  static const Color surfaceModalLight = surfaceElevatedLight;
  static const Color surfaceModalDark = surfaceElevatedDark;

  // === Light Mode Surfaces ===
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceCardLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color dividerLight = Color(0xFFF1F2F6);

  // === Light Mode Text ===
  static const Color textPrimaryLight = Color(0xFF111827);   // Contrast 14.5:1 on white
  static const Color textSecondaryLight = Color(0xFF4B5563); // Contrast 7.1:1 on white
  static const Color textTertiaryLight = Color(0xFF6B7280);  // Contrast 4.6:1 on white
  static const Color textDisabledLight = Color(0xFF9CA3AF);

  // === Dark Mode Surfaces ===
  static const Color backgroundDark = Color(0xFF0B0F14);
  static const Color surfaceDark = Color(0xFF151C24);
  static const Color surfaceCardDark = Color(0xFF1E2833);
  static const Color surfaceElevatedDark = Color(0xFF26323F);
  static const Color borderDark = Color(0xFF2D3B48);
  static const Color dividerDark = Color(0xFF1A232D);

  // === Dark Mode Text ===
  static const Color textPrimaryDark = Color(0xFFF9FAFB);   // Contrast 15.8:1 on 0xFF151C24
  static const Color textSecondaryDark = Color(0xFFD1D5DB); // Contrast 9.2:1
  static const Color textTertiaryDark = Color(0xFF9CA3AF);  // Contrast 4.8:1
  static const Color textDisabledDark = Color(0xFF6B7280);
}
