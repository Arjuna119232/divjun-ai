/// Nilai yang disuntik saat build lewat `--dart-define`.
///
/// Kenapa `--dart-define` dan bukan baca file `.env` saat runtime:
/// kalau `.env` dibaca runtime, file itu harus jadi aset bundle dan build
/// CRASH kalau lupa. Dengan `--dart-define`, kunci hilang = konfigurasi kosong
/// (jatuh ke mode lokal / tampilkan status jujur), bukan crash.
library;

abstract final class AppEnv {
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY');
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '2.0.0',
  );

  static bool get punyaGroq => groqApiKey.trim().isNotEmpty;
  static bool get punyaGemini => geminiApiKey.trim().isNotEmpty;
  static bool get punyaOpenRouter => openRouterApiKey.trim().isNotEmpty;
  static bool get punyaApiKey => punyaGroq || punyaGemini;

  /// Mode demo = tidak ada jalur AI sama sekali. OVH + Pollinations jalan
  /// tanpa kunci, jadi aplikasi tetap punya model gratis walau semua kunci
  /// kosong - banner "demo" tidak boleh muncul hanya karena kunci kosong.
  static bool get modeDemo => !punyaApiKey;
}
