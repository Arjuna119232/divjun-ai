import 'package:divjun_ai/features/artifacts/domain/artifak.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parser artifak: harus benar untuk jawaban yang sudah selesai DAN yang
/// masih mengalir (pagar penutup belum datang).
void main() {
  group('PemecahJawaban.pecah', () {
    test('teks tanpa pagar dikembalikan utuh sebagai satu bagian', () {
      const teks = 'Halo, ini **jawaban** biasa.\n\n- satu\n- dua';
      final hasil = PemecahJawaban.pecah(teks);
      expect(hasil, hasLength(1));
      expect(hasil.first.kode, isFalse);
      expect(hasil.first.teks, teks);
      expect(hasil.first.artifak, isNull);
    });

    test('teks kosong menghasilkan daftar kosong', () {
      expect(PemecahJawaban.pecah(''), isEmpty);
    });

    test('memecah teks, blok kode, lalu teks lagi', () {
      const md = 'Berikut kodenya:\n\n```dart\nvoid main() {}\n```\n\nSelesai.';
      final hasil = PemecahJawaban.pecah(md);
      expect(hasil, hasLength(3));
      expect(hasil[0].kode, isFalse);
      expect(hasil[0].teks.trim(), 'Berikut kodenya:');
      expect(hasil[1].kode, isTrue);
      expect(hasil[1].bahasa, 'dart');
      expect(hasil[1].isi.trim(), 'void main() {}');
      expect(hasil[1].terbuka, isFalse);
      expect(hasil[2].teks.trim(), 'Selesai.');
    });

    test('pagar penutup yang belum datang ditandai terbuka', () {
      const md = 'Tunggu ya:\n```html\n<h1>Halo</h1>';
      final hasil = PemecahJawaban.pecah(md);
      expect(hasil, hasLength(2));
      expect(hasil[1].kode, isTrue);
      expect(hasil[1].terbuka, isTrue);
      expect(hasil[1].artifak!.terbuka, isTrue);
      expect(hasil[1].artifak!.jenis, JenisArtifak.html);
    });

    test('blok kosong tidak menghasilkan kartu', () {
      final hasil = PemecahJawaban.pecah('A\n```\n```\nB');
      expect(hasil, hasLength(2));
      expect(hasil.every((b) => !b.kode), isTrue);
    });

    test('pagar tilde boleh memuat backtick di dalamnya', () {
      const md = '~~~md\n# Judul\n\n```dart\nvar a = 1;\n```\n~~~';
      final hasil = PemecahJawaban.pecah(md);
      expect(hasil, hasLength(1));
      expect(hasil.first.kode, isTrue);
      expect(hasil.first.bahasa, 'md');
      expect(hasil.first.isi, contains('```dart'));
      expect(hasil.first.terbuka, isFalse);
    });

    test('pagar penutup harus sepanjang pagar pembuka', () {
      const md = '````\nkode\n```\nmasih kode\n`````';
      final hasil = PemecahJawaban.pecah(md);
      expect(hasil, hasLength(1));
      expect(hasil.first.kode, isTrue);
      expect(hasil.first.terbuka, isFalse);
      expect(hasil.first.isi, contains('masih kode'));
    });

    test('info string pagar diambil kata pertamanya', () {
      final hasil = PemecahJawaban.pecah('```HTML title="demo"\n<p>x</p>\n```');
      expect(hasil.single.bahasa, 'html');
      expect(hasil.single.artifak!.jenis, JenisArtifak.html);
    });

    test('CRLF dinormalkan, isi blok tetap utuh', () {
      final hasil = PemecahJawaban.pecah('a\r\n```dart\r\nvar x = 1;\r\n```');
      expect(hasil, hasLength(2));
      expect(hasil[1].isi, contains('var x = 1;'));
      expect(hasil[1].terbuka, isFalse);
    });
  });

  group('Artifak.dari', () {
    test('mengenali html, svg, markdown, dan kode', () {
      expect(Artifak.dari('<p>x</p>', 'html').jenis, JenisArtifak.html);
      expect(Artifak.dari('<svg/>', 'svg').jenis, JenisArtifak.svg);
      expect(Artifak.dari('# Judul', 'md').jenis, JenisArtifak.markdown);
      expect(Artifak.dari('int a = 1;', 'dart').jenis, JenisArtifak.kode);
    });

    test('tanpa label, jenis dikenali dari isi (bukan ditebak sembarang)', () {
      expect(
        Artifak.dari('<svg viewBox="0 0 1 1"></svg>', '').jenis,
        JenisArtifak.svg,
      );
      expect(
        Artifak.dari('<!doctype html><p>x</p>', '').jenis,
        JenisArtifak.html,
      );
      expect(Artifak.dari('SELECT 1;', '').jenis, JenisArtifak.kode);
    });

    test('label yang ditampilkan', () {
      expect(Artifak.dari('', 'html').label, 'HTML');
      expect(Artifak.dari('', 'svg').label, 'SVG');
      expect(Artifak.dari('', 'markdown').label, 'Markdown');
      expect(Artifak.dari('x', '').label, 'Kode');
      expect(Artifak.dari('x', 'sql').label, 'SQL');
    });

    test('judul diambil dari <title> dan dipotong kalau kepanjangan', () {
      expect(
        Artifak.dari(
          '<html><head><title>Nota  Jual</title></head></html>',
          'html',
        ).judul,
        'Nota Jual',
      );

      final String panjangSekali = List<String>.filled(80, 'a').join();
      final String judul = Artifak.dari(
        '<title>$panjangSekali</title>',
        'html',
      ).judul;
      expect(judul.length, 60);
      expect(judul.endsWith('...'), isTrue);
    });

    test('judul fallback memuat jenis dan jumlah baris', () {
      expect(Artifak.dari('a\nb\nc', 'sql').judul, 'Kode SQL · 3 baris');
      expect(Artifak.dari('a\nb', 'html').judul, 'Dokumen HTML · 2 baris');
    });

    test('jumlahBaris menghitung baris isi', () {
      expect(Artifak.dari('', 'dart').jumlahBaris, 0);
      expect(Artifak.dari('satu', 'dart').jumlahBaris, 1);
      expect(Artifak.dari('satu\ndua\n', 'dart').jumlahBaris, 3);
    });

    test('bisaPratinjau hanya untuk isi non-kode yang terisi', () {
      expect(Artifak.dari('<p>x</p>', 'html').bisaPratinjau, isTrue);
      expect(Artifak.dari('   ', 'html').bisaPratinjau, isFalse);
      expect(Artifak.dari('int a = 1;', 'dart').bisaPratinjau, isFalse);
    });

    test('dokumenHtml membungkus isi, dokumen utuh dipakai apa adanya', () {
      final String bungkus = Artifak.dari('<h1>Halo</h1>', 'html').dokumenHtml();
      expect(bungkus, startsWith('<!doctype html>'));
      expect(bungkus, contains('<h1>Halo</h1>'));
      // Latar putih dipaksa: dokumen gelap tidak boleh ikut tema app.
      expect(bungkus, contains('background:#ffffff'));
      expect(bungkus, contains('color-scheme'));

      const String utuh = '<!DOCTYPE html><html><body>x</body></html>';
      expect(Artifak.dari(utuh, 'html').dokumenHtml(), utuh);
    });

    test('svg dibungkus kanvas supaya berada di tengah', () {
      final String d = Artifak.dari('<svg></svg>', 'svg').dokumenHtml();
      expect(d, contains('class="kanvas"'));
      expect(d, contains('<svg></svg>'));
    });

    test('Artifak.kosong aman sebagai fallback rute', () {
      expect(Artifak.kosong.isi, isEmpty);
      expect(Artifak.kosong.bisaPratinjau, isFalse);
      expect(Artifak.kosong.jumlahBaris, 0);
      expect(Artifak.kosong.judul, 'Artifak');
      expect(Artifak.kosong.terbuka, isFalse);
    });
  });
}
