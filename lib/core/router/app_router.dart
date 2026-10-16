import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/layar_chat.dart';
import '../../features/home/presentation/layar_splash.dart';
import '../../features/memory/presentation/layar_memori.dart';
import '../../features/settings/presentation/layar_setelan.dart';

/// Routing app.
///
/// `context.go()` untuk perpindahan root (splash -> chat), `context.push()`
/// untuk halaman turunan (chat -> setelan) supaya tombol back perangkat
/// selalu benar-benar kembali, bukan langsung menutup app.
abstract final class AppRouter {
  static final GoRouter appRouter = GoRouter(
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
        path: '/memori',
        builder: (BuildContext c, GoRouterState s) => const LayarMemori(),
      ),
    ],
  );
}
