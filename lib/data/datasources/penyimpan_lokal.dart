import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/boot/diagnostik.dart';

/// Penyimpanan lokal: dua lapisan.
///
/// 1) [SimpanCepit] (SharedPreferences) - untuk hal kecil & sering ditulis:
///    pengaturan, penanda UI. Nilainya kecil, tulis sinkron, aman.
/// 2) [SimpanBerkas] (file JSON di documents dir) - untuk data besar:
///    riwayat percakapan + memori. Tulis lewat file, tidak memuat seluruh
///    blob ke memory UI, dan bisa disalin/backup sendiri.
///
/// Kenapa tidak Hive/Isar di v1: keduanya perlu codegen/build step dan
/// punya sejarah masalah ABI di Android 16. Data app ini kecil (ribuan baris
/// JSON), jadi file JSON lebih simple + mudah diaudit. Naikkan ke Isar kalau
/// histori sudah tumbuh ke ratusan MB.
class SimpanCepit {
  SimpanCepit._(this._prefs, [Map<String, Object?>? memori])
    : _memori = memori ?? <String, Object?>{};

  /// Null kalau SharedPreferences gagal dibuka - dipakai [SimpanCepit.memori]
  /// supaya aplikasi tetap jalan (dengan penyimpanan sementara) alih-alih
  /// menggantung selamanya di layar launch.
  final SharedPreferences? _prefs;
  final Map<String, Object?> _memori;

  /// True kalau data hanya ada di memori (belum ketemu tempat simpan).
  bool get sementara => _prefs == null;

  /// Cadangan terakhir: seluruh nilai disimpan di memori saja.
  /// Dipakai kalau [buka] tidak selesai dalam batas waktu.
  static SimpanCepit darurat() {
    Diagnostik.catat(
      StateError('SharedPreferences tidak merespons - pakai penyimpanan memori'),
      null,
      konteks: 'SimpanCepit.darurat',
    );
    return SimpanCepit._(null);
  }

  static Future<SimpanCepit> buka() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      return SimpanCepit._(p);
    } catch (e, s) {
      Diagnostik.catat(e, s, konteks: 'SimpanCepit.buka');
      return SimpanCepit._(null);
    }
  }

  String? baca(String kunci) => _prefs?.getString(kunci) ?? _memori[kunci] as String?;

  bool? bacaBool(String kunci) =>
      _prefs?.getBool(kunci) ?? _memori[kunci] as bool?;

  Future<void> tulis(String kunci, String nilai) async {
    final SharedPreferences? p = _prefs;
    if (p == null) {
      _memori[kunci] = nilai;
      return;
    }
    try {
      await p.setString(kunci, nilai);
    } catch (e, s) {
      Diagnostik.catat(e, s, konteks: 'SimpanCepit.tulis');
    }
  }

  Future<void> hapus(String kunci) async {
    final SharedPreferences? p = _prefs;
    if (p == null) {
      _memori.remove(kunci);
      return;
    }
    try {
      await p.remove(kunci);
    } catch (e, s) {
      Diagnostik.catat(e, s, konteks: 'SimpanCepit.hapus');
    }
  }
}

class SimpanBerkas {
  SimpanBerkas(this._dir, {this.sementara = false});

  final Directory _dir;

  /// True kalau menulis ke direktori sementara (documents dir gagal dibuka).
  final bool sementara;

  /// Cadangan terakhir: direktori sementara sistem.
  static SimpanBerkas darurat({String subFolder = 'divjun'}) {
    Diagnostik.catat(
      StateError('Documents dir tidak merespons - pakai direktori sementara'),
      null,
      konteks: 'SimpanBerkas.darurat',
    );
    return SimpanBerkas(Directory.systemTemp, sementara: true);
  }

  static Future<SimpanBerkas> buka({String subFolder = 'divjun'}) async {
    Directory? dasar;
    try {
      dasar = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 5));
    } catch (e, s) {
      Diagnostik.catat(e, s, konteks: 'SimpanBerkas.buka');
    }
    // Cadangan: direktori sementara sistem supaya aplikasi tetap jalan.
    dasar ??= Directory.systemTemp;
    final Directory d = Directory('${dasar.path}/$subFolder');
    if (!d.existsSync()) {
      await d.create(recursive: true);
    }
    return SimpanBerkas(
      d,
      sementara: d.path.startsWith(Directory.systemTemp.path),
    );
  }

  String _jalur(String nama) => '${_dir.path}/$nama.json';

  bool ada(String nama) => File(_jalur(nama)).existsSync();

  Future<String?> baca(String nama) async {
    final File f = File(_jalur(nama));
    if (!f.existsSync()) return null;
    try {
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> tulis(String nama, String isi) async {
    final File f = File(_jalur(nama));
    await f.writeAsString(isi, flush: true);
  }

  Future<void> hapus(String nama) async {
    final File f = File(_jalur(nama));
    if (f.existsSync()) await f.delete();
  }

  /// Tulis lewat file sementara lalu rename: kalau aplikasi mati di tengah
  /// penulisan, file lama tetap utuh (tidak ada file korup).
  Future<void> tulisAman(String nama, String isi) async {
    final String sementara = '${_jalur(nama)}.tmp';
    await File(sementara).writeAsString(isi, flush: true);
    await File(sementara).rename(_jalur(nama));
  }

  Future<int> ukuran(String nama) async {
    final File f = File(_jalur(nama));
    if (!f.existsSync()) return 0;
    return f.lengthSync();
  }
}
