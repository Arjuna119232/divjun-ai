import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Latar onboarding: gradasian dalam, orb melayang, grid halus, dan
/// partikel berkedip - semuanya digambar di satu [CustomPainter].
///
/// Kenapa painter dan bukan tumpukan widget: tiap lapisan butuh berubah
/// setiap frame. Kalau lewat widget, tiap frame membangun ulang subtree dan
/// bateria habis. Di painter, satu `repaint` cukup.
///
/// Latar selalu gelap (identitas brand), apa pun tema sistem. Itu keputusan
/// desain, bukan bug: onboarding adalah ruang sendiri, dan neon di atas
/// putih terlihat murah.
class LatarOnboarding extends StatefulWidget {
  const LatarOnboarding({super.key, required this.animate});

  final bool animate;

  @override
  State<LatarOnboarding> createState() => _LatarOnboardingState();
}

class _LatarOnboardingState extends State<LatarOnboarding>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(LatarOnboarding lama) {
    super.didUpdateWidget(lama);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            painter: _PelukisLatar(_c.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _PelukisLatar extends CustomPainter {
  _PelukisLatar(this.t);

  /// 0..1, siklus penuh 24 detik.
  final double t;

  /// Posisi partikel dibuat SEKALI dari seed tetap supaya tidak berkedip
  /// acak tiap frame (pozisi acak per frame = flickering, sangat menyilaukan).
  static final List<_Partikel> _partikel = _buatPartikel();

  static List<_Partikel> _buatPartikel() {
    final math.Random r = math.Random(7);
    return List<_Partikel>.generate(
      26,
      (int i) => _Partikel(
        x: r.nextDouble(),
        y: r.nextDouble(),
        ukuran: 1.1 + r.nextDouble() * 1.9,
        fase: r.nextDouble(),
        kecepatan: 0.5 + r.nextDouble() * 1.1,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect layar = Offset.zero & size;
    canvas.drawRect(
      layar,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.45),
          radius: 1.15,
          colors: <Color>[Color(0xFF26264E), Color(0xFF15152E), Color(0xFF0B0B10)],
          stops: <double>[0, 0.45, 1],
        ).createShader(layar),
    );

    _gambarOrb(canvas, size, const Offset(-0.22, -0.14), 0.52, AppColors.brand, 0.52);
    _gambarOrb(canvas, size, const Offset(1.06, 0.42), 0.46, AppColors.mint, 0.30);
    _gambarOrb(canvas, size, const Offset(-0.10, 1.06), 0.58, AppColors.coral, 0.20);
    _gambarOrb(canvas, size, const Offset(0.86, 0.92), 0.34, AppColors.amber, 0.16);

    _gambarGrid(canvas, size);
    _gambarPartikel(canvas, size);

    // Vignette supaya teks di tengah selalu terbaca.
    canvas.drawRect(
      layar,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: <Color>[Colors.transparent, const Color(0xE605050C)],
          stops: const <double>[0.45, 1],
        ).createShader(layar),
    );
  }

  /// Orb besar dengan blur, bergerak di lintasan sinus - dua sumbu dengan
  /// frekuensi berbeda supaya tidak terlihat seperti gerak linear.
  void _gambarOrb(
    Canvas canvas,
    Size size,
    Offset pusat,
    double radiusFraksi,
    Color warna,
    double opasitas,
  ) {
    const double tau = math.pi * 2;
    final double fx = math.sin(t * tau + radiusFraksi * 3) * 0.06;
    final double fy = math.cos(t * tau * 1.3 + radiusFraksi * 2) * 0.07;
    final double skala = 1 + math.sin(t * tau * 0.7) * 0.08;

    final Offset c = Offset(
      (pusat.dx + fx) * size.width,
      (pusat.dy + fy) * size.height,
    );
    final double radius = size.shortestSide * radiusFraksi * skala;

    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = warna.withValues(alpha: opasitas)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46)
        ..blendMode = BlendMode.screen,
    );
  }

  /// Grid 34 px dengan mask radial supaya memudar di tepi, digeser pelan.
  void _gambarGrid(Canvas canvas, Size size) {
    final Paint garis = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;

    final double geser = 34 * t;
    canvas.save();
    final Rect area = Offset.zero & size;
    canvas.clipRect(area);
    for (double x = -34 + geser; x < size.width + 34; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), garis);
    }
    for (double y = -34 + geser; y < size.height + 34; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), garis);
    }
    canvas.restore();

    // Mask: hanya bagian tengah yang terlihat.
    canvas.drawRect(
      area,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = const RadialGradient(
          radius: 0.78,
          colors: <Color>[const Color(0x00000000), const Color(0xFF000000)],
          stops: const <double>[0.55, 1],
        ).createShader(area),
    );
  }

  void _gambarPartikel(Canvas canvas, Size size) {
    for (final _Partikel p in _partikel) {
      final double denyut =
          (math.sin((t * p.kecepatan + p.fase) * math.pi * 2) + 1) / 2;
      if (denyut < 0.12) continue;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.ukuran * (0.7 + denyut * 0.6),
        Paint()..color = Colors.white.withValues(alpha: 0.10 + denyut * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_PelukisLatar lama) => lama.t != t;
}

class _Partikel {
  const _Partikel({
    required this.x,
    required this.y,
    required this.ukuran,
    required this.fase,
    required this.kecepatan,
  });

  final double x;
  final double y;
  final double ukuran;
  final double fase;
  final double kecepatan;
}