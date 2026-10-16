import 'package:flutter/services.dart';

import '../domain/skill.dart';

/// Akses pustaka skill yang dibundel di APK (`assets/skills/`).
///
/// Tidak ada jaringan: semua skill ikut terpasang di dalam app, jadi bisa
/// dibuka offline dan tidak pernah "tiba hilang".
class SkillRepository {
  SkillRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String indeksPath = 'assets/skills/index.json';

  final AssetBundle _bundle;
  IndeksSkill? _cache;

  Future<IndeksSkill> muatIndeks({bool paksa = false}) async {
    if (_cache != null && !paksa) return _cache!;
    try {
      final String isi = await _bundle.loadString(indeksPath);
      _cache = parseIndeksSkill(isi);
    } catch (_) {
      _cache = IndeksSkill.kosong;
    }
    return _cache!;
  }

  /// Isi `SKILL.md` sebuah skill.
  Future<String?> bacaSkill(Skill s) => bacaBerkas(s, 'SKILL.md');

  Future<String?> bacaBerkas(Skill s, String path) async {
    final String bersih = path.startsWith('/') ? path.substring(1) : path;
    if (bersih.contains('..')) return null;
    try {
      return await _bundle.loadString('assets/skills/${s.folder}/$bersih');
    } catch (_) {
      return null;
    }
  }

  Future<bool> adaBerkas(Skill s, String path) async =>
      (await bacaBerkas(s, path)) != null;

  /// Skill yang paling relevan untuk sebuah pesan (untuk agent).
  Future<List<Skill>> relevan(String pesan, {int maks = 2}) async {
    final IndeksSkill idx = await muatIndeks();
    return idx.relevan(pesan, maks: maks);
  }

  /// Rakit blok panduan skill untuk disuntik ke system prompt.
  ///
  /// Dibatasi total karakternya supaya context tidak meledak; isi dipotong
  /// dari ATAS karena bagian atas SKILL.md = nama + kapan dipakai.
  Future<String?> panduanUntuk(String pesan, {int maksSkill = 2}) async {
    final List<Skill> cocok = await relevan(pesan, maks: maksSkill);
    if (cocok.isEmpty) return null;

    final StringBuffer b = StringBuffer();
    int sisa = 6000;
    for (final Skill s in cocok) {
      final String? isi = await bacaSkill(s);
      if (isi == null || isi.isEmpty) continue;
      final String potongan =
          isi.length > sisa ? '${isi.substring(0, sisa)}\n…(dipotong)' : isi;
      sisa -= potongan.length;
      b.writeln('### Skill: ${s.nama}');
      if (s.deskripsi.isNotEmpty) b.writeln('> ${s.deskripsi}');
      b.writeln(potongan);
      b.writeln();
      if (sisa <= 0) break;
    }
    final String hasil = b.toString().trim();
    return hasil.isEmpty ? null : hasil;
  }
}