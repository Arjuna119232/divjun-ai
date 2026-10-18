import '../core/constants/app_config.dart';
import '../data/datasources/klien_llm.dart';
import '../domain/entities/memori.dart';
import '../domain/entities/percakapan.dart';

/// Layanan memori: menyuntikkan memori jangka panjang ke system prompt dan
/// merangkum riwayat kalau sudah terlalu panjang.
class MemoryService {
  const MemoryService();

  /// Aturan menjalankan, ikut di setiap system prompt (mulai v2.9.0).
  ///
  /// Sengaja ditulis RINGKAS: string ini dikirim di SETIAP permintaan ke
  /// provider, jadi setiap kalimat ada harganya. Jangan menambah baris tanpa
  /// menghitung token - aturan yang panjang bisa membuat prompt tambahan user
  /// atau blok memori ikut terpotong.
  static const String _aturanBerpikir = '''
Aturan menjalankan:
1. Kamu punya batas langkah. Jangan habiskan jatah untuk percobaan sia-sia. Kalau sebuah alat gagal, jangan ulangi dengan cara yang sama.
2. URL gagal dibuka (404 atau tidak bisa diakses): jangan buka lagi. Maksimal 2 percobaan, lalu BERHENTI mencari web dan jawab dari cuplikan hasil pencarian atau pengetahuanmu sendiri. Kalau memakai pengetahuanmu sendiri, sebutkan itu sebagai informasi umum.
3. Kalau batas langkah hampir habis, berhenti mencari dan susun jawaban akhir sendiri. Jangan biarkan jawaban terpotong.
4. Kalau semua sumber gagal, jujur dan sampaikan apa adanya. Tetap berikan jawaban dari cuplikan atau pengetahuanmu sendiri. Jangan pernah jawaban kosong atau menempel pesan error mentah ke user.
5. Kalau model ditolak provider lalu sistem dialihkan ke model lain, abaikan pesan error itu dan lanjutkan tugas dari titik terakhir. Jangan ulangi percakapan dari awal.
6. Kata kunci pencarian harus spesifik dan menyebut lokasi, bukan kalimat umum.
7. Format jawaban rapi: daftar atau tabel (nama, deskripsi singkat, kisaran harga bila ada). Jangan menempel URL panjang mentah kecuali diminta.
8. Kalau permintaan terlalu umum, berikan 3-5 pilihan awal lalu ajukan satu pertanyaan untuk mempersempit. Jangan bertanya lagi kalau jawabanmu sudah memadai.
9. Keamanan: jangan rekomendasikan tindakan yang melanggar hukum. Untuk harga atau transaksi, ingatkan user memverifikasi langsung ke pihak terkait karena informasi bisa kedaluwarsa.''';

  /// Bangun system prompt + blok memori.
  ///
  /// [namaPengguna] boleh kosong. [memori] = hasil pencarian memori lokal.
  String systemPrompt({
    required String namaPengguna,
    required bool agentAktif,
    required String promptTambahan,
    List<EntriMemori> memori = const <EntriMemori>[],
    bool bisaWeb = true,
    String? panduanSkill,
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
    b.writeln();
    b.write(_aturanBerpikir);
    if (memori.isNotEmpty) {
      b.writeln();
      b.writeln('Memori jangka panjang user (dari sebelumnya):');
      for (final EntriMemori e in memori.take(8)) {
        b.writeln('- [${KategoriMemori.label(e.kategori)}] ${e.isi}');
      }
    }
    if (panduanSkill != null && panduanSkill.trim().isNotEmpty) {
      b.writeln();
      b.writeln(
        'Pustaka skill internal app (pakai sebagai prosedur kerja kalau '
        'relevan; jangan disebut sebagai sumber):',
      );
      b.writeln(panduanSkill.trim());
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
