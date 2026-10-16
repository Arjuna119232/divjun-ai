/// Katalog model AI.
///
/// PENTING (hasil audit 17 Okt 2026 terhadap docs resmi Groq): beberapa model
/// yang dulu gratis sekarang **khusus paket Enterprise** - misalnya
/// `llama-3.3-70b-versatile` dan `llama-3.1-8b-instant` (keduanya "ContactSales").
/// Kalau katalog bawaan menunjuk model seperti itu, SEMUA permintaan dari kunci
/// gratis akan ditolak dan userума "semua model gagal". Jadi model Enterprise
/// ditandai [perluBayar] dan TIDAK dipakai sebagai default / pilihan otomatis.
library;

enum PenyediaModel { groq, gemini }

class ModelAi {
  const ModelAi({
    required this.id,
    required this.label,
    required this.penyedia,
    this.dukungAlat = false,
    this.lihatGambar = false,
    this.konteks = 8192,
    this.perluBayar = false,
  });

  final String id;
  final String label;
  final PenyediaModel penyedia;
  final bool dukungAlat;
  final bool lihatGambar;
  final int konteks;

  /// True = hanya tersedia di paket berbayar (Enterprise) di provider aslinya.
  final bool perluBayar;

  String get labelLengkap => '$label · ${penyedia.name}';

  /// Aman dipakai kunci gratis.
  bool get untukGratis => !perluBayar;

  @override
  bool operator ==(Object o) => o is ModelAi && o.id == id;

  @override
  int get hashCode => id.hashCode;

  static const List<ModelAi> bawaan = <ModelAi>[
    // --- Groq: yang dipakai kunci gratis (docs Groq, Okt 2026) ---
    ModelAi(
      id: 'openai/gpt-oss-20b',
      label: 'GPT-OSS 20B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'openai/gpt-oss-120b',
      label: 'GPT-OSS 120B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'qwen/qwen3.8-27b',
      label: 'Qwen3.8 27B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 131072,
    ),
    // --- Groq: Enterprise, disembunyikan dari pilihan otomatis ---
    ModelAi(
      id: 'llama-3.3-70b-versatile',
      label: 'Llama 3.3 70B (Enterprise)',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 131072,
      perluBayar: true,
    ),
    ModelAi(
      id: 'llama-3.1-8b-instant',
      label: 'Llama 3.1 8B (Enterprise)',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 131072,
      perluBayar: true,
    ),
    // --- Gemini (butuh kunci gratis dari AI Studio) ---
    ModelAi(
      id: 'gemini-2.5-flash',
      label: 'Gemini 2.5 Flash',
      penyedia: PenyediaModel.gemini,
      lihatGambar: true,
      konteks: 1000000,
    ),
    ModelAi(
      id: 'gemini-2.0-flash',
      label: 'Gemini 2.0 Flash',
      penyedia: PenyediaModel.gemini,
      lihatGambar: true,
      konteks: 1000000,
    ),
  ];

  /// Model yang mendukung tool calling (syarat agent mode aktif).
  static List<ModelAi> yangDukungAlat([List<ModelAi>? semua]) =>
      (semua ?? bawaan).where((ModelAi m) => m.dukungAlat).toList();

  /// Dipakai untuk otomatis memilih: tool calling dulu, baru kunci gratis.
  static List<ModelAi> layakOtomatis([List<ModelAi>? semua]) =>
      (semua ?? bawaan)
          .where((ModelAi m) => m.dukungAlat && m.untukGratis)
          .toList();

  static ModelAi? cari(String id, [List<ModelAi>? semua]) {
    for (final ModelAi m in semua ?? bawaan) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Default untuk kunci gratis: paling ringan dulu (respons cepat).
  static ModelAi defaultGratis([List<ModelAi>? semua]) {
    final List<ModelAi> layak = layakOtomatis(semua);
    if (layak.isEmpty) return bawaan.first;
    for (final ModelAi m in layak) {
      if (m.id == 'openai/gpt-oss-20b') return m;
    }
    return layak.first;
  }

  /// Urutan cadangan ketika model/model sebelumnya ditolak provider.
  static List<ModelAi> cadangan(ModelAi sekarang, [List<ModelAi>? semua]) {
    final List<ModelAi> layak = layakOtomatis(semua);
    final List<ModelAi> urut = <ModelAi>[];
    for (final ModelAi m in layak) {
      if (m.id != sekarang.id) urut.add(m);
    }
    return urut;
  }
}
