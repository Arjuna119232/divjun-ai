import 'dart:convert';

enum TemaMode { sistem, terang, gelap }

enum ModeAgent { chatting, auto, selalu }

/// Pengaturan aplikasi. Disimpan lokal, dibaca di mana saja lewat Riverpod.
///
/// Tiga hal ini SENGAJA tidak bisa dimatikan dari pengaturan (mulai v3.0.0):
/// [modeAgent], [autoRingkas], dan [pakaiSkillPanduan]. Alasannya ketiganya
/// perilaku inti aplikasi, bukan preferensi pribadi - toggle hanya bikin
/// pengguna mengira AI-nya "memburuk" saat sakelarnya mati, padahal semua
/// fitur ini murah dijalankan. Nilainya dipaksa saat dibaca dan tidak lagi
/// ditulis ke JSON, jadi setelan lama yang pernah bernilai false ikut aktif
/// tanpa perlu migrasi data pengguna.
class SetelanApp {
  const SetelanApp({
    this.modelId = 'openai/gpt-oss-20b',
    this.tema = TemaMode.sistem,
    this.pakaiWarnaDinamis = true,
    this.suhu = 0.7,
    this.ingatMemori = true,
    this.izinkanWeb = true,
    this.izinkanEmail = true,
    this.izinkanKalkulator = true,
    this.namaPengguna = '',
    this.promptSistemTambahan = '',
  });

  final String modelId;
  final TemaMode tema;
  final bool pakaiWarnaDinamis;
  final double suhu;
  final bool ingatMemori;
  final bool izinkanWeb;
  final bool izinkanEmail;
  final bool izinkanKalkulator;
  final String namaPengguna;
  final String promptSistemTambahan;

  /// Selalu [ModeAgent.auto] - lihat catatan kelas.
  ModeAgent get modeAgent => ModeAgent.auto;

  /// Selalu `true` - lihat catatan kelas.
  bool get autoRingkas => true;

  /// Selalu `true` - lihat catatan kelas.
  bool get pakaiSkillPanduan => true;

  bool get agentAktif => true;

  SetelanApp salin({
    String? modelId,
    TemaMode? tema,
    bool? pakaiWarnaDinamis,
    double? suhu,
    bool? ingatMemori,
    bool? izinkanWeb,
    bool? izinkanEmail,
    bool? izinkanKalkulator,
    String? namaPengguna,
    String? promptSistemTambahan,
  }) =>
      SetelanApp(
        modelId: modelId ?? this.modelId,
        tema: tema ?? this.tema,
        pakaiWarnaDinamis: pakaiWarnaDinamis ?? this.pakaiWarnaDinamis,
        suhu: suhu ?? this.suhu,
        ingatMemori: ingatMemori ?? this.ingatMemori,
        izinkanWeb: izinkanWeb ?? this.izinkanWeb,
        izinkanEmail: izinkanEmail ?? this.izinkanEmail,
        izinkanKalkulator: izinkanKalkulator ?? this.izinkanKalkulator,
        namaPengguna: namaPengguna ?? this.namaPengguna,
        promptSistemTambahan:
            promptSistemTambahan ?? this.promptSistemTambahan,
      );

  Map<String, dynamic> keJson() => {
        'modelId': modelId,
        'tema': tema.name,
        'pakaiWarnaDinamis': pakaiWarnaDinamis,
        'suhu': suhu,
        'ingatMemori': ingatMemori,
        'izinkanWeb': izinkanWeb,
        'izinkanEmail': izinkanEmail,
        'izinkanKalkulator': izinkanKalkulator,
        'namaPengguna': namaPengguna,
        'promptSistemTambahan': promptSistemTambahan,
      };

  static SetelanApp dariJson(Map<String, dynamic> j) => SetelanApp(
        modelId: j['modelId'] as String? ?? 'openai/gpt-oss-20b',
        tema: TemaMode.values.firstWhere(
          (TemaMode t) => t.name == j['tema'],
          orElse: () => TemaMode.sistem,
        ),
        pakaiWarnaDinamis: j['pakaiWarnaDinamis'] as bool? ?? true,
        suhu: (j['suhu'] as num?)?.toDouble() ?? 0.7,
        ingatMemori: j['ingatMemori'] as bool? ?? true,
        izinkanWeb: j['izinkanWeb'] as bool? ?? true,
        izinkanEmail: j['izinkanEmail'] as bool? ?? true,
        izinkanKalkulator: j['izinkanKalkulator'] as bool? ?? true,
        namaPengguna: j['namaPengguna'] as String? ?? '',
        promptSistemTambahan: j['promptSistemTambahan'] as String? ?? '',
      );

  static String keJsonTeks(SetelanApp s) => jsonEncode(s.keJson());

  static SetelanApp dariJsonTeks(String? teks) {
    if (teks == null || teks.isEmpty) return const SetelanApp();
    try {
      return SetelanApp.dariJson(jsonDecode(teks) as Map<String, dynamic>);
    } catch (_) {
      return const SetelanApp();
    }
  }
}
