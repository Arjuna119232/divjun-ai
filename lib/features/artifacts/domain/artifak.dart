/// Pemecah jawaban AI menjadi bagian teks + blok kode, dan pengenal
/// "artifak" — blok yang layak dibuka sebagai dokumen sendiri.
///
/// Kenapa dipisah di layer domain, bukan di widget:
/// - Hanya di sini ada aturan pagar (```` ``` ````) yang bisa diuji tanpa
///   Flutter (lihat `test/artifak_test.dart`).
/// - Saat stream masih mengalir, pagar penutup belum datang. Parser harus
///   tetap menghasilkan blok yang bisa ditampilkan, dengan penanda
///   [BagianTeks.terbuka] supaya UI tidak menawarkan "pratinjau" atas
///   dokumen setengah jadi.
library;

/// Jenis isi sebuah blok kode.
enum JenisArtifak {
  /// Dokumen web yang bisa langsung dirender (`html`, `htm`, `xhtml`).
  html,

  /// Gambar vektor (`svg`).
  svg,

  /// Markdown yang enak dibaca sebagai dokumen (`md`, `markdown`).
  markdown,

  /// Kode sumber biasa — hanya bisa dilihat sebagai teks.
  kode,
}

/// Satu potongan jawaban: teks biasa atau blok kode.
class BagianTeks {
  const BagianTeks.teks(this.teks)
      : kode = false,
        isi = '',
        bahasa = '',
        terbuka = false;

  const BagianTeks.kode({
    required this.isi,
    required this.bahasa,
    this.terbuka = false,
  })  : kode = true,
        teks = '';

  /// Isi teks biasa (markdown). Kosong kalau [kode] benar.
  final String teks;

  /// True = potongan ini blok kode berpagar.
  final bool kode;

  /// Isi blok kode tanpa pagar. Kosong kalau [kode] salah.
  final String isi;

  /// Label bahasa dari pagar pembuka (`dart`, `html`, ...). Boleh kosong.
  final String bahasa;

  /// True = pagar penutup belum diterima (jawaban masih mengalir).
  final bool terbuka;

  /// Artifak hasil pengenalan, atau null untuk potongan teks biasa.
  Artifak? get artifak => kode ? Artifak.dari(isi, bahasa, terbuka: terbuka) : null;
}

/// Blok yang bisa dibuka sebagai dokumen/pratinjau.
class Artifak {
  const Artifak({
    required this.isi,
    required this.bahasa,
    required this.jenis,
    required this.judul,
    this.terbuka = false,
  });

  /// Artifak kosong — dipakai saat rute `/artifak` dibuka tanpa data
  /// (mis. setelah app dibuka ulang), supaya layar tidak crash.
  static const Artifak kosong = Artifak(
    isi: '',
    bahasa: '',
    jenis: JenisArtifak.kode,
    judul: 'Artifak',
  );

  final String isi;
  final String bahasa;
  final JenisArtifak jenis;

  /// Judul yang ditampilkan di kartu dan app bar.
  final String judul;

  /// True = blok belum ditutup pagar (masih mengalir).
  final bool terbuka;

  factory Artifak.dari(String isi, String bahasa, {bool terbuka = false}) {
    final String b = bahasa.trim().toLowerCase();
    final JenisArtifak jenis = _kenali(isi, b);
    return Artifak(
      isi: isi,
      bahasa: b,
      jenis: jenis,
      judul: _susunJudul(isi, b, jenis),
      terbuka: terbuka,
    );
  }

  /// Blok yang punya tampilan selain teks mentah.
  bool get bisaPratinjau =>
      jenis != JenisArtifak.kode && isi.trim().isNotEmpty;

  /// Jumlah baris isi — ditampilkan di kartu supaya mata tahu besarnya.
  int get jumlahBaris {
    if (isi.isEmpty) return 0;
    return isi.split('\n').length;
  }

  /// Label pendek jenis isi (`HTML`, `SVG`, `Markdown`, atau nama bahasa).
  String get label {
    switch (jenis) {
      case JenisArtifak.html:
        return 'HTML';
      case JenisArtifak.svg:
        return 'SVG';
      case JenisArtifak.markdown:
        return 'Markdown';
      case JenisArtifak.kode:
        return bahasa.isEmpty ? 'Kode' : bahasa.toUpperCase();
    }
  }

  /// Dokumen HTML utuh untuk WebView.
  ///
  /// - Dokumen yang sudah punya `<html>`/`<!doctype>` dipakai apa adanya:
  ///   penulisnya yang tahu tampilannya.
  /// - Selain itu dibungkus kerangka dokumen berlatang putih, karena
  ///   pratinjau dokumen tidak boleh ikut tema gelap app (teks hitam di atas
  ///   latar gelap = tidak terbaca).
  String dokumenHtml() {
    final String t = isi.trimLeft();
    final String kecil = t.toLowerCase();
    if (kecil.startsWith('<!doctype') || kecil.startsWith('<html')) {
      return isi;
    }
    final String badan = jenis == JenisArtifak.svg
        ? '<div class="kanvas">$isi</div>'
        : isi;
    return '<!doctype html>'
        '<html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<meta name="color-scheme" content="light">'
        '<style>'
        'html,body{margin:0;padding:16px;background:#ffffff;color:#111111;'
        'font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;'
        'font-size:16px;line-height:1.6}'
        'img,svg,video,canvas{max-width:100%;height:auto}'
        'pre{overflow:auto;background:#f5f5f7;padding:12px;border-radius:8px}'
        'table{border-collapse:collapse}'
        'td,th{border:1px solid #dddddd;padding:6px}'
        '.kanvas{display:flex;align-items:center;justify-content:center;'
        'min-height:calc(100vh - 32px)}'
        '</style></head><body>$badan</body></html>';
  }

