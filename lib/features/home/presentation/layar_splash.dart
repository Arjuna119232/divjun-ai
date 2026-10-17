import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/boot/diagnostik.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/theme/app_theme.dart';

/// Splash pendek (900 ms) dengan logo + progress bar.
///
/// Tidak ada teks marketing di sini: hanya nama app dan indikator proses.
/// Warna latar = warna brand, jadi tidak ada kedip putih saat app dibuka.
class LayarSplash extends StatefulWidget {
  const LayarSplash({super.key});

  @override
  State<LayarSplash> createState() => _LayarSplashState();
}

class _LayarSplashState extends State<LayarSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.lambat,
  )..forward();

  Timer? _timer;
  Timer? _jaga;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), () => _keBeranda());
    // Watchdog: kalau 6 detik lalu masih di splash, tombol "Lanjut"
    // muncul. Ini jaring pengaman untuk laporan "layar ungu nyangkut".
    _jaga = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _galat ??= 'Layar splash belum berhasil pindah ke beranda.');
    });
  }

  void _keBeranda() {
    if (!mounted) return;
    try {
      context.go('/chat');
    } catch (e, s) {
      Diagnostik.catat(e, s, konteks: 'splash.go(/chat)');
      setState(() => _galat = '$e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _jaga?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = context.gelap;

    return Scaffold(
      backgroundColor: AppColors.brand,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.brand,
              gelap ? AppColors.brandDeep : AppColors.brandDeep,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              // Cahaya halus di belakang logo.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FadeTransition(
                      opacity: _c,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.88, end: 1)
                            .animate(CurvedAnimation(
                          parent: _c,
                          curve: AppMotion.elas,
                        )),
                        child: const _LogoSplash(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
              if (_galat == null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 56,
                  child: FadeTransition(
                    opacity: _c,
                    child: Center(
                      child: SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 3,
                            backgroundColor: Colors.white.withValues(alpha: 0.22),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(Colors.white),
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
                      onCobaLagi: _keBeranda,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoSplash extends StatelessWidget {
  const _LogoSplash();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: AppRadius.br20,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
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
    );
  }
}
