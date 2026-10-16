import 'package:divjun_ai/core/utils/url_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Penjaga SSRF: tool web tidak boleh bisa menyentuh jaringan privat.
void main() {
  group('UrlGuard.boleh', () {
    test('menolak alamat privat & internal', () {
      expect(UrlGuard.boleh('http://127.0.0.1'), isFalse);
      expect(UrlGuard.boleh('http://localhost:8080'), isFalse);
      expect(UrlGuard.boleh('https://169.254.169.254/latest/meta-data/'), isFalse);
      expect(UrlGuard.oleh('http://192.168.1.1'), isFalse);
      expect(UrlGuard.boleh('http://10.0.0.5'), isFalse);
      expect(UrlGuard.boleh('http://172.16.0.1'), isFalse);
      expect(UrlGuard.boleh('http://[::1]/'), isFalse);
      expect(UrlGuard.boleh('http://router.local'), isFalse);
    });

    test('menerima URL publik', () {
      expect(UrlGuard.boleh('https://example.com'), isTrue);
      expect(UrlGuard.boleh('https://news.bbc.co.uk/berita'), isTrue);
      expect(UrlGuard.boleh('http://example.com:8080'), isFalse); // port bukan 80
    });

    test('menolak skema selain http/https', () {
      expect(UrlGuard.boleh('ftp://example.com'), isFalse);
      expect(UrlGuard.boleh('file:///etc/passwd'), isFalse);
      expect(UrlGuard.boleh('javascript:alert(1)'), isFalse);
    });

    test('alasan penolakan selalu Bahasa Indonesia', () {
      final String pesan = UrlGuard.alasan('http://127.0.0.1');
      expect(pesan.isNotEmpty, isTrue);
      expect(pesan.contains('diblokir') || pesan.contains('http'), isTrue);
    });
  });
}
