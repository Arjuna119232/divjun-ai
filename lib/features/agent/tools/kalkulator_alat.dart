import 'kalkulator.dart';
import 'alat.dart';

/// Tool kalkulator. Parser aman (tidak memakai eval), hasil diformat gaya
/// Indonesia (pemisah ribuan titik).
class AlatKalkulator extends Alat {
  const AlatKalkulator();

  @override
  String get nama => 'kalkulator';

  @override
  String get deskripsi =>
      'Hitung ekspresi matematika. Contoh: "12.500 + 3.400", '
      '"(80+20)/4 * 1.5", "sqrt(144)", "20% dari 1.500.000". '
      'Gunakan untuk setiap soal hitung, jangan menebak sendiri.';

  @override
  Map<String, dynamic> get parameter => {
        'type': 'object',
        'properties': {
          'ekspresi': {
            'type': 'string',
            'description': 'Ekspresi matematika, contoh: (12000 + 8000) / 4',
          },
        },
        'required': <String>['ekspresi'],
      };

  @override
  Future<HasilAlat> jalankan(Map<String, dynamic> args, KonteksAlat ctx) async {
    if (!ctx.bolehKalkulator) {
      return HasilAlat.salah(
        'Kalkulator dimatikan di pengaturan.',
        ringkasan: 'Kalkulator nonaktif',
      );
    }
    final String ekspresi = (args['ekspresi'] as String? ?? '').trim();
    if (ekspresi.isEmpty) {
      return HasilAlat.salah(
        'Argumen "ekspresi" kosong. Minta user menulis ekspresinya.',
        ringkasan: 'Ekspresi kosong',
      );
    }
    final double? nilai = Kalkulator.hitung(ekspresi);
    if (nilai == null) {
      return HasilAlat.salah(
        'Ekspresi "$ekspresi" tidak bisa dihitung. Periksa tanda kurung, '
        'atau nama fungsi (sqrt, sin, cos, log, ln, abs, round, floor, ceil).',
        ringkasan: 'Ekspresi tidak valid',
      );
    }
    return HasilAlat.ok(
      '$ekspresi = ${Kalkulator.format(nilai)}',
      ringkasan: '${Kalkulator.format(nilai)}',
    );
  }
}
