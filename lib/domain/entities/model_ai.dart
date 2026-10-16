import 'dart:convert';

/// Katalog model AI.
///
/// Model diambil dari provider saat runtime (lihat `data/datasources/katalog_model.dart`),
/// daftar di bawah = bawaan + cadangan kalau fetch gagal / offline.
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
  });

  final String id;
  final String label;
  final PenyediaModel penyedia;
  final bool dukungAlat;
  final bool lihatGambar;
  final int konteks;

  String get labelLengkap => '$label · ${penyedia.name}';

  @override
  bool operator ==(Object o) => o is ModelAi && o.id == id;

  @override
  int get hashCode => id.hashCode;

  static const List<ModelAi> bawaan = [
    ModelAi(
      id: 'llama-3.3-70b-versatile',
      label: 'Llama 3.3 70B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 128000,
    ),
    ModelAi(
      id: 'openai/gpt-oss-120b',
      label: 'GPT-OSS 120B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 128000,
    ),
    ModelAi(
      id: 'openai/gpt-oss-20b',
      label: 'GPT-OSS 20B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 128000,
    ),
    ModelAi(
      id: 'llama-3.1-8b-instant',
      label: 'Llama 3.1 8B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 128000,
    ),
    ModelAi(
      id: 'qwen/qwen3-32b',
      label: 'Qwen3 32B',
      penyedia: PenyediaModel.groq,
      dukungAlat: true,
      konteks: 32768,
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

  static ModelAi? cari(String id, [List<ModelAi>? semua]) {
    for (final ModelAi m in semua ?? bawaan) {
      if (m.id == id) return m;
    }
    return null;
  }

  static ModelAi defaultGroq = bawaan.first;

  /// Model stok dari daftar bawaan - dipakai saat app dibuka supaya user
  /// bisa mencicipi kemampuan model yang berbeda.
  static ModelAi stokDari(int seed) => bawaan[seed.abs() % bawaan.length];
}
