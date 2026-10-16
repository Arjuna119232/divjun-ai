import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'data/datasources/penyimpan_lokal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Semua status bar/nav bar mengikuti tema (M3 edge-to-edge).
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Storage diinisialisasi SEBELUM runApp supaya provider tidak perlu
  // FutureBuilder di setiap layar.
  final SimpanCepit cepit = await SimpanCepit.buka();
  final SimpanBerkas berkas = await SimpanBerkas.buka();

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
