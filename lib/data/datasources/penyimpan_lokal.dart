import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  SimpanCepit._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SimpanCepit> buka() async =>
      SimpanCepit._(await SharedPreferences.getInstance());

  String? baca(String kunci) => _prefs.getString(kunci);

  bool? bacaBool(String kunci) => _prefs.getBool(kunci);

  Future<void> tulis(String kunci, String nilai) =>
      _prefs.setString(kunci, nilai);

  Future<void> hapus(String kunci) => _prefs.remove(kunci);
}

class SimpanBerkas {
  SimpanBerkas(this._dir);

  final Directory _dir;

  static Future<SimpanBerkas> buka({String subFolder = 'divjun'}) async {
    final Directory dasar = await getApplicationDocumentsDirectory();
    final Directory d = Directory('${dasar.path}/$subFolder');
    if (!d.existsSync()) {
      await d.create(recursive: true);
    }
    return SimpanBerkas(d);
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
