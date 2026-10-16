import '../../../core/utils/waktu.dart';
import 'alat.dart';

/// Tool tanggal/waktu. Mengembalikan waktu Indonesia (WIB/WITA/WIT) + jam
/// dunia untuk zona yang diminta.
class AlatWaktu extends Alat {
  const AlatWaktu();

  @override
  String get nama => 'waktu_sekarang';

  @override
  String get deskripsi =>
      'Ambil tanggal dan jam saat ini. Opsional: zona (WIB, WITA, WIT, atau '
      'seperti Europe/Paris). Gunakan setiap kali user menanyakan jam, '
      'tanggal, hari, atau "berapa lama lagi".';

  @override
  Map<String, dynamic> get parameter => {
        'type': 'object',
        'properties': {
          'zona': {
            'type': 'string',
            'description': 'Zona waktu. Contoh: WIB, WITA, WIT, Asia/Jakarta.',
          },
        },
        'required': <String>[],
      };

  static const Map<String, int> _offsetJam = {
    'wib': 7,
    'asia/jakarta': 7,
    'wita': 9,
    'asia/makassar': 9,
    'wit': 10,
    'asia/jayapura': 10,
    'utc': 0,
  };

  @override
  Future<HasilAlat> jalankan(Map<String, dynamic> args, KonteksAlat ctx) async {
    final DateTime lokal = DateTime.now();
    final String zona = (args['zona'] as String? ?? 'WIB').trim();
    final int? offset = _offsetJam[zona.toLowerCase()];

    if (offset == null) {
      return HasilAlat.ok(
        'Zona "$zona" tidak dikenal. Zona tersedia: WIB (+7), WITA (+9), '
        'WIT (+10), UTC (0).',
        ringkasan: 'Zona waktu tidak dikenal: $zona',
      );
    }

    final DateTime target = lokal.toUtc().add(Duration(hours: offset));
    final String isi = 'Zona: $zona (UTC${offset >= 0 ? '+' : ''}$offset)\n'
        'Tanggal: ${Waktu.tanggalPanjang(target)}\n'
        'Jam: ${Waktu.jamDetik(target)}\n'
        'Hari dalam minggu: ${Waktu.tanggalPanjang(target).split(',').first}\n'
        'Waktu lokal perangkat: ${Waktu.tanggalPanjang(lokal)} '
        '${Waktu.jamDetik(lokal)}';

    return HasilAlat.ok(isi, ringkasan: '$zona ${Waktu.jamDetik(target)}');
  }
}
