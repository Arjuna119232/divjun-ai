import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/boot/diagnostik.dart';
import 'core/providers.dart';
import 'data/datasources/penyimpan_lokal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Penangkap galat global dipasang paling awal: kalau ada yang gagal,
  // jejaknya tersimpan dan bisa ditampilkan, bukan hilang diam-diam.
  Diagnostik.pasang();

  // Semua status bar/nav bar mengikuti tema (M3 edge-to-edge).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Inisialisasi tidak boleh menggantung: satu Future yang macet membuat
  // aplikasi tertahan di layar launch (jendela Android berwarna brand)
  // selamanya tanpa pesan apa pun. [_aman] menambah batas waktu 8 detik dan
  // memakai penyimpanan cadangan kalau gagal.
  final SimpanCepit cepit = await _aman(
    SimpanCepit.buka,
    SimpanCepit.darurat,
    'SimpanCepit',
  );
  final SimpanBerkas berkas = await _aman(
    SimpanBerkas.buka,
    SimpanBerkas.darurat,
    'SimpanBerkas',
  );

  runApp(
    ProviderScope(
      overrides: <Override>[
        simpanCepitProvider.overrideWithValue(cepit),
        simpanBerkasProvider.overrideWithValue(berkas),
      ],
      child: const DivjunApp(),
    ),
  );
}

/// Jalankan [jalan] dengan batas waktu; kalau gagal/terlalu lama, pakai
/// [cadangan] dan catat galatnya supaya kelihatan di layar.
Future<T> _aman<T>(
  Future<T> Function() jalan,
  T Function() cadangan,
  String nama,
) async {
  try {
    return await jalan().timeout(const Duration(seconds: 8));
  } catch (e, s) {
    Diagnostik.catat(e, s, konteks: nama);
    return cadangan();
  }
}