import '../../../data/models/chat_api.dart';
import '../../../domain/entities/setelan.dart';
import 'alat.dart';
import 'email_alat.dart';
import 'kalkulator_alat.dart';
import 'memori_alat.dart';
import 'waktu_alat.dart';
import 'web_alat.dart';

/// Daftar tool yang boleh ditawarkan ke LLM.
///
///\code
/// Semua tool punya dua lapis saklar: setelan user (izinkan*) dan
/// ketersediaan API key di build. Tool yang mati TIDAK dikirim ke model,
/// jadi model tidak pernah memanggil alat yang pasti gagal.
class DaftarAlat {
  DaftarAlat({SetelanApp? setelan, AlatWeb? web})
      : _setelan = setelan ?? const SetelanApp(),
        _web = web ?? AlatWeb();

  SetelanApp _setelan;
  final AlatWeb _web;

  static const List<Alat> _inti = <Alat>[
    AlatKalkulator(),
    AlatWaktu(),
    AlatMemori(),
  ];

  List<Alat> aktif() {
    final List<Alat> daftar = <Alat>[];
    for (final Alat a in _inti) {
      if (a is AlatKalkulator && !_setelan.izinkanKalkulator) continue;
      if (a is AlatMemori && !_setelan.ingatMemori) continue;
      daftar.add(a);
    }
    if (_setelan.izinkanWeb) daftar.add(_web);
    if (_setelan.izinkanEmail) daftar.add(const AlatEmail());
    return daftar;
  }

  List<ToolSpec> specs() =>
      aktif().map((Alat a) => ToolSpec(
            nama: a.nama,
            deskripsi: a.deskripsi,
            parameter: a.parameter,
          )).toList();

  Alat? cari(String nama) {
    for (final Alat a in aktif()) {
      if (a.nama == nama) return a;
    }
    return null;
  }

  List<String> namaAktif() => aktif().map((Alat a) => a.nama).toList();

  void terapkan(SetelanApp baru) {
    _setelan = baru;
  }
}