  static JenisArtifak _kenali(String isi, String bahasa) {
    switch (bahasa) {
      case 'html':
      case 'htm':
      case 'xhtml':
        return JenisArtifak.html;
      case 'svg':
        return JenisArtifak.svg;
      case 'md':
      case 'markdown':
        return JenisArtifak.markdown;
    }
    if (bahasa.isNotEmpty) return JenisArtifak.kode;

    // Pagar tanpa label: kenali dari isi, bukan dari tebakan.
    final String t = isi.trimLeft().toLowerCase();
    if (t.startsWith('<svg')) return JenisArtifak.svg;
    if (t.startsWith('<!doctype html') || t.startsWith('<html')) {
      return JenisArtifak.html;
    }
    return JenisArtifak.kode;
  }

  static String _susunJudul(String isi, String bahasa, JenisArtifak jenis) {
    final String dariDokumen = _judulDokumen(isi);
    if (dariDokumen.isNotEmpty) return dariDokumen;

    final String label = switch (jenis) {
      JenisArtifak.html => 'Dokumen HTML',
      JenisArtifak.svg => 'Gambar SVG',
      JenisArtifak.markdown => 'Dokumen Markdown',
      JenisArtifak.kode => bahasa.isEmpty ? 'Kode' : 'Kode ${bahasa.toUpperCase()}',
    };
    final int baris = isi.isEmpty ? 0 : isi.split('\n').length;
    return baris == 0 ? label : '$label · $baris baris';
  }

  static final RegExp _tagJudul = RegExp(
    r'<title[^>]*>([\s\S]*?)</title>',
    caseSensitive: false,
  );

  static String _judulDokumen(String isi) {
    final Match? m = _tagJudul.firstMatch(isi);
    if (m == null) return '';
    final String j = m.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Judul panjang dipotong: app bar bukan tempat paragraf.
    return j.length <= 60 ? j : '${j.substring(0, 57)}...';
  }
}

/// Pemecah markdown jawaban menjadi [BagianTeks].
abstract final class PemecahJawaban {
  /// Pagar pembuka/penutup: sampai 3 spasi indentasi, minimal 3 backtick
  /// atau tilde, lalu info string.
  static final RegExp _pagar = RegExp(r'^\s{0,3}(`{3,}|~{3,})(.*)$');

  static List<BagianTeks> pecah(String markdown) {
    if (markdown.isEmpty) return const <BagianTeks>[];

    final String sumber =
        markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // Jalan cepat: tanpa pagar sama sekali, jangan sentuh teksnya.
    if (!sumber.contains('```') && !sumber.contains('~~~')) {
      return <BagianTeks>[BagianTeks.teks(markdown)];
    }

    final List<String> baris = sumber.split('\n');
    final List<BagianTeks> hasil = <BagianTeks>[];
    final StringBuffer teks = StringBuffer();
    final StringBuffer kode = StringBuffer();
    String? pagar;
    String bahasa = '';
    bool dalamKode = false;

    void keluarkanTeks() {
      final String isi = teks.toString();
      if (isi.trim().isNotEmpty) hasil.add(BagianTeks.teks(isi));
      teks.clear();
    }

    void keluarkanKode({required bool terbuka}) {
      // Blok kosong (``` diikuti ``` langsung) tidak perlu kartu.
      if (kode.toString().trim().isNotEmpty) {
        hasil.add(BagianTeks.kode(
          isi: kode.toString(),
          bahasa: bahasa,
          terbuka: terbuka,
        ));
      }
      kode.clear();
      bahasa = '';
    }

    for (final String barisIni in baris) {
      final Match? cocok = _pagar.firstMatch(barisIni);
      if (!dalamKode) {
        if (cocok == null) {
          teks.writeln(barisIni);
          continue;
        }
        keluarkanTeks();
        pagar = cocok.group(1)!;
        bahasa = _bahasa(cocok.group(2)!);
        dalamKode = true;
        continue;
      }

      final String? penutup = cocok?.group(1);
      final bool sahPenutup = penutup != null &&
          pagar != null &&
          penutup[0] == pagar[0] &&
          penutup.length >= pagar.length &&
          cocok!.group(2)!.trim().isEmpty;
      if (sahPenutup) {
        keluarkanKode(terbuka: false);
        dalamKode = false;
        pagar = null;
        continue;
      }
      kode.writeln(barisIni);
    }

    if (dalamKode) {
      // Pagar penutup belum datang -> blok masih mengalir.
      keluarkanKode(terbuka: true);
    }
    keluarkanTeks();

    if (hasil.isEmpty) return <BagianTeks>[BagianTeks.teks(markdown)];
    return hasil;
  }

  /// Info string pagar bisa berisi meta (`html title="x"`); ambil kata pertama.
  static String _bahasa(String info) {
    final String bersih = info.trim();
    if (bersih.isEmpty) return '';
    return bersih.split(RegExp(r'[\s{,]+')).first.toLowerCase();
  }
}
