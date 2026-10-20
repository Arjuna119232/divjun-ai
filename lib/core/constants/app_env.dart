/// Nilai yang disuntik saat build lewat `--dart-define`.
///
/// Kenapa `--dart-define` dan bukan baca file `.env` saat runtime:
/// kalau `.env` dibaca runtime, file itu harus jadi aset bundle dan build
/// CRASH kalau lupa. Dengan `--dart-define`, nilai hilang =
/// konfigurasi kosong, bukan crash.
library;

abstract final class AppEnv {
  /// Versi aplikasi, disuntik CI dari `pubspec.yaml`.
  ///
  /// Default-nya sengaja TIDAK ditulis tangan: versi pernah macet di "2.0.0"
  /// padahal APK sudah 2.8.x, jadi layar Pengaturan menampilkan angka yang
  /// salah. CI selalu mengisinya; nilai bawaan hanya untuk `flutter run` lokal.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );
}
