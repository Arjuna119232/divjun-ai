import 'alat.dart';

/// Tool draf email.
///
/// App tidak pernah mengirim email diam-diam ke server SMTP.
/// Yang terjadi: draf dibuat, lalu app membuka aplikasi email user dengan
/// draf terisi (mailto:) sehingga user menekan "Kirim" sendiri di sana.
class AlatEmail extends Alat {
  const AlatEmail();

  @override
  String get nama => 'email';

  @override
  String get deskripsi =>
      'Buat draf email (tidak langsung terkirim). Param: recipient, subjek, '
      'isi. Sistem akan membuka aplikasi email user dengan draf siap kirim. '
      'Selalu tanya konfirmasi ke user sebelum memanggil tool ini, kecuali '
      'user sudah bilang "kirim" secara eksplisit.';

  @override
  Map<String, dynamic> get parameter => {
        'type': 'object',
        'properties': {
          'recipient': {
            'type': 'string',
            'description': 'Email penerima. Bisa lebih dari satu, pisah koma.',
          },
          'subjek': {
            'type': 'string',
            'description': 'Subjek email.',
          },
          'isi': {
            'type': 'string',
            'description': 'Isi email dalam Bahasa Indonesia yang sopan.',
          },
        },
        'required': <String>['recipient', 'subjek', 'isi'],
      };

  @override
  Future<HasilAlat> jalankan(Map<String, dynamic> args, KonteksAlat ctx) async {
    if (!ctx.bolehEmail) {
      return HasilAlat.salah(
        'Fitur email dimatikan di pengaturan.',
        ringkasan: 'Email nonaktif',
      );
    }
    final String penerima = (args['recipient'] as String? ?? '').trim();
    final String subjek = (args['subjek'] as String? ?? '').trim();
    final String isi = (args['isi'] as String? ?? '').trim();

    if (penerima.isEmpty || subjek.isEmpty || isi.isEmpty) {
      return HasilAlat.salah(
        'recipient, subjek, dan isi wajib diisi.',
        ringkasan: 'Draf tidak lengkap',
      );
    }

    final String isiSiap = '$isi\n\n---\nDikirim dari DIVJUN AI';
    final String mailto = Uri(
      scheme: 'mailto',
      path: penerima,
      queryParameters: <String, String>{
        'subject': subjek,
        'body': isiSiap,
      },
    ).toString();

    return HasilAlat.ok(
      'Draf siap:\nKe: $penerima\nSubjek: $subjek\n\n$isiSiap\n\n'
      'LINK_BUKA:$mailto',
      ringkasan: 'Draf ke $penerima',
      aksiUI: <String, String>{
        'tipe': 'buka_email',
        'mailto': mailto,
      },
    );
  }
}
