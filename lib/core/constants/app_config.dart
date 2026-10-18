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

  // Intro: splash + durasi per halaman onboarding.
  // 4 detik per halaman, BUKAN 4 detik total: tiga halaman berisi teks,
  // 1,3 detik per halaman tidak terbaca. Countdown-nya tampil sebagai garis
  // tipis di atas konten supaya auto-lanjut tidak terasa mencuri waktu baca.
  // konten supaya auto-lanjut tidak terasa mencuri waktu baca.
  static const int durasiSplashMs = 4000;
  static const int durasiHalamanOnboardingMs = 4000;

  // Kunci penyimpanan lokal
  static const String kPengaturan = 'divjun.pengaturan.v2';
  static const String kRiwayat = 'divjun.riwayat.v2';
  static const String kMemori = 'divjun.memori.v2';

  static const String versi = '2.0.0';
}
