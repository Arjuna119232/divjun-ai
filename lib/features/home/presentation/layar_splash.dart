import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/boot/diagnostik.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/presentation/layar_onboarding.dart';

/// Splash pendek (900 ms) dengan logo + progress bar.
///
/// Tidak ada teks marketing di sini: hanya nama app dan indikator proses.
/// Warna latar = warna brand, jadi tidak ada kedip putih saat app dibuka.
class LayarSplash extends ConsumerStatefulWidget {
  const LayarSplash({super.key});

  @override
  ConsumerState<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends ConsumerState<LayarSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.lambat,
  )..forward();

  /// Transisi keluar: lambang membesar jadi "portal" yang menutup layar.
  /// Satu controller untuk lambang DAN teks, jadi keduanya tidak meleset.
  late final AnimationController _cKeluar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  Timer? _timer;
  Timer? _jaga;
  String? _galat;
  bool _keluar = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      const Duration(milliseconds: AppConfig.durasiSplashMs),
      () => _bukaPortal(),
    );
    // Watchdog: kalau 6 detik lalu masih di splash, tombol "Lanjut"
    // muncul. Ini jaring pengaman untuk laporan "layar ungu nyangkut".
    _jaga = Timer(
      const Duration(seconds: AppConfig.durasiSplashMs ~/ 1000 + 6),
      () {
        if (!mounted) return;
        setState(() => _galat ??= 'Layar splash belum berhasil pindah ke beranda.');
      },
    );
  }

  /// Logo melebar sampai memenuhi layar, lalu pindah ke onboarding/chat.
  /// Efeknya membaca sebagai "pintu terbuka", jadi halaman berikutnya
  /// terasa seperti dunia yang sedang dimasuki, bukan layar yang diganti.
  Future<void> _bukaPortal() async {
    if (!mounted || _keluar) return;
    setState(() => _keluar = true);
    await _cKeluar.forward();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    _keBeranda();
  }

  void _keBeranda() {
    if (!mounted) return;
    try {
      // Onboarding hanya sekali: kuncinya dibaca di sini, bukan di dalam
      // LayarOnboarding, supaya `/onboarding` yang dibuka manual dari
      // Pengaturan tidak ikut terpengaruh keputusan ini.
      final bool sudah =
          ref.read(simpanCepitProvider).bacaBool(kunciOnboarding) ?? false;
      context.go(sudah ? '/chat' : '/onboarding');
    } catch (e, s) {
      Diagnostik.catat(e, s, konteks: 'splash.go');
      setState(() => _galat = '$e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _jaga?.cancel();
    _c.dispose();
    _cKeluar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brand,
      body: AnimatedBuilder(
        animation: _cKeluar,
        builder: (BuildContext context, Widget? _) {
          // v=0 normal, v=1 portal sudah menutup layar.
          final double v = Curves.easeInCubic.transform(_cKeluar.value);
          return Stack(
            children: <Widget>[
              // Gradasian tetap ada saat portal menutup: kalau latar rata,
              // lambang yang melebar tidak kelihatan bergerak.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[AppColors.brand, AppColors.brandDeep],
                    ),
                  ),
                ),
              ),
              // Cahaya halus di belakang logo.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.10 * (1 - v)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Nama aplikasi memudar duluan, lambang yang jadi portal.
              Opacity(
                opacity: (1 - v * 1.6).clamp(0.0, 1.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FadeTransition(
                        opacity: _c,
                        child: Text(
                          AppConfig.appName,
                          style: AppTypography.textTheme(Brightness.dark)
                              .displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                letterSpacing: 2.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Logo becomes the portal: border radius shrinks to a circle
              // while it grows to fill the whole screen.
              Center(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (BuildContext context, Widget? _) {
                    return Opacity(
                      opacity: _c.value,
                      child: Transform.scale(
                        scale: 1 + (v * 9),
                        child: _LogoSplash(menempel: v > 0.01),
                      ),
                    );
                  },
                ),
              ),
              if (_galat == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 56,
                  child: Opacity(
                    opacity: (1 - v * 2).clamp(0.0, 1.0),
                    child: FadeTransition(
                      opacity: _c,
                      child: Center(
                        child: SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.22),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Diagnostik.panel(
                      judul: 'DIVJUN tersendat',
                      onCobaLagi: _bukaPortal,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LogoSplash extends StatelessWidget {
  const _LogoSplash({this.menempel = false});

  /// True saat portal sedang menutup: huruf disembunyikan supaya yang melebar
  /// hanyalah kotak warna, bukan lambang yang jadi Huge.
  final bool menempel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: menempel ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(menempel ? 999 : 20),
        border: Border.all(
          color: Colors.white.withValues(alpha: menempel ? 0 : 0.35),
        ),
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: menempel ? 0 : 1,
        child: const Center(
          child: Text(
            'D',
            style: TextStyle(
              color: Colors.white,
              fontFamily: AppTypography.ui,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
