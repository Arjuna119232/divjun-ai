import '../../core/constants/app_config.dart';
import '../../domain/entities/setelan.dart';
import '../datasources/penyimpan_lokal.dart';

/// Pengaturan: nilai kecil -> SharedPreferences (tulis sinkron, selalu aman).
class RepositoriSetelan {
  RepositoriSetelan(this._simpan);

  final SimpanCepit _simpan;

  SetelanApp baca() => SetelanApp.dariJsonTeks(_simpan.baca(AppConfig.kPengaturan));

  Future<void> simpan(SetelanApp s) =>
      _simpan.tulis(AppConfig.kPengaturan, SetelanApp.keJsonTeks(s));
}
