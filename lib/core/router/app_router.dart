import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/layar_login.dart';
import '../../features/chat/presentation/layar_chat.dart';
import '../../features/home/presentation/layar_splash.dart';
import '../../features/legal/data/legal_service.dart';
import '../../features/legal/presentation/halaman_markdown.dart';
import '../../features/legal/presentation/pusat_legal_screen.dart';
import '../../features/memory/presentation/layar_memori.dart';
import '../../features/onboarding/presentation/layar_onboarding.dart';
import '../../features/settings/presentation/halaman_koneksi.dart';
import '../../features/settings/presentation/halaman_kunci.dart';
import '../../features/settings/presentation/layar_lanjutan.dart';
import '../../features/settings/presentation/layar_setelan.dart';
import '../../features/settings/presentation/layar_tentang.dart';
import '../../features/skills/presentation/layar_skill.dart';
import '../theme/app_transitions.dart';

/// Routing app.
///
/// Setiap route memakai [CustomTransitionPage] sendiri, bukan animasi Material
/// bawaan. Alasannya: perpindahan "dunia baru" (onboarding -> chat) memakai
/// zoom-through dua arah, sementara halaman turunan (chat -> pengaturan) memakai
/// geser kecil. Campur keduanya dalam satu `builder:` tidak mungkin.
///
/// `context.go()` untuk perpindahan root (splash -> onboarding -> chat),
/// `context.push()` untuk halaman turunan (chat -> setelan) supaya tombol back
/// perangkat selalu benar-benar kembali, bukan langsung menutup app.
///
/// Satu instance global, dipakai `MaterialApp.router` di app.dart.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: <RouteBase>[
    GoRoute(
      path: '/splash',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const LayarSplash()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.portalPage<void>(s, const LayarOnboarding()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.portalPage<void>(s, const LayarLogin()),
    ),
    GoRoute(
      path: '/chat',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.portalPage<void>(s, const LayarChat()),
    ),
    GoRoute(
      path: '/setelan',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const LayarSetelan()),
    ),
    GoRoute(
      path: '/koneksi',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const HalamanKoneksi()),
    ),
    GoRoute(
      path: '/setelan/lanjutan',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const LayarLanjutan()),
    ),
    GoRoute(
      path: '/setelan/tentang',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const LayarTentang()),
    ),
    GoRoute(
      path: '/kunci',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const HalamanKunci()),
    ),
    GoRoute(
      path: '/skills',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const LayarSkill()),
    ),
    GoRoute(
      path: '/memori',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const LayarMemori()),
    ),
    GoRoute(
      path: '/legal',
      pageBuilder: (BuildContext c, GoRouterState s) =>
          AppTransisi.halaman<void>(s, const PusatLegalScreen()),
    ),
    GoRoute(
      // Id dokumen ikut di URL supaya tautan dari halaman Login tetap sah
      // kalau app dibuka ulang lewat deep link.
      path: '/legal/dokumen/:id',
      pageBuilder: (BuildContext c, GoRouterState s) {
        final DokumenLegal? dok = LegalService.cari(s.pathParameters['id'] ?? '');
        // Id tidak dikenal -> tampilkan daftar dokumen, jangan layar kosong.
        if (dok == null) {
          return AppTransisi.halaman<void>(s, const PusatLegalScreen());
        }
        return AppTransisi.halaman<void>(
          s,
          HalamanMarkdown(judul: dok.judul, berkas: dok.berkas),
        );
      },
    ),
  ],
);
