import 'package:flutter/services.dart' show rootBundle;

/// Satu dokumen hukum yang ditampilkan di Pusat Legal.
class DokumenLegal {
  const DokumenLegal({
    required this.id,
    required this.judul,
    required this.ringkas,
    required this.berkas,
  });

  /// Penanda dokumen (`syarat`, `penggunaan`, `privasi`).
  final String id;

  /// Judul yang tampil di daftar dan di app bar halaman markdown.
  final String judul;

  /// Satu baris penjelasan di bawah judul.
  final String ringkas;

  /// Path asset markdown, mis. `assets/legal/terms.md`.
  final String berkas;
}

/// Pembaca dokumen Pusat Legal.
///
/// Isi dokumen sengaja TIDAK ditulis di Dart: seluruh teks hukum ada di
/// `assets/legal/*.md` supaya bisa diperbarui tanpa menyentuh UI.
abstract final class LegalService {
  /// Tanggal pembaruan dokumen (dipakai footer halaman markdown).
  static const String diperbarui = '19 Oktober 2026';

  static const List<DokumenLegal> daftar = <DokumenLegal>[
    DokumenLegal(
      id: 'syarat',
      judul: 'Syarat & Ketentuan',
      ringkas: 'Aturan pemakaian aplikasi dan batas tanggung jawab.',
      berkas: 'assets/legal/terms.md',
    ),
    DokumenLegal(
      id: 'penggunaan',
      judul: 'Panduan Penggunaan',
      ringkas: 'Cara memakai aplikasi dengan benar dan aman.',
      berkas: 'assets/legal/usage.md',
    ),
    DokumenLegal(
      id: 'privasi',
      judul: 'Kebijakan Privasi',
      ringkas: 'Data apa yang disimpan dan ke mana data dikirim.',
      berkas: 'assets/legal/privacy.md',
    ),
  ];

  /// Cari dokumen lewat id; null kalau id tidak dikenal.
  static DokumenLegal? cari(String id) {
    for (final DokumenLegal d in daftar) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Baca isi markdown dari bundle aplikasi lewat path asset-nya.
  static Future<String> baca(String berkas) {
    return rootBundle.loadString(berkas);
  }
}
