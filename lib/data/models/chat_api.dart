import 'dart:convert';

/// Model untuk layer data: bentuk request & bentuk response provider.
/// Entity app (Pesan, dsb) TIDAK ikut ke sini supaya tidak bercampur.
/// Definisi satu tool yang dikirim ke LLM sebagai native function calling.
class ToolSpec {
  const ToolSpec({
    required this.nama,
    required this.deskripsi,
    required this.parameter,
  });

  final String nama;
  final String deskripsi;
  final Map<String, dynamic> parameter;

  Map<String, dynamic> keJson() => {
        'type': 'function',
        'function': {
          'name': nama,
          'description': deskripsi,
          'parameters': parameter,
        },
      };
}

/// Satu request tool call dari model.
class PanggilanAlat {
  const PanggilanAlat({
    required this.id,
    required this.nama,
    required this.argumen,
    this.kesalahan = '',
  });

  final String id;
  final String nama;
  final String argumen;
  final String kesalahan;

  bool get sah => kesalahan.isEmpty;

  Map<String, dynamic> argumenMap() {
    if (argumen.trim().isEmpty) return <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(argumen);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // argumen rusak -> dikembalikan kosong, bukan crash
    }
    return <String, dynamic>{};
  }

  static PanggilanAlat dariJson(Map<String, dynamic> j) {
    final Map<String, dynamic> fn =
        (j['function'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String raw = fn['arguments'] as String? ?? '{}';
    String galat = '';
    Map<String, dynamic> cek = <String, dynamic>{};
    try {
      final Object? decoded = jsonDecode(raw.isEmpty ? '{}' : raw);
      if (decoded is Map<String, dynamic>) {
        cek = decoded;
      } else {
        galat = 'Argumen tool bukan objek JSON.';
      }
    } catch (_) {
      galat = 'Argumen tool bukan JSON yang valid.';
    }
    return PanggilanAlat(
      id: j['id'] as String? ?? j['name'] as String? ?? '',
      nama: fn['name'] as String? ?? j['name'] as String? ?? 'unknown',
      argumen: raw,
      kesalahan: cek.isEmpty && raw.trim().isNotEmpty && galat.isEmpty
          ? 'Argumen tool kosong.'
          : galat,
    );
  }
}

/// Satu potongan dari stream (delta token atau tool call).
class PotonganBalasan {
  const PotonganBalasan({
    this.teks = '',
    this.alat = const <PanggilanAlat>[],
    this.selesai = false,
    this.alasanBerhenti = '',
    this.galat = '',
  });

  final String teks;
  final List<PanggilanAlat> alat;
  final bool selesai;
  final String alasanBerhenti;
  final String galat;

  bool get tanpaIsi => teks.isEmpty && alat.isEmpty && !selesai && galat.isEmpty;
}

/// Hasil satu putaran chat (non-streaming atau sudah dirangkum).
class HasilBalasan {
  const HasilBalasan({
    required this.teks,
    this.alat = const <PanggilanAlat>[],
    this.galat = '',
    this.alasanBerhenti = '',
    this.usage = 0,
  });

  final String teks;
  final List<PanggilanAlat> alat;
  final String galat;
  final String alasanBerhenti;
  final int usage;

  bool get gagal => galat.isNotEmpty;
}
