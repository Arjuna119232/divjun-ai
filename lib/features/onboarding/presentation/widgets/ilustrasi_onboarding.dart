import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/halaman_onboarding.dart';

/// Ilustrasi tiap halaman onboarding - digambar dari widget + animasi, tanpa
/// aset gambar satu pun.
///
/// Kenapa bukan gambar/animasi file: vektor selalu tajam di ukuran apa pun,
/// ikut warna tema, ukurannya tetap kecil di APK, dan geraknya bisa disinkron
/// dengan halaman (masuk berurutan, tidak berputar sendiri).
class IlustrasiOnboarding extends StatelessWidget {
  const IlustrasiOnboarding({
    super.key,
    required this.jenis,
    required this.aksen,
  });

  final GambarOnboarding jenis;
  final List<Color> aksen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: switch (jenis) {
        GambarOnboarding.obrolan => _IlustrasiObrolan(aksen: aksen),
        GambarOnboarding.orbitAlat => _IlustrasiOrbit(aksen: aksen),
        GambarOnboarding.kartuSkill => _IlustrasiSkill(aksen: aksen),
      },
    );
  }
}

/// Kotak kaca kecil untuk elemen ilustrasi.
class _Kaca extends StatelessWidget {
  const _Kaca({
    required this.radius,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(12),
  });

  final double radius;
  final Widget child;
  final Gradient? gradient;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? Colors.white.withValues(alpha: 0.07)
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}

// --------------------------------------------------------------- halaman 1

class _IlustrasiObrolan extends StatelessWidget {
  const _IlustrasiObrolan({required this.aksen});

  final List<Color> aksen;

@override
  Widget build(BuildContext context) {
    final Color warnaAksen = aksen.isNotEmpty ? aksen.first : AppColors.brand;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: _Kaca(
            radius: 18,
            gradient: LinearGradient(
              colors: <Color>[warnaAksen, warnaAksen.withValues(alpha: 0.75)],
            ),
            child: Text(
              'Buatkan draf email minta cuti 3 hari',
              style: _putih(13),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _Kaca(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(LucideIcons.brain, size: 13, color: AppColors.amber),
                    const SizedBox(width: 6),
                    Text(
                      'Berpikir 2,4 detik',
                      style: _putih(11).copyWith(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _Garis(0.9),
                const SizedBox(height: 6),
                _Garis(0.72),
                const SizedBox(height: 6),
                _Garis(0.48),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: _Kaca(
            radius: 18,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Kirim besok pagi', style: _putih(13)),
                const SizedBox(width: 6),
                _KursorBerkedip(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KursorBerkedip extends StatefulWidget {
  @override
  State<_KursorBerkedip> createState() => _KursorBerkedipState();
}

class _KursorBerkedipState extends State<_KursorBerkedip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) {
        return Container(
          width: 6,
          height: 13,
          color: Colors.white.withValues(
            alpha: _c.value > 0.5 ? 0.15 : 1,
          ),
        );
      },
    );
  }
}

class _Garis extends StatelessWidget {
  const _Garis(this.frac);

  final double frac;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: frac,
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- halaman 2

class _IlustrasiOrbit extends StatefulWidget {
  const _IlustrasiOrbit({required this.aksen});

  final List<Color> aksen;

  @override
  State<_IlustrasiOrbit> createState() => _IlustrasiOrbitState();
}

class _IlustrasiOrbitState extends State<_IlustrasiOrbit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  static const List<IconData> _alat = <IconData>[
    LucideIcons.calculator,
    LucideIcons.globe,
    LucideIcons.clock,
    LucideIcons.mail,
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                Container(
                  width: 120 + i * 56.0,
                  height: 120 + i * 56.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: i == 0 ? 0.16 : 0.08,
                      ),
                    ),
                  ),
                  transform: Matrix4.identity()
                    ..rotateZ(i.isEven ? _c.value * 0.25 : -_c.value * 0.25),
                ),
              _IntiOrbit(
                denyut: _c.value,
                warnaA: widget.aksen.isNotEmpty
                    ? widget.aksen.first
                    : AppColors.brand,
                warnaB: widget.aksen.length > 1
                    ? widget.aksen[1]
                    : AppColors.brandDeep,
              ),
              for (int i = 0; i < _alat.length; i++)
                _Satelit(
                  ikon: _alat[i],
                  sudut: (_c.value * 2 * math.pi / _alat.length) +
                      (i * math.pi / 2) +
                      (i.isOdd ? -0.35 : 0),
                  radius: i.isEven ? 76 : 60,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IntiOrbit extends StatelessWidget {
  const _IntiOrbit({
    required this.denyut,
    required this.warnaA,
    required this.warnaB,
  });

  final double denyut;
  final Color warnaA;
  final Color warnaB;

  @override
  Widget build(BuildContext context) {
    final double skala = 1 + math.sin(denyut * math.pi * 2) * 0.05;
    return Transform.scale(
      scale: skala,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[warnaA, warnaB],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: warnaA.withValues(alpha: 0.30),
              blurRadius: 34,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Center(
          child: Icon(LucideIcons.sparkles, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}

class _Satelit extends StatelessWidget {
  const _Satelit({
    required this.ikon,
    required this.sudut,
    required this.radius,
  });

  final IconData ikon;
  final double sudut;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final double dx = math.cos(sudut) * radius;
    final double dy = math.sin(sudut) * radius * 0.42;
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Icon(ikon, size: 18, color: Colors.white),
      ),
    );
  }
}

// --------------------------------------------------------------- halaman 3

class _IlustrasiSkill extends StatefulWidget {
  const _IlustrasiSkill({required this.aksen});

  final List<Color> aksen;

  @override
  State<_IlustrasiSkill> createState() => _IlustrasiSkillState();
}

class _IlustrasiSkillState extends State<_IlustrasiSkill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  static const List<String> _judul = <String>[
    'Pustaka skill',
    'Prosedur kerja',
    'Taksonomi lengkap',
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < _judul.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BarisSkill(
              judul: _judul[i],
              warna: widget.aksen[i % widget.aksen.length],
              naik: math.sin((_c.value * 2 * math.pi) + (i * 0.9)) * 6,
              lencana: i == 0 ? '111' : '',
            ),
          ),
      ],
    );
  }
}

class _BarisSkill extends StatelessWidget {
  const _BarisSkill({
    required this.judul,
    required this.warna,
    required this.naik,
    required this.lencana,
  });

  final String judul;
  final Color warna;
  final double naik;
  final String lencana;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, naik),
      child: Container(
        width: 272,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.075),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: warna.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(LucideIcons.bookOpen, size: 17, color: warna),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(judul, style: _putih(12.5, w: FontWeight.w700)),
            ),
            if (lencana.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppColors.amber, AppColors.coral],
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  lencana,
                  style: const TextStyle(
                    color: Color(0xFF241100),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

TextStyle _putih(double ukuran, {FontWeight w = FontWeight.w400}) =>
    TextStyle(
      color: Colors.white,
      fontFamily: AppTypography.ui,
      fontSize: ukuran,
      fontWeight: w,
      height: 1.4,
    );