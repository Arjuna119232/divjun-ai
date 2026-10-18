/// Katalog model AI.
///
/// PENTING (hasil audit 17 Okt 2026 terhadap docs resmi Groq): beberapa model
/// yang dulu gratis sekarang **khusus paket Enterprise** - misalnya
/// `llama-3.3-70b-versatile` dan `llama-3.1-8b-instant` (keduanya "ContactSales").
/// Kalau katalog bawaan menunjuk model seperti itu, SEMUA permintaan dari kunci
/// gratis akan ditolak dan userума "semua model gagal". Jadi model Enterprise
/// ditandai [perluBayar] dan TIDAK dipakai sebagai default / pilihan otomatis.
library;

enum PenyediaModel {
  /// Gratis, tanpa kunci API sama sekali (diverifikasi 18 Okt 2026).
  ovh,
  pollinations,
  groq,
  gemini,
  openrouter,
}

extension PenyediaModelX on PenyediaModel {
  /// Provider ini jalan tanpa kunci API. Untuk APK ini penting: tidak ada
  /// rahasia yang bisa diekstrak dari APK.
  bool get tanpaKunci =>
      this == PenyediaModel.ovh || this == PenyediaModel.pollinations;

  /// Prioritas mencoba: tanpa kunci didahulukan.
  int get prioritas => tanpaKunci ? 0 : 10;

  String get namaTampil => switch (this) {
        PenyediaModel.ovh => 'OVH (tanpa kunci)',
        PenyediaModel.pollinations => 'Pollinations (tanpa kunci)',
        PenyediaModel.groq => 'Groq',
        PenyediaModel.gemini => 'Gemini',
        PenyediaModel.openrouter => 'OpenRouter',
      };
}

class ModelAi {
  const ModelAi({
    required this.id,
    required this.label,
    required this.penyedia,
    this.dukungAlat = false,
    this.lihatGambar = false,
    this.konteks = 8192,
    this.perluBayar = false,
    this.dukungGambarMasuk = false,
  });

  final String id;
  final String label;
  final PenyediaModel penyedia;
  final bool dukungAlat;
  final bool lihatGambar;
  final int konteks;

  /// True = hanya tersedia di paket berbayar (Enterprise) di provider aslinya.
  final bool perluBayar;

  /// Menerima gambar sebagai bagian dari pesan.
  final bool dukungGambarMasuk;

  String get labelLengkap => '$label · ${penyedia.namaTampil}';

  /// Butuh kunci API yang sudah diisi sebelum model ini bisa dipakai.
  bool get perluKunci => !penyedia.tanpaKunci;

  /// Aman dipakai kunci gratis.
  bool get untukGratis => !perluBayar;

  @override
  bool operator ==(Object other) => other is ModelAi && other.id == id;

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
    // --- OVHcloud AI Endpoints: GRATIS, TANPA KUNCI (18 Okt 2026, live) ---
    ModelAi(
      id: 'gpt-oss-120b',
      label: 'GPT-OSS 120B (OVH)',
      penyedia: PenyediaModel.ovh,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'gpt-oss-20b',
      label: 'GPT-OSS 20B (OVH)',
      penyedia: PenyediaModel.ovh,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'Qwen3.8-27B',
      label: 'Qwen3.8 27B (OVH)',
      penyedia: PenyediaModel.ovh,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'Qwen3.6-27B',
      label: 'Qwen3.6 27B (OVH)',
      penyedia: PenyediaModel.ovh,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'Qwen3.5-397B-A17B',
      label: 'Qwen3.5 397B (OVH)',
      penyedia: PenyediaModel.ovh,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'Mistral-Small-3.2-24B-Instruct-2506',
      label: 'Mistral Small 3.2 24B (OVH)',
      penyedia: PenyediaModel.ovh,
      dukungAlat: true,
      konteks: 131072,
    ),
    ModelAi(
      id: 'Meta-Llama-3_3-70B-Instruct',
      label: 'Llama 3.3 70B (OVH)',
      penyedia: PenyediaModel.ovh,
      dukungAlat: true,
      konteks: 131072,
    ),
    // --- Pollinations: GRATIS, TANPA KUNCI, tool calling + SSE (live) ---
    ModelAi(
      id: 'openai-fast',
      label: 'Pollinations Fast',
      penyedia: PenyediaModel.pollinations,
      dukungAlat: true,
      konteks: 131072,
    ),
    // --- OpenRouter: 16 model ':free', 15 punya tool calling (live) ---
    ModelAi(
      id: 'nvidia/nemotron-3-ultra-550b-a55b:free',
      label: 'Nemotron 3 Ultra 550B',
      penyedia: PenyediaModel.openrouter,
      dukungAlat: true,
      konteks: 1000000,
    ),
    ModelAi(
      id: 'thinkingmachines/inkling:free',
      label: 'Inkling',
      penyedia: PenyediaModel.openrouter,
      dukungAlat: true,
      konteks: 1000000,
    ),
    ModelAi(
      id: 'nvidia/nemotron-3.5-lightning:free',
      label: 'Nemotron 3.5 Lightning',
      penyedia: PenyediaModel.openrouter,
      dukungAlat: true,
      konteks: 1000000,
    ),
    ModelAi(
      id: 'google/gemma-4-31b-it:free',
      label: 'Gemma 4 31B',
      penyedia: PenyediaModel.openrouter,
      dukungAlat: true,
      lihatGambar: true,
      konteks: 262144,
    ),
    ModelAi(
      id: 'cohere/north-mini-code:free',
      label: 'North Mini Code',
      penyedia: PenyediaModel.openrouter,
      dukungAlat: true,
      konteks: 256000,
    ),
    ModelAi(
      id: 'nvidia/nemotron-3-super-120b-a12b:free',
      label: 'Nemotron 3 Super 120B',
      penyedia: PenyediaModel.openrouter,
      dukungAlat: true,
      konteks: 262144,
    ),
    // --- Gemini (butuh kunci gratis dari AI Studio) ---
    ModelAi(
      id: 'gemini-3.8-flash',
      label: 'Gemini 3.8 Flash',
      penyedia: PenyediaModel.gemini,
      lihatGambar: true,
      konteks: 1000000,
    ),
    ModelAi(
      id: 'gemini-3.5-flash-lite',
      label: 'Gemini 3.5 Flash Lite',
      penyedia: PenyediaModel.gemini,
      lihatGambar: true,
      konteks: 1000000,
    ),
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
  static List<ModelAi> layakOtomatis([List<ModelAi>? semua]) {
    final List<ModelAi> hasil = (semua ?? bawaan)
        .where((ModelAi m) => m.dukungAlat && m.untukGratis)
        .toList();
    hasil.sort((ModelAi a, ModelAi b) {
      final int p = a.penyedia.prioritas.compareTo(b.penyedia.prioritas);
      if (p != 0) return p;
      return a.label.compareTo(b.label);
    });
    return hasil;
  }

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
    // Prioritas: provider tanpa kunci (langsung jalan), lalu yang paling
    // ringan (respons cepat).
    for (final ModelAi m in layak) {
      if (!m.perluKunci) return m;
    }
    for (final ModelAi m in layak) {
      if (m.id == 'openai/gpt-oss-20b') return m;
    }
    return layak.first;
  }

  /// Urutan cadangan ketika model/model sebelumnya ditolak provider.
  static List<ModelAi> cadangan(ModelAi sekarang, [List<ModelAi>? semua]) {
    final List<ModelAi> layak = layakOtomatis(semua);
    return <ModelAi>[
      for (final ModelAi m in layak)
        if (m.id != sekarang.id) m,
    ];
  }
}
