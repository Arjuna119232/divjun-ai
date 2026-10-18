import 'package:dio/dio.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/utils/teks.dart';
import '../../../core/utils/url_guard.dart';
import 'alat.dart';

/// Tool web: buka satu URL dan summarize jadi teks.
///
/// Keamanan berlapis:
/// 1) hanya http/https, port 80/443;
/// 2) blokir host privat/internal (termasuk 169.254.169.254 metadata awan);
/// 3) cek hasil resolusi DNS supaya tidak rebound ke IP privat;
/// 4) batasi ukuran unduhan + timeout.
class AlatWeb extends Alat {
  AlatWeb({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: AppConfig.timeoutWebDetik),
              maxRedirects: 3,
              validateStatus: (int? s) => s != null && s < 500,
            ));

  final Dio _dio;

  @override
  String get nama => 'buka_url';

  @override
  String get deskripsi =>
      'Ambil isi teks dari satu URL publik (artikel, dokumentasi, halaman web). '
      'Hanya satu URL per panggilan. Jangan gunakan untuk alamat privat, '
      'localhost, atau halaman yang butuh login.';

  @override
  Map<String, dynamic> get parameter => {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'URL lengkap dengan http:// atau https://',
          },
        },
        'required': <String>['url'],
      };

  @override
  Future<HasilAlat> jalankan(Map<String, dynamic> args, KonteksAlat ctx) async {
    if (!ctx.bolehWeb) {
      return HasilAlat.salah(
        'Akses web dimatikan di pengaturan.',
        ringkasan: 'Web nonaktif',
      );
    }
    final String url = (args['url'] as String? ?? '').trim();
    if (url.isEmpty) {
      return HasilAlat.salah(
        'URL kosong.',
        ringkasan: 'URL kosong',
      );
    }

    final String? masalah = await UrlGuard.cekDns(url);
    if (masalah != null) {
      return HasilAlat.salah(masalah, ringkasan: 'URL diblokir');
    }

    try {
      final Response<String> r = await _dio.get<String>(
        url,
        options: Options(
          headers: const <String, String>{
            'User-Agent': AppConfig.userAgent,
            'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8',
            'Accept-Language': 'id-ID,id;q=0.9,en;q=0.6',
          },
          responseType: ResponseType.plain,
        ),
      );

      final int kode = r.statusCode ?? 0;
      if (kode >= 400) {
        return HasilAlat.salah(
          'Halaman membalas HTTP $kode.',
          ringkasan: 'HTTP $kode',
        );
      }

      final String html = r.data ?? '';
      if (html.trim().isEmpty) {
        return HasilAlat.salah(
          'Halaman kosong.',
          ringkasan: 'Halaman kosong',
        );
      }

      final String judul = Teks.judulHalaman(html);
      final String teks = Teks.ringkas(
        Teks.htmlKeTeks(html),
        AppConfig.maksHurufWeb,
      );

      return HasilAlat.ok(
        'Sumber: $url\n'
        'Judul: ${judul.isEmpty ? '(tanpa judul)' : judul}\n'
        'Isi:\n$teks',
        ringkasan: judul.isEmpty ? Teks.host(url) : judul,
      );
    } on DioException catch (e) {
      return HasilAlat.salah(
        'Gagal membuka halaman: ${e.type.name}.',
        ringkasan: 'Gagal buka URL',
      );
    } catch (e) {
      return HasilAlat.salah('Gagal membuka halaman: $e', ringkasan: 'Error web');
    }
  }
}
