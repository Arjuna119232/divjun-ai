import 'package:flutter/material.dart';

/// Token warna tunggal aplikasi.
///
/// ATURAN: tidak boleh ada `Color(0x...)` di luar file ini.
///-butuh warna baru? tambah token di sini, jangan karangan hex di layar.
abstract final class AppColors {
  // Brand
  static const Color brand = Color(0xFF5B5BD6);
  static const Color brandDeep = Color(0xFF3B3BA8);
  static const Color brandSoft = Color(0xFFE6E6FF);

  // Aksen (dipakai untuk status streaming / sukses)
  static const Color mint = Color(0xFF00BFA6);
  static const Color mintSoft = Color(0xFFD3FFF6);

  // Status
  static const Color amber = Color(0xFFFFA726);
  static const Color coral = Color(0xFFFF6B4A);
  static const Color danger = Color(0xFFE5484D);

  // Netral (permukaan)
  static const Color inkLight = Color(0xFF101017);
  static const Color inkDark = Color(0xFF0B0B10);
  static const Color surfaceLight = Color(0xFFFBFBFD);
  static const Color surfaceDark = Color(0xFF121218);
  static const Color lineLight = Color(0xFFE7E7EE);
  static const Color lineDark = Color(0xFF26262F);

  // Teks
  static const Color textLight = Color(0xFF14141A);
  static const Color textDark = Color(0xFFF2F2F7);
  static const Color textMutedLight = Color(0xFF6B6B78);
  static const Color textMutedDark = Color(0xFF9A9AA8);

  /// Warna bubble: pesan user (kanan) dan jawaban AI (kiri).
  static Color bubbleUser(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? AppColors.brand : AppColors.brand;
  static Color bubbleAi(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const Color(0xFF1C1C25)
          : Colors.white;

  /// Warna aksen untuk status tool saat agent sedang jalan.
  static const Color tool = Color(0xFF7C4DFF);
  static const Color toolSoft = Color(0xFFEDE4FF);
}
