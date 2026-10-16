/// Konstanta aplikasi: identitas, endpoint, dan batas agent loop.
abstract final class AppConfig {
  static const String appName = 'DIVJUN AI';
  static const String appTagline = 'Chatbot + Agent AI native';
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';

  // Batas agent loop
  static const int maksLangkahAgent = 6;
  static const int maksPanggilanToolSama = 1;
  static const int batasToolPerLangkah = 4;

  // Manajemen konteks (estimasi kasar: 1 token ~ 4 karakter)
  static const int ambangRingkas = 6000; // karakter -> mulai ringkas
  static const int maksKarakterBalasan = 24000;

  // Batas tool web
  static const int maksHurufWeb = 6000;
  static const int timeoutWebDetik = 12;

  // Kunci penyimpanan lokal
  static const String kPengaturan = 'divjun.pengaturan.v2';
  static const String kRiwayat = 'divjun.riwayat.v2';
  static const String kMemori = 'divjun.memori.v2';

  static const String versi = '2.0.0';
}
