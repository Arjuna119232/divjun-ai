/// Katalog model AI.
///
/// Semua model di sini gratis dan TANPA kunci API (diverifikasi 18 Okt 2026):
/// OVHcloud AI Endpoints + Pollinations. Tidak ada rahasia yang bisa
/// diekstrak dari APK.
library;

enum PenyediaModel {
  /// Gratis, tanpa kunci API sama sekali.
  ovh,
  pollinations,
}

extension PenyediaModelX on PenyediaModel {
  /// Provider ini jalan tanpa kunci API. Untuk APK ini penting: tidak ada
  /// rahasia yang bisa diekstrak dari APK.
  bool get tanpaKunci =>
      this == PenyediaModel.ovh || this == PenyediaModel.pollinations;

  /// Prioritas mencoba: tanpa kunci didahulukan (selalu 0 sekarang).
  int get prioritas => tanpaKunci ? 0 : 10;

  String get namaTampil => switch (this) {
        PenyediaModel.ovh => 'OVH (tanpa kunci)',
        PenyediaModel.pollinations => 'Pollinations (tanpa kunci)',
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

  /// Aman dipakai kunci gratis.
  bool get untukGratis => !perluBayar;

  @override
  bool operator ==(Object other) => other is ModelAi && other.id == id;

  @override
  int get hashCode => id.hashCode;

  static const List<ModelAi> bawaan = <ModelAi>[
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
    // Semua model di katalog ini tanpa kunci, jadi yang paling ringan (first)
    // langsung dipakai — respons paling cepat.
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
