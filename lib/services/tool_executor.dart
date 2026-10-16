import 'dart:async';

import '../core/constants/app_config.dart';
import '../data/models/chat_api.dart';
import '../features/agent/tools/alat.dart';
import '../features/agent/tools/daftar_alat.dart';

/// Hasil eksekusi satu tool call, siap ditempel sebagai pesan `tool`.
class HasilPanggilan {
  const HasilPanggilan({required this.call, required this.hasil});

  final PanggilanAlat call;
  final HasilAlat hasil;

  String get teksUntukModel {
    if (hasil.gagal) return 'ERROR: ${hasil.isi}';
    return hasil.isi;
  }
}

/// Eksekusi tool-call dari model.
///
/// Keamanan & ketahanan:
/// - tool yang tidak terdaftar / dimatikan di setelan -> jawaban jujur ke model;
/// - anti-duplikasi: call dengan (nama + argumen) sama pada langkah yang sama
///   hanya dieksekusi sekali (model kadang mengulang sendiri);
/// - batas jumlah tool per langkah;
/// - timeout per tool supaya satu tool macet tidak membekukan agent;
/// - pembatalan user langsung dihormati.
class ToolExecutor {
  ToolExecutor(this.daftar, {this.detikBatas = const Duration(seconds: 20)});

  final DaftarAlat daftar;
  final Duration detikBatas;

  final Set<String> _sudahDipakai = <String>{};
  int _jumlah = 0;

  /// Panggil tiap kali agent masuk langkah baru supaya dedup bersih.
  void langkahBaru() {
    _sudahDipakai.clear();
    _jumlah = 0;
  }

  Future<HasilPanggilan> jalankan(PanggilanAlat call, KonteksAlat ctx) async {
    final String kunci = '${call.nama}::${call.argumen.trim()}';
    if (_sudahDipakai.contains(kunci)) {
      return HasilPanggilan(
        call: call,
        hasil: HasilAlat.salah(
          'Tool ini sudah dipanggil dengan argumen sama pada langkah ini, '
          'jadi diabaikan agar tidak mengulang.',
          ringkasan: 'Duplikat diabaikan',
        ),
      );
    }
    if (_jumlah >= AppConfig.batasToolPerLangkah) {
      return HasilPanggilan(
        call: call,
        hasil: HasilAlat.salah(
          'Batas ${AppConfig.batasToolPerLangkah} tool per langkah tercapai.',
          ringkasan: 'Batas tool tercapai',
        ),
      );
    }
    _sudahDipakai.add(kunci);
    _jumlah++;

    final Alat? alat = daftar.cari(call.nama);
    if (alat == null) {
      return HasilPanggilan(
        call: call,
        hasil: HasilAlat.salah(
          'Tool "${call.nama}" tidak tersedia. Tool yang aktif: '
          '${daftar.namaAktif().join(', ')}.',
          ringkasan: 'Tool tidak dikenal',
        ),
      );
    }
    if (!call.sah) {
      return HasilPanggilan(
        call: call,
        hasil: HasilAlat.salah(
          'Argumen tool tidak valid: ${call.kesalahan}',
          ringkasan: 'Argumen rusak',
        ),
      );
    }
    if (ctx.sudahBatal()) {
      return HasilPanggilan(
        call: call,
        hasil: HasilAlat.salah('Dibatalkan user.', ringkasan: 'Dibatalkan'),
      );
    }

    try {
      final HasilAlat hasil = await alat
          .jalankan(call.argumenMap(), ctx)
          .timeout(detikBatas);
      return HasilPanggilan(call: call, hasil: hasil);
    } on TimeoutException {
      return HasilPanggilan(
        call: call,
        hasil: HasilAlat.salah(
          'Tool melebihi batas ${detikBatas.inSeconds} detik.',
          ringkasan: 'Tool timeout',
        ),
      );
    } catch (e) {
      return HasilPanggilan(
        call: call,
        hasil: HasilAlat.salah('Tool gagal: $e', ringkasan: 'Tool error'),
      );
    }
  }
}
