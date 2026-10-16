import 'dart:convert';

/// Entri memori jangka panjang milik user (disimpan lokal di perangkat).
///
/// Yang disimpan hanya fakta yang ditulis user lewat tool `memory`,
/// bukan seluruh isi percakapan.
class EntriMemori {
  const EntriMemori({
    required this.id,
    required this.kategori,
    required this.isi,
    required this.dibuat,
    this.dipakai = 0,
    this.sumber = 'user',
  });

  final String id;
  final String kategori;
  final String isi;
  final DateTime dibuat;
  final int dipakai;
  final String sumber;

  EntriMemori salin({int? dipakai, DateTime? dibuat}) => EntriMemori(
        id: id,
        kategori: kategori,
        isi: isi,
        dibuat: dibuat ?? this.dibuat,
        dipakai: dipakai ?? this.dipakai,
        sumber: sumber,
      );

  Map<String, dynamic> keJson() => {
        'id': id,
        'kategori': kategori,
        'isi': isi,
        'dibuat': dibuat.toIso8601String(),
        'dipakai': dipakai,
        'sumber': sumber,
      };

  static EntriMemori dariJson(Map<String, dynamic> j) => EntriMemori(
        id: j['id'] as String? ?? '',
        kategori: j['kategori'] as String? ?? 'umum',
        isi: j['isi'] as String? ?? '',
        dibuat: DateTime.tryParse(j['dibuat'] as String? ?? '') ?? DateTime.now(),
        dipakai: (j['dipakai'] as num?)?.toInt() ?? 0,
        sumber: j['sumber'] as String? ?? 'user',
      );

  static String keJsonRapi(List<EntriMemori> daftar) =>
      const JsonEncoder.withIndent('  ').convert(
        daftar.map((EntriMemori e) => e.keJson()).toList(),
      );
}

/// Kategori memori yang dipakai tool.
abstract final class KategoriMemori {
  static const String profil = 'profil';
  static const String preferensi = 'preferensi';
  static const String proyek = 'proyek';
  static const String jadwal = 'jadwal';
  static const String umum = 'umum';

  static const List<String> semua = [
    profil,
    preferensi,
    proyek,
    jadwal,
    umum,
  ];

  static String label(String kategori) => switch (kategori) {
        profil => 'Profil',
        preferensi => 'Preferensi',
        proyek => 'Proyek',
        jadwal => 'Jadwal',
        _ => 'Umum',
      };
}
