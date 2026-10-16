/// Penjaga URL untuk tool `web`.
///
/// Menolak alamat privat/internal supaya LLM tidak bisa dipakai mem-fetch
/// metadata awan (169.254.169.254), router rumah, atau localhost app.
/// Return nilai, bukan exception, supaya agent bisa membalas dengan jujur.
library;

import 'dart:io';

abstract final class UrlGuard {
  static bool _izin(int? port, {required int defaultPort}) =>
      port == null || port == defaultPort;

  /// Host yang tidak pernah boleh dibuka, apa pun port-nya.
  static const Set<String> _hostDilarang = {
    'localhost',
    'localhost.localdomain',
    'metadata.google.internal',
    'metadata',
    'instance-data',
  };

  static bool _ipPublik(String ip) {
    // IPv4
    final List<int> okt = ip.split('.').map((e) => int.tryParse(e) ?? -1).toList();
    if (okt.length == 4 && !okt.contains(-1)) {
      if (okt[0] == 10) return false; // 10.0.0.0/8
      if (okt[0] == 127) return false; // loopback
      if (okt[0] == 0) return false; // "this" network
      if (okt[0] == 169 && okt[1] == 254) return false; // link-local + metadata
      if (okt[0] == 172 && okt[1] >= 16 && okt[1] <= 31) return false;
      if (okt[0] == 192 && okt[1] == 168) return false;
      if (okt[0] == 100 && okt[1] >= 64 && okt[1] <= 127) return false; // CGNAT
      if (okt[0] >= 224) return false; // multicast/reserved
      return true;
    }
    // IPv6
    final String v = ip.toLowerCase();
    if (v == '::1' || v == '::') return false;
    if (v.startsWith('fe80')) return false; // link-local
    if (v.startsWith('fc') || v.startsWith('fd')) return false; // ULA
    if (v.startsWith('::ffff:127.')) return false;
    if (v.startsWith('::ffff:10.')) return false;
    if (v.startsWith('::ffff:192.168.')) return false;
    if (v.startsWith('::ffff:169.254.')) return false;
    if (v.startsWith('::ffff:172.')) {
      const String prefiks = '::ffff:172.';
      final List<String> bagian =
          v.substring(prefiks.length).split('.');
      if (bagian.isNotEmpty) {
        final int? kedua = int.tryParse(bagian.first);
        if (kedua != null && kedua >= 16 && kedua <= 31) return false;
      }
    }
    return true;
  }

  /// true = aman dibuka.
  static bool boleh(String urlMasuk) {
    final Uri? u = Uri.tryParse(urlMasuk.trim());
    if (u == null) return false;
    if (u.scheme != 'http' && u.scheme != 'https') return false;
    final String host = u.host.toLowerCase();
    if (host.isEmpty) return false;
    if (_hostDilarang.contains(host)) return false;
    if (host.endsWith('.local') || host.endsWith('.internal')) return false;
    if (_ipPublik(host)) return false;
    final bool http = u.scheme == 'http';
    if (!_izin(u.port, defaultPort: http ? 80 : 443)) return false;
    return true;
  }

  /// Alasan penolakan dalam Bahasa Indonesia (untuk dibalas ke user).
  static String alasan(String urlMasuk) {
    final Uri? u = Uri.tryParse(urlMasuk.trim());
    if (u == null) return 'URL tidak bisa dibaca.';
    if (u.scheme != 'http' && u.scheme != 'https') {
      return 'Hanya URL http/https yang boleh dibuka.';
    }
    final String host = u.host.toLowerCase();
    if (_hostDilarang.contains(host) ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      return 'Alamat internal ($host) diblokir demi keamanan.';
    }
    if (!_ipPublik(host)) return 'Alamat jaringan privat ($host) diblokir.';
    final bool http = u.scheme == 'http';
    if (!_izin(u.port, defaultPort: http ? 80 : 443)) {
      return 'Port ${u.port} diblokir (hanya 80/443).';
    }
    return 'URL tidak valid.';
  }

  /// Sama seperti [boleh], tapi juga cek hasil resolusi DNS (anti rebound ke IP privat).
  static Future<String?> cekDns(String urlMasuk) async {
    final Uri? u = Uri.tryParse(urlMasuk.trim());
    if (u == null || u.host.isEmpty) return 'URL tidak valid.';
    if (!boleh(urlMasuk)) return alasan(urlMasuk);
    try {
      final List<InternetAddress> hasil =
          await InternetAddress.lookup(u.host).timeout(
        const Duration(seconds: 5),
      );
      for (final InternetAddress a in hasil) {
        if (!_ipPublik(a.address)) {
          return 'Alamat $urlMasuk nyasar ke jaringan privat - diblokir.';
        }
      }
    } on SocketException {
      return 'Host tidak bisa diresolvsi.';
    } catch (_) {
      // DNS gagal tidak selalu berarti berbahaya; biarkan request yang menilai.
    }
    return null;
  }
}
