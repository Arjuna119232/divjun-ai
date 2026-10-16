import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/layar_chat.dart';
import '../../features/home/presentation/layar_splash.dart';
import '../../features/memory/presentation/layar_memori.dart';
import '../../features/settings/presentation/halaman_koneksi.dart';
import '../../features/settings/presentation/halaman_kunci.dart';
import '../../features/settings/presentation/layar_setelan.dart';
import '../../features/skills/presentation/layar_skill.dart';

/// Routing app.
///
/// `context.go()` untuk perpindahan root (splash -> chat), `context.push()`
/// untuk halaman turunan (chat -> setelan) supaya tombol back perangkat
/// selalu benar-benar kembali, bukan langsung menutup app.
///
/// Satu instance global, dipakai `MaterialApp.router` di app.dart.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      builder: (BuildContext c, GoRouterState s) => const LayarSplash(),
    ),
    GoRoute(
      path: '/chat',
      builder: (BuildContext c, GoRouterState s) => const LayarChat(),
    ),
    GoRoute(
      path: '/setelan',
      builder: (BuildContext c, GoRouterState s) => const LayarSetelan(),
    ),
    GoRoute(
      path: '/koneksi',
      builder: (BuildContext c, GoRouterState s) => const HalamanKoneksi(),
    ),
    GoRoute(
      path: '/kunci',
      builder: (BuildContext c, GoRouterState s) => const HalamanKunci(),
    ),
    GoRoute(
      path: '/skills',
      builder: (BuildContext c, GoRouterState s) => const LayarSkill(),
    ),
    GoRoute(
      path: '/memori',
      builder: (BuildContext c, GoRouterState s) => const LayarMemori(),
    ),
  ],
);
