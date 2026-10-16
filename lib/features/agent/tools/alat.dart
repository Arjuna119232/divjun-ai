import '../../../domain/entities/memori.dart';
import '../../../domain/entities/setelan.dart';

/// Hasil satu pemanggilan tool.
class HasilAlat {
  const HasilAlat({
    required this.isi,
    this.ringkasan = '',
    this.gagal = false,
    this.aksiUI,
  });

  final String isi;

  /// Teks pendek yang ditampilkan di bubble AI (satu baris).
  final String ringkasan;
  final bool gagal;

  /// Tipe aksi opsional untuk UI (mis. 'buka_email' dengan payload).
  final Map<String, String>? aksiUI;

  static HasilAlat ok(String isi, {String ringkasan = '', Map<String, String>? aksiUI}) =>
      HasilAlat(isi: isi, ringkasan: ringkasan, aksiUI: aksiUI);

  static HasilAlat salah(String isi, {String ringkasan = ''}) =>
      HasilAlat(isi: isi, ringkasan: ringkasan, gagal: true);
}

/// Konteks yang boleh dipakai sebuah tool.
///
/// purposefully sempit: tool tidak boleh menyentuh UI, hanya data + izin.
class KonteksAlat {
  KonteksAlat({
    required this.setelan,
    required this.simpanMemori,
    required this.bacaMemori,
    required this.sudahBatal,
  });

  final SetelanApp setelan;
  final Future<EntriMemori> Function({required String isi, String kategori})?
      simpanMemori;
  final Future<List<EntriMemori>> Function(String kueri) bacaMemori;
  final bool Function() sudahBatal;

  bool get bolehWeb => setelan.izinkanWeb;
  bool get bolehEmail => setelan.izinkanEmail;
  bool get bolehKalkulator => setelan.izinkanKalkulator;
  bool get bolehMemori => setelan.ingatMemori;
}

/// Kontrak satu tool yang Offer ke LLM sebagai native function.
abstract class Alat {
  const Alat();

  String get nama;
  String get deskripsi;
  Map<String, dynamic> get parameter;
  Future<HasilAlat> jalankan(Map<String, dynamic> args, KonteksAlat ctx);
}
