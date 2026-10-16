import 'dart:convert';
import 'dart:math';

import '../../core/constants/app_config.dart';
import '../../core/utils/id.dart';
import '../../core/utils/teks.dart';
import '../../domain/entities/memori.dart';
import '../datasources/penyimpan_lokal.dart';

/// Memori jangka panjang -> file JSON + pencarian lokal (tanpa vector DB).
class RepositoriMemori {
  RepositoriMemori(this._simpan);

  final SimpanBerkas _simpan;

  bool _dimuat = false;
  final List<EntriMemori> _peti = <EntriMemori>[];

  Future<List<EntriMemori>> semua() async {
    await _muat();
    final List<EntriMemori> d = List<EntriMemori>.from(_peti)
      ..sort((EntriMemori a, EntriMemori b) => b.dibuat.compareTo(a.dibuat));
    return d;
  }

  Future<List<EntriMemori>> perKategori(String kategori) async {
    final List<EntriMemori> d = await semua();
    return d.where((EntriMemori e) => e.kategori == kategori).toList();
  }

  Future<EntriMemori> tambah({
    required String isi,
    String kategori = KategoriMemori.umum,
    String sumber = 'user',
  }) async {
    await _muat();
    final EntriMemori e = EntriMemori(
      id: 'mem-${Id.pendek(12)}',
      kategori: KategoriMemori.semua.contains(kategori)
          ? kategori
          : KategoriMemori.umum,
      isi: Teks.bersihSpasi(isi),
      dibuat: DateTime.now(),
      sumber: sumber,
    );
    // Hindari duplikat persis.
    _peti.removeWhere((EntriMemori x) => x.isi.toLowerCase() == e.isi.toLowerCase());
    _peti.add(e);
    await _tulis();
    return e;
  }

  Future<void> hapus(String id) async {
    await _muat();
    _peti.removeWhere((EntriMemori e) => e.id == id);
    await _tulis();
  }

  Future<void> hapusSemua() async {
    _peti.clear();
    _dimuat = true;
    await _simpan.tulisAman(AppConfig.kMemori, '[]');
  }

  /// Pencarian lokal sederhana:skor = tumpang tindih kata kunci + kesegaran.
  /// Cukup untuk data puluhan/ribuan entri; vector DB baru perlu kalau
  /// memori tumbuh jadi ribuan dokumen panjang.
  Future<List<EntriMemori>> cari(String kueri, {int maks = 5}) async {
    await _muat();
    if (_peti.isEmpty) return <EntriMemori>[];
    final List<String> kunci = Teks.kata(kueri);
    if (kunci.isEmpty) {
      return (List<EntriMemori>.from(_peti)
            ..sort((EntriMemori a, EntriMemori b) => b.dibuat.compareTo(a.dibuat)))
          .take(maks)
          .toList();
    }

    final DateTime sekarang = DateTime.now();
    final List<MapEntry<EntriMemori, double>> hasil =
        <MapEntry<EntriMemori, double>>[];

    for (final EntriMemori e in _peti) {
      final String isi = Teks.normalisasi('${e.kategori} ${e.isi}');
      double skor = 0;
      for (final String k in kunci) {
        if (isi.contains(k)) skor += 1;
      }
      if (skor == 0) continue;
      // Bonus kalau kategori ikut disebut di kueri.
      if (kueri.toLowerCase().contains(e.kategori)) skor += 0.5;
      // Bonus kesegaran (maks 0.8).
      final int umurHari = sekarang.difference(e.dibuat).inDays;
      skor += max(0, 0.8 - umurHari * 0.05);
      hasil.add(MapEntry<EntriMemori, double>(e, skor));
    }

    hasil.sort((MapEntry<EntriMemori, double> a,
            MapEntry<EntriMemori, double> b) =>
        b.value.compareTo(a.value));
    return hasil.take(maks).map((MapEntry<EntriMemori, double> m) => m.key).toList();
  }

  Future<void> tandaiDipakai(List<String> idTerpakai) async {
    if (idTerpakai.isEmpty) return;
    await _muat();
    bool adaPerubahan = false;
    for (int i = 0; i < _peti.length; i++) {
      if (idTerpakai.contains(_peti[i].id)) {
        _peti[i] = _peti[i].salin(dipakai: _peti[i].dipakai + 1);
        adaPerubahan = true;
      }
    }
    if (adaPerubahan) await _tulis();
  }

  Future<void> _muat() async {
    if (_dimuat) return;
    final String? teks = await _simpan.baca(AppConfig.kMemori);
    _peti.clear();
    if (teks != null && teks.isNotEmpty) {
      try {
        final Object? dec = jsonDecode(teks);
        if (dec is List) {
          for (final dynamic item in dec) {
            if (item is Map<String, dynamic>) {
              final EntriMemori e = EntriMemori.dariJson(item);
              if (e.id.isNotEmpty) _peti.add(e);
            }
          }
        }
      } catch (_) {
        await _simpan.tulisAman(
          'memori.rusak-${DateTime.now().millisecondsSinceEpoch}',
          teks,
        );
      }
    }
    _dimuat = true;
  }

  Future<void> _tulis() => _simpan.tulisAman(
        AppConfig.kMemori,
        jsonEncode(_peti.map((EntriMemori e) => e.keJson()).toList()),
      );
}
