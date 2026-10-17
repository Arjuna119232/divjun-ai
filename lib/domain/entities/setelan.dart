import 'dart:convert';

enum TemaMode { sistem, terang, gelap }

enum ModeAgent { chatting, auto, selalu }

/// Pengaturan aplikasi. Disimpan lokal, dibaca di mana saja lewat Riverpod.
class SetelanApp {
  const SetelanApp({
    this.modelId = 'openai/gpt-oss-120b',
    this.tema = TemaMode.sistem,
    this.pakaiWarnaDinamis = true,
    this.modeAgent = ModeAgent.auto,
    this.suhu = 0.7,
    this.ingatMemori = true,
    this.izinkanWeb = true,
    this.izinkanEmail = true,
    this.izinkanKalkulator = true,
    this.autoRingkas = true,
    this.pakaiSkillPanduan = true,
    this.namaPengguna = '',
    this.promptSistemTambahan = '',
    this.kunciGroq = '',
    this.kunciGemini = '',
    this.kunciOpenRouter = '',
  });

  final String modelId;
  final TemaMode tema;
  final bool pakaiWarnaDinamis;
  final ModeAgent modeAgent;
  final double suhu;
  final bool ingatMemori;
  final bool izinkanWeb;
  final bool izinkanEmail;
  final bool izinkanKalkulator;
  final bool autoRingkas;
  final bool pakaiSkillPanduan;
  final String namaPengguna;
  final String promptSistemTambahan;

  /// Kunci API yang diisi user di aplikasi (menimpa kunci yang dibundel).
  /// Dikosongkan = pakai kunci bawaan saat build.
  final String kunciGroq;
  final String kunciGemini;

  /// Kunci OpenRouter (opsional - model gratis ':free' tetap butuh kunci).
  final String kunciOpenRouter;

  bool get agentAktif => modeAgent != ModeAgent.chatting;

  SetelanApp salin({
    String? modelId,
    TemaMode? tema,
    bool? pakaiWarnaDinamis,
    ModeAgent? modeAgent,
    double? suhu,
    bool? ingatMemori,
    bool? izinkanWeb,
    bool? izinkanEmail,
    bool? izinkanKalkulator,
    bool? autoRingkas,
    bool? pakaiSkillPanduan,
    String? namaPengguna,
    String? promptSistemTambahan,
    String? kunciGroq,
    String? kunciGemini,
    String? kunciOpenRouter,
  }) =>
      SetelanApp(
        modelId: modelId ?? this.modelId,
        tema: tema ?? this.tema,
        pakaiWarnaDinamis: pakaiWarnaDinamis ?? this.pakaiWarnaDinamis,
        modeAgent: modeAgent ?? this.modeAgent,
        suhu: suhu ?? this.suhu,
        ingatMemori: ingatMemori ?? this.ingatMemori,
        izinkanWeb: izinkanWeb ?? this.izinkanWeb,
        izinkanEmail: izinkanEmail ?? this.izinkanEmail,
        izinkanKalkulator: izinkanKalkulator ?? this.izinkanKalkulator,
        autoRingkas: autoRingkas ?? this.autoRingkas,
        pakaiSkillPanduan: pakaiSkillPanduan ?? this.pakaiSkillPanduan,
        namaPengguna: namaPengguna ?? this.namaPengguna,
        promptSistemTambahan:
            promptSistemTambahan ?? this.promptSistemTambahan,
        kunciGroq: kunciGroq ?? this.kunciGroq,
        kunciGemini: kunciGemini ?? this.kunciGemini,
        kunciOpenRouter: kunciOpenRouter ?? this.kunciOpenRouter,
      );

  Map<String, dynamic> keJson() => {
        'modelId': modelId,
        'tema': tema.name,
        'pakaiWarnaDinamis': pakaiWarnaDinamis,
        'modeAgent': modeAgent.name,
        'suhu': suhu,
        'ingatMemori': ingatMemori,
        'izinkanWeb': izinkanWeb,
        'izinkanEmail': izinkanEmail,
        'izinkanKalkulator': izinkanKalkulator,
        'autoRingkas': autoRingkas,
        'pakaiSkillPanduan': pakaiSkillPanduan,
        'namaPengguna': namaPengguna,
        'promptSistemTambahan': promptSistemTambahan,
        'kunciGroq': kunciGroq,
        'kunciGemini': kunciGemini,
        'kunciOpenRouter': kunciOpenRouter,
      };

  static SetelanApp dariJson(Map<String, dynamic> j) => SetelanApp(
        modelId: j['modelId'] as String? ?? 'openai/gpt-oss-120b',
        tema: TemaMode.values.firstWhere(
          (TemaMode t) => t.name == j['tema'],
          orElse: () => TemaMode.sistem,
        ),
        pakaiWarnaDinamis: j['pakaiWarnaDinamis'] as bool? ?? true,
        modeAgent: ModeAgent.values.firstWhere(
          (ModeAgent m) => m.name == j['modeAgent'],
          orElse: () => ModeAgent.auto,
        ),
        suhu: (j['suhu'] as num?)?.toDouble() ?? 0.7,
        ingatMemori: j['ingatMemori'] as bool? ?? true,
        izinkanWeb: j['izinkanWeb'] as bool? ?? true,
        izinkanEmail: j['izinkanEmail'] as bool? ?? true,
        izinkanKalkulator: j['izinkanKalkulator'] as bool? ?? true,
        autoRingkas: j['autoRingkas'] as bool? ?? true,
        pakaiSkillPanduan: j['pakaiSkillPanduan'] as bool? ?? true,
        namaPengguna: j['namaPengguna'] as String? ?? '',
        promptSistemTambahan: j['promptSistemTambahan'] as String? ?? '',
        kunciGroq: j['kunciGroq'] as String? ?? '',
        kunciGemini: j['kunciGemini'] as String? ?? '',
        kunciOpenRouter: j['kunciOpenRouter'] as String? ?? '',
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
