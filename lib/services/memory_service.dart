import '../core/constants/app_config.dart';
import '../data/datasources/klien_llm.dart';
import '../domain/entities/memori.dart';
import '../domain/entities/percakapan.dart';

/// Layanan memori: menyuntikkan memori jangka panjang ke system prompt dan
/// merangkum riwayat kalau sudah terlalu panjang.
class MemoryService {
  const MemoryService();

  /// Bangun system prompt + blok memori.
  ///
  /// [namaPengguna] boleh kosong. [memori] = hasil pencarian memori lokal.
  String systemPrompt({
    required String namaPengguna,
    required bool agentAktif,
    required String promptTambahan,
    List<EntriMemori> memori = const <EntriMemori>[],
    bool bisaWeb = true,
  }) {
    final StringBuffer b = StringBuffer();
    b.writeln('Kamu DIVJUN AI, asisten pribadi berbahasa Indonesia.');
    b.writeln('Gaya: singkat, jelas, Bahasa Indonesia baku, tanpa basa-basi panjang.');
    if (namaPengguna.trim().isNotEmpty) {
      b.writeln('Nama user: ${namaPengguna.trim()}.');
    }
    if (agentAktif) {
      b.writeln(
        'Kamu punya akses tool. Kalau jawabannya butuh perhitungan, data '
        'waktu, atau isi halaman web, PAKAI tool - jangan menebak angka.',
      );
      if (bisaWeb) {
        b.writeln('Kalau tidak tahu, boleh buka satu URL untuk mengecek.');
      }
      b.writeln(
        'Kalau tool gagal, katakan apa adanya ke user. Jangan mengarang hasil.',
      );
    }
    if (memori.isNotEmpty) {
      b.writeln();
      b.writeln('Memori jangka panjang user (dari sebelumnya):');
      for (final EntriMemori e in memori.take(8)) {
        b.writeln('- [${KategoriMemori.label(e.kategori)}] ${e.isi}');
      }
    }
    if (promptTambahan.trim().isNotEmpty) {
      b.writeln();
      b.writeln('Instruksi tambahan user: ${promptTambahan.trim()}');
    }
    return b.toString().trim();
  }

  /// Perkiraan karakter riwayat (1 token ~ 4 karakter).
  int ukuranRiwayat(List<Pesan> pesan) {
    int total = 0;
    for (final Pesan p in pesan) {
      total += p.isi.length;
    }
    return total;
  }

  bool perluRingkas(List<Pesan> pesan) =>
      pesan.length > 8 && ukuranRiwayat(pesan) > AppConfig.ambangRingkas;

  /// Ringkas riwayat jadi satu pesan ringkasan.
  ///
  /// Sengaja tanpa panggilan LLM (hemat kuota, tidak gagal diam-diam):
  /// mengambil pesan pertama + pesan terakhir per percakapan.
  String ringkas(List<Pesan> pesan) {
    if (pesan.isEmpty) return '';
    final List<Pesan> penting = <Pesan>[
      if (pesan.first.dariPengguna) pesan.first,
      ...pesan.where((Pesan p) => p.dariPengguna).take(6),
      ...pesan.where((Pesan p) => p.dariAi).take(3),
      if (pesan.length > 10) pesan.last,
    ];
    final Set<String> dilihat = <String>{};
    final StringBuffer b = StringBuffer('Ringkasan percakapan sebelumnya:\n');
    for (final Pesan p in penting) {
      if (!dilihat.add(p.id)) continue;
      final String isi = p.isi.length > 220
          ? '${p.isi.substring(0, 220)}…'
          : p.isi;
      if (isi.trim().isEmpty) continue;
      b.writeln('- ${p.dariPengguna ? 'User' : 'Assistant'}: $isi');
    }
    return b.toString().trim();
  }

  /// Bangun daftar pesan wire-format dari riwayat.
  List<PesanApi> keWire({
    required String systemPrompt,
    required List<Pesan> pesan,
  }) {
    final List<PesanApi> out = <PesanApi>[
      PesanApi(peran: 'system', isi: systemPrompt),
    ];
    for (final Pesan p in pesan) {
      if (p.peran == Peran.sistem) continue;
      if (p.peran == Peran.alat) continue;
      out.add(PesanApi(
        peran: p.dariPengguna ? 'user' : 'assistant',
        isi: p.isi,
      ));
    }
    return out;
  }
}
