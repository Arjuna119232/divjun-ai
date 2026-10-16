import '../../../core/utils/teks.dart';
import '../../../domain/entities/memori.dart';
import 'alat.dart';

/// Tool memori jangka panjang: simpan / cari / hapus semua.
///
/// Memori hanya berisi fakta yang memang diminta user disimpan, tidak
/// merekam seluruh percakapan.
class AlatMemori extends Alat {
  const AlatMemori();

  @override
  String get nama => 'memori';

  @override
  String get deskripsi =>
      'Kelola memori jangka panjang user. aksi: "simpan" (fakta, preferensi, '
      'jadwal, proyek), "cari" (ingat kembali), "hapus_semua". '
      'Simpan hanya kalau user bilang "ingat ini" atau memang fakta penting '
      'yang akan dipakai lagi. Jangan simpan kode/token/password.';

  @override
  Map<String, dynamic> get parameter => {
        'type': 'object',
        'properties': {
          'aksi': {
            'type': 'string',
            'enum': <String>['simpan', 'cari', 'hapus_semua'],
            'description': 'Yang ingin dilakukan.',
          },
          'isi': {
            'type': 'string',
            'description': 'Fakta yang disimpan (aksi=simpan).',
          },
          'kategori': {
            'type': 'string',
            'enum': KategoriMemori.semua,
            'description': 'Kategori fakta (aksi=simpan). Default: umum.',
          },
          'kueri': {
            'type': 'string',
            'description': 'Kata kunci pencarian (aksi=cari).',
          },
        },
        'required': <String>['aksi'],
      };

  @override
  Future<HasilAlat> jalankan(Map<String, dynamic> args, KonteksAlat ctx) async {
    if (!ctx.bolehMemori) {
      return HasilAlat.salah(
        'Memori dimatikan di pengaturan.',
        ringkasan: 'Memori nonaktif',
      );
    }
    final String aksi = (args['aksi'] as String? ?? '').toLowerCase().trim();

    switch (aksi) {
      case 'simpan':
        final String isi = (args['isi'] as String? ?? '').trim();
        if (isi.isEmpty) {
          return HasilAlat.salah('Isi memori kosong.', ringkasan: 'Isi kosong');
        }
        if (_berbahaya(isi)) {
          return HasilAlat.salah(
            'Isi terlihat seperti password/token/kunci - tidak disimpan demi '
            'keamanan. Minta user menyimpan sendiri.',
            ringkasan: 'Ditolak: resembles a secret',
          );
        }
        final SimpanMemori? simpan = ctx.simpanMemori;
        if (simpan == null) {
          return HasilAlat.salah(
            'Penyimpanan memori tidak tersedia.',
            ringkasan: 'Memori tidak tersedia',
          );
        }
        final EntriMemori e = await simpan(
          isi: isi,
          kategori: args['kategori'] as String? ?? KategoriMemori.umum,
        );
        return HasilAlat.ok(
          'Tersimpan di memori (${KategoriMemori.label(e.kategori)}): ${e.isi}',
          ringkasan: 'Diingat: ${Teks.potong(e.isi, 40)}',
        );

      case 'cari':
        final String kueri = (args['kueri'] as String? ?? '').trim();
        final List<EntriMemori> hasil = await ctx.bacaMemori(
          kueri.isEmpty ? args.toString() : kueri,
        );
        if (hasil.isEmpty) {
          return HasilAlat.ok(
            'Tidak ada memori yang cocok dengan "$kueri".',
            ringkasan: 'Memori kosong',
          );
        }
        final String isi = hasil
            .map((EntriMemori e) =>
                '- [${KategoriMemori.label(e.kategori)}] ${e.isi}')
            .join('\n');
        return HasilAlat.ok(
          'Ditemukan ${hasil.length} memori:\n$isi',
          ringkasan: '${hasil.length} memori ditemukan',
        );

      case 'hapus_semua':
        // Penghapusan massal tetap butuh persetujuan UI, jadi tool hanya
        // melaporkan keadaan, tidak menghapus diam-diam.
        final List<EntriMemori> semua = await ctx.bacaMemori('');
        return HasilAlat.ok(
          'Ada ${semua.length} entri memori. Hapus hanya dilakukan dari layar '
          'Memori setelah user menekan tombol hapus (agar tidak hilang tanpa '
          'sadar).',
          ringkasan: '${semua.length} entri memori',
        );

      default:
        return HasilAlat.salah(
          'aksi tidak dikenal. Pakai simpan, cari, atau hapus_semua.',
          ringkasan: 'Aksi tidak dikenal',
        );
    }
  }

  static bool _berbahaya(String isi) {
    final String s = isi.toLowerCase();
    const List<String> pola = [
      'password',
      'passcode',
      'api key',
      'api_key',
      'secret',
      'token',
      'private key',
      'pin atm',
      'cvv',
      'otp',
    ];
    return pola.any((String p) => s.contains(p));
  }
}
