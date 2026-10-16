/// Utilitas teks: bersih-bersih HTML dari hasil web, ringkas, dan
/// pemenggalan aman untuk tampilan.
library;

abstract final class Teks {
  static const Map<String, String> _entitas = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&mdash;': '-',
    '&ndash;': '-',
    '&hellip;': '...',
  };

  /// Ubah HTML halaman web jadi teks polos yang enak dibaca model.
  static String htmlKeTeks(String html) {
    String s = html;
    s = s.replaceAll(RegExp(
        r'<(script|style|noscript|svg|head)[^>]*>.*?</\1>',
        caseSensitive: false,
        dotAll: true,
      ),
        ' ');
    s = s.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ');
    s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'</(p|div|li|h[1-6]|tr|section)>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    for (final MapEntry<String, String> e in _entitas.entries) {
      s = s.replaceAll(e.key, e.value);
    }
    s = s.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (Match m) => String.fromCharCode(int.tryParse(m.group(1) ?? '32') ?? 32),
    );
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    return s.trim();
  }

  /// Judul halaman dari <title> atau og:title.
  static String judulHalaman(String html) {
    final RegExpMatch? t =
        RegExp(
            r'<title[^>]*>(.*?)</title>',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(html);
    final String isi = t?.group(1)?.trim() ?? '';
    if (isi.isEmpty) {
      final RegExpMatch? og = RegExp(
          r'<meta[^>]+property="og:title"[^>]+content="([^"]+)"',
          caseSensitive: false,
          dotAll: true,
        )
          .firstMatch(html);
      return og?.group(1)?.trim() ?? '';
    }
    return Teks.bersihSpasi(isi);
  }

  static String bersihSpasi(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String potong(String s, int maks, {String akhir = '…'}) {
    if (s.length <= maks) return s;
    return '${s.substring(0, maks).trimRight()}$akhir';
  }

  /// Ringkas di batas kata supaya tidak memotong di tengah kalimat.
  static String ringkas(String s, int maks) {
    if (s.length <= maks) return s;
    final int potong = s.lastIndexOf(' ', maks);
    return '${s.substring(0, potong < 0 ? maks : potong).trimRight()}…';
  }

  /// Estimasi kasar jumlah token (sekitar 4 karakter = 1 token).
  /// Cukup untuk menentukan kapan riwayat perlu diringkas.
  static int perkiraanToken(String s) => (s.length / 4).ceil();

  static String normalisasi(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<String> kata(String s) {
    final List<String> k = normalisasi(s).split(' ');
    return k.where((String e) => e.length > 2).toList();
  }

  /// Judul pendek dari pesan pertama (untuk daftar riwayat).
  static String judulPercakapan(String pesanPertama, {int maks = 42}) {
    final String s = pesanPertama.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return 'Percakapan baru';
    return potong(s, maks);
  }

  /// Ambil nama domain untuk ditampilkan ringkas.
  static String host(String url) {
    final Uri? u = Uri.tryParse(url);
    return (u == null || u.host.isEmpty) ? url : u.host;
  }
}
