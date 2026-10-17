import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Galat tidak boleh "hening".
///
/// Latar: pada build yang dilaporkan user (v2.1.1 / 2.2.0) aplikasi berhenti di
/// layar launch ungu selamanya - karena jendela launch Android (warna brand
/// `#5B5BD6`) tetap tampil selama Flutter belum menggambar frame pertama.
/// Kalau inisialisasi storage di `main()` menggantung atau lempar, tidak ada
/// apa pun yang tampil dan tidak ada jejak galatnya. Jadi:
///
/// 1. Semua galat (Flutter framework, error tak tertangani, error zona)
///    dicatat di sini, bukan cuma dicetak ke log.
/// 2. Galat build widget ditampilkan sebagai panel merah yang terbaca user,
///    bukan kotak abu-abu kosong.
/// 3. Halaman splash punya watchdog: kalau tidak sampai ke `/chat` dalam
///    6 detik, tombol "Lanjut" muncul.
class Diagnostik {
  Diagnostik._();

  static final List<String> riwayat = <String>[];
  static String? pesanTerakhir;
  static String? jejakTerakhir;

  static bool _terpasang = false;

  /// Pasang penangkap galat global. Panggil sebelum inisialisasi apa pun.
  static void pasang() {
    if (_terpasang) return;
    _terpasang = true;

    final FlutterExceptionHandler? lama = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails detail) {
      catat(
        detail.exception,
        detail.stack,
        konteks: detail.context?.toDescription() ?? 'flutter',
      );
      lama?.call(detail);
    };

    PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
      catat(e, s, konteks: 'platform');
      return true;
    };

    // Ganti tampilan error bawaan (abu-abu kosong di release) jadi panel
    // yang isinya bisa dibaca user dan developer.
    ErrorWidget.builder = _panelGalat;
  }

  static void catat(Object e, StackTrace? s, {String konteks = ''}) {
    final String teks =
        '[${DateTime.now().toIso8601String()}] $konteks: $e';
    pesanTerakhir = teks;
    jejakTerakhir = s?.toString();
    riwayat.add(teks);
    if (riwayat.length > 30) riwayat.removeAt(0);
    debugPrint('DIVJUN-DIAG $teks');
  }

  static Widget _panelGalat(FlutterErrorDetails d) {
    final String isi = d.exceptionAsString();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xFF7A1020),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'DIVJUN gagal menampilkan layar.\n\n$isi',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  /// Panel galat siap pakai untuk halaman mana pun.
  static Widget panel({String? judul, void Function()? onCobaLagi}) {
    return Container(
      color: const Color(0xFF7A1020),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            judul ?? 'DIVJUN tidak bisa lanjut',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                pesanTerakhir ?? 'Penyimpanan atau jaringan tidak merespons.',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          if (onCobaLagi != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton(onPressed: onCobaLagi, child: const Text('Coba lagi')),
          ],
        ],
      ),
    );
  }
}