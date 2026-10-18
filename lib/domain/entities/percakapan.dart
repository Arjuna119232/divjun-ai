enum Peran { pengguna, ai, sistem, alat }

enum StatusPesan { antre, mengalir, selesai, gagal, dibatalkan }

enum StatusAlat { berjalan, selesai, gagal }

class CatatanAlat {
  const CatatanAlat({
    required this.nama,
    required this.argumen,
    required this.hasil,
    required this.status,
    required this.waktu,
    this.ringkasan = '',
  });

  final String nama;
  final String argumen;
  final String hasil;
  final StatusAlat status;
  final DateTime waktu;
  final String ringkasan;

  CatatanAlat salin({
    String? hasil,
    StatusAlat? status,
    String? ringkasan,
  }) =>
      CatatanAlat(
        nama: nama,
        argumen: argumen,
        hasil: hasil ?? this.hasil,
        status: status ?? this.status,
        waktu: waktu,
        ringkasan: ringkasan ?? this.ringkasan,
      );

  Map<String, dynamic> keJson() => {
        'nama': nama,
        'argumen': argumen,
        'hasil': hasil,
        'status': status.name,
        'waktu': waktu.toIso8601String(),
        'ringkasan': ringkasan,
      };

  static CatatanAlat dariJson(Map<String, dynamic> j) => CatatanAlat(
        nama: j['nama'] as String? ?? 'alat',
        argumen: j['argumen'] as String? ?? '',
        hasil: j['hasil'] as String? ?? '',
        status: StatusAlat.values.firstWhere(
          (StatusAlat s) => s.name == j['status'],
          orElse: () => StatusAlat.selesai,
        ),
        waktu: DateTime.tryParse(j['waktu'] as String? ?? '') ?? DateTime.now(),
        ringkasan: j['ringkasan'] as String? ?? '',
      );
}

class Pesan {
  const Pesan({
    required this.id,
    required this.peran,
    required this.isi,
    required this.waktu,
    this.status = StatusPesan.selesai,
    this.modelId = '',
    this.catatanAlat = const <CatatanAlat>[],
    this.pesanGalat = '',
    this.percobaan = 0,
    this.penalaran = '',
    this.penalaranMs = 0,
  });

  final String id;
  final Peran peran;
  final String isi;
  final DateTime waktu;
  final StatusPesan status;
  final String modelId;
  final List<CatatanAlat> catatanAlat;
  final String pesanGalat;

  /// Berapa kali pesan ini dicoba ulang (regenerate / retry).
  final int percobaan;

  /// Isi "berpikir" model (reasoning). Dipisah dari [isi] supaya bisa
  /// ditampilkan sebagai blok yang bisa dibuka-tutup, dan TIDAK ikut
  /// dikirim balik ke model sebagai bagian jawaban.
  final String penalaran;

  /// Berapa milidetik model berpikir. 0 = tidak ada penalaran.
  final int penalaranMs;

  bool get dariPengguna => peran == Peran.pengguna;
  bool get dariAi => peran == Peran.ai;
  bool get sedangMengalir => status == StatusPesan.mengalir;
  bool get punyaPenalaran => penalaran.trim().isNotEmpty;

  Pesan salin({
    String? isi,
    StatusPesan? status,
    List<CatatanAlat>? catatanAlat,
    String? pesanGalat,
    int? percobaan,
    String? modelId,
    String? penalaran,
    int? penalaranMs,
  }) =>
      Pesan(
        id: id,
        peran: peran,
        isi: isi ?? this.isi,
        waktu: waktu,
        status: status ?? this.status,
        modelId: modelId ?? this.modelId,
        catatanAlat: catatanAlat ?? this.catatanAlat,
        pesanGalat: pesanGalat ?? this.pesanGalat,
        percobaan: percobaan ?? this.percobaan,
        penalaran: penalaran ?? this.penalaran,
        penalaranMs: penalaranMs ?? this.penalaranMs,
      );

  Map<String, dynamic> keJson() => {
        'id': id,
        'peran': peran.name,
        'isi': isi,
        'waktu': waktu.toIso8601String(),
        'status': status.name,
        'modelId': modelId,
        'catatanAlat': catatanAlat.map((CatatanAlat c) => c.keJson()).toList(),
        'pesanGalat': pesanGalat,
        'percobaan': percobaan,
        'penalaran': penalaran,
        'penalaranMs': penalaranMs,
      };

  static Pesan dariJson(Map<String, dynamic> j) => Pesan(
        id: j['id'] as String? ?? '',
        peran: Peran.values.firstWhere(
          (Peran p) => p.name == j['peran'],
          orElse: () => Peran.ai,
        ),
        isi: j['isi'] as String? ?? '',
        waktu: DateTime.tryParse(j['waktu'] as String? ?? '') ?? DateTime.now(),
        status: StatusPesan.values.firstWhere(
          (StatusPesan s) => s.name == j['status'],
          orElse: () => StatusPesan.selesai,
        ),
        modelId: j['modelId'] as String? ?? '',
        catatanAlat: (j['catatanAlat'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(CatatanAlat.dariJson)
            .toList(),
        pesanGalat: j['pesanGalat'] as String? ?? '',
        percobaan: (j['percobaan'] as num?)?.toInt() ?? 0,
        penalaran: j['penalaran'] as String? ?? '',
        penalaranMs: (j['penalaranMs'] as num?)?.toInt() ?? 0,
      );
}

class Percakapan {
  Percakapan({
    required this.id,
    required this.judul,
    required this.dibuat,
    required this.diperbarui,
    this.pesan = const <Pesan>[],
  });

  final String id;
  String judul;
  final DateTime dibuat;
  DateTime diperbarui;
  List<Pesan> pesan;

  bool get kosong => pesan.isEmpty;

  Pesan? get terakhir => pesan.isEmpty ? null : pesan.last;

  Map<String, dynamic> keJson() => {
        'id': id,
        'judul': judul,
        'dibuat': dibuat.toIso8601String(),
        'diperbarui': diperbarui.toIso8601String(),
        'pesan': pesan.map((Pesan p) => p.keJson()).toList(),
      };

  static Percakapan dariJson(Map<String, dynamic> j) => Percakapan(
        id: j['id'] as String? ?? '',
        judul: j['judul'] as String? ?? 'Percakapan',
        dibuat: DateTime.tryParse(j['dibuat'] as String? ?? '') ?? DateTime.now(),
        diperbarui:
            DateTime.tryParse(j['diperbarui'] as String? ?? '') ?? DateTime.now(),
        pesan: (j['pesan'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Pesan.dariJson)
            .toList(),
      );
}

