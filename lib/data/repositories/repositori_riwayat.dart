import 'dart:convert';

import '../../core/constants/app_config.dart';
import '../../core/utils/id.dart';
import '../../core/utils/teks.dart';
import '../../domain/entities/percakapan.dart';
import '../datasources/penyimpan_lokal.dart';

/// Riwayat percakapan -> file JSON (data besar, ditulis atomik).
class RepositoriRiwayat {
  RepositoriRiwayat(this._simpan);

  final SimpanBerkas _simpan;

  bool _dimuat = false;
  final Map<String, Percakapan> _peti = <String, Percakapan>{};

  Future<List<Percakapan>> semua() async {
    await _muat();
    final List<Percakapan> daftar = _peti.values.toList()
      ..sort((Percakapan a, Percakapan b) =>
          b.diperbarui.compareTo(a.diperbarui));
    return daftar;
  }

  Future<Percakapan?> ambil(String id) async {
    await _muat();
    return _peti[id];
  }

  Future<Percakapan> buat({String judul = 'Percakapan baru'}) async {
    await _muat();
    final DateTime sekarang = DateTime.now();
    final Percakapan p = Percakapan(
      id: 'perc-${Id.pendek(12)}',
      judul: judul,
      dibuat: sekarang,
      diperbarui: sekarang,
    );
    _peti[p.id] = p;
    await _tulis();
    return p;
  }

  Future<void> simpan(Percakapan p) async {
    await _muat();
    _peti[p.id] = p;
    await _tulis();
  }

  Future<void> hapus(String id) async {
    await _muat();
    _peti.remove(id);
    await _tulis();
  }

  Future<void> hapusSemua() async {
    _peti.clear();
    _dimuat = true;
    await _simpan.tulisAman(AppConfig.kRiwayat, '[]');
  }

  Future<void> _muat() async {
    if (_dimuat) return;
    final String? teks = await _simpan.baca(AppConfig.kRiwayat);
    _peti.clear();
    if (teks != null && teks.isNotEmpty) {
      try {
        final Object? dec = jsonDecode(teks);
        if (dec is List) {
          for (final dynamic item in dec) {
            if (item is Map<String, dynamic>) {
              final Percakapan p = Percakapan.dariJson(item);
              if (p.id.isNotEmpty) _peti[p.id] = p;
            }
          }
        }
      } catch (_) {
        await _simpan.tulisAman(
          'riwayat.rusak-${DateTime.now().millisecondsSinceEpoch}',
          teks,
        );
      }
    }
    _dimuat = true;
  }

  Future<void> _tulis() => _simpan.tulisAman(
        AppConfig.kRiwayat,
        jsonEncode(_peti.values.map((Percakapan p) => p.keJson()).toList()),
      );

  /// Judul otomatis dari pesan pertama user.
  static String judulOtomatis(String pesanPertama) =>
      Teks.judulPercakapan(pesanPertama);
}
