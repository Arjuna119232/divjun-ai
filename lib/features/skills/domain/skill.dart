/// Model pustaka skill yang dibundel sebagai asset di dalam APK.
///
/// Sumber: `assets/skills/index.json` (dibuat oleh `tool/sync_skills.py`).
library;

import 'dart:convert';

class BerkasSkill {
  const BerkasSkill({required this.path, required this.size});

  /// Path relatif terhadap folder skill, contoh `SKILL.md`.
  final String path;
  final int size;

  static BerkasSkill dariJson(Map<String, dynamic> j) => BerkasSkill(
        path: j['path'] as String? ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
      );
}

class Skill {
  const Skill({
    required this.nama,
    required this.deskripsi,
    required this.folder,
    required this.size,
    required this.jumlahFile,
    required this.berkas,
  });

  final String nama;
  final String deskripsi;
  final String folder;
  final int size;
  final int jumlahFile;
  final List<BerkasSkill> berkas;

  bool punya(String kueri) {
    final String q = kueri.toLowerCase().trim();
    if (q.isEmpty) return true;
    return nama.toLowerCase().contains(q) ||
        folder.toLowerCase().contains(q) ||
        deskripsi.toLowerCase().contains(q);
  }

  static Skill dariJson(Map<String, dynamic> j) => Skill(
        nama: j['nama'] as String? ?? '',
        deskripsi: j['deskripsi'] as String? ?? '',
        folder: j['folder'] as String? ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
        jumlahFile: (j['jumlahFile'] as num?)?.toInt() ?? 0,
        berkas: (j['files'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(BerkasSkill.dariJson)
            .toList(),
      );
}

class IndeksSkill {
  const IndeksSkill({required this.jumlah, required this.skills});

  final int jumlah;
  final List<Skill> skills;

  static const IndeksSkill kosong = IndeksSkill(jumlah: 0, skills: <Skill>[]);

  List<Skill> cari(String kueri) =>
      skills.where((Skill s) => s.punya(kueri)).toList();

  int get totalBerkas =>
      skills.fold<int>(0, (int a, Skill s) => a + s.jumlahFile);

  int get totalUkuran => skills.fold<int>(0, (int a, Skill s) => a + s.size);

  /// Skill paling relevan untuk sebuah pesan (skor kata kunci).
  ///
  /// Dipakai agent: sebelum menjawab, app menyuntik 1-2 SKILL.md yang cocok
  /// supaya AI punya prosedur kerja, bukan cumaparametric knowledge.
  List<Skill> relevan(String pesan, {int maks = 2}) {
    final List<String> kunci = kataKunci(pesan);
    if (kunci.isEmpty) return const <Skill>[];

    final List<({Skill skill, double skor})> hasil =
        <({Skill skill, double skor})>[];
    for (final Skill s in skills) {
      final String target =
          '${s.nama} ${s.deskripsi}'.toLowerCase();
      double skor = 0;
      for (final String k in kunci) {
        if (target.contains(k)) skor += k.length > 6 ? 2 : 1;
      }
      // Skill dengan nama panjang biasanya lebih spesifik.
      if (pesan.toLowerCase().contains(s.nama.toLowerCase())) skor += 3;
      if (skor == 0) continue;
      skor += s.nama.length / 100;
      hasil.add((skill: s, skor: skor));
    }
    hasil.sort((({Skill skill, double skor}) a,
            ({Skill skill, double skor}) b) =>
        b.skor.compareTo(a.skor));
    return hasil.take(maks).map((({Skill skill, double skor}) e) => e.skill).toList();
  }

  /// Ambil kata kunci: buang kata umum, potong 3-40 huruf.
  static List<String> kataKunci(String teks) {
    const Set<String> umum = {
      'yang', 'dan', 'atau', 'untuk', 'dengan', 'dari', 'pada', 'itu',
      'ini', 'apa', 'bagaimana', 'kenapa', 'bisa', 'buat', 'bikin', 'saya',
      'aku', 'kamu', 'kalian', 'tolong', 'dong', 'kah', 'nya', 'ada',
    };
    final Set<String> hasil = <String>{};
    for (final String kata in teks.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
      if (kata.length < 3 || kata.length > 40) continue;
      if (umum.contains(kata)) continue;
      hasil.add(kata);
      // juga simpan awalan panjang (mis. "flutter" dari "flutter_apk")
      if (kata.length > 8) hasil.add(kata.substring(0, 6));
    }
    return hasil.toList();
  }
}

/// Parser `index.json`. Pakai `dart:convert` (pustaka inti, tanpa Flutter)
/// supaya bisa diuji di unit test tanpa asset bundle.
IndeksSkill parseIndeksSkill(String json) {
  try {
    final Object? dec = jsonDecode(json);
    if (dec is! Map<String, dynamic>) return IndeksSkill.kosong;
    final List<dynamic> daftar = dec['skills'] as List<dynamic>? ?? <dynamic>[];
    return IndeksSkill(
      jumlah: (dec['jumlah'] as num?)?.toInt() ?? daftar.length,
      skills: daftar
          .whereType<Map<String, dynamic>>()
          .map(Skill.dariJson)
          .toList(),
    );
  } catch (_) {
    return IndeksSkill.kosong;
  }
}
