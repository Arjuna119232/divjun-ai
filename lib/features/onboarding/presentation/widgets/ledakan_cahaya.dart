import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Ledakan cahaya saat keluar dari halaman onboarding terakhir.
///
/// Dua cincin yang melebar + satu kilatan putih di tengah. Efeknya membaca
/// sebagai "portal terbuka ke dunia baru", bukan sekadar layar hilang.
///
/// [animasi] 0..1. Catatan: memakai controller milik layar onboarding, BUKAN
/// controller sendiri, supaya ledakan dan zoom halaman tetap sinkron persis.
/// Dua controller terpisah akan melesat barengan tapi tidak pernah tepat
/// sama waktunya.
class LedakanCahaya extends StatelessWidget {
  const LedakanCahaya({super.key, required this.animasi});

  final Animation<double> animasi;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animasi,
          builder: (BuildContext context, Widget? _) =>
              CustomPaint(painter: _PelukisLedakan(animasi.value), size: Size.infinite),
        ),
      ),
    );
  }
}

class _PelukisLedakan extends CustomPainter {
  _PelukisLedakan(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final Offset pusat = Offset(size.width / 2, size.height * 0.46);
    final double radiusMaks = size.longestSide * 0.95;

    // Kilatan awal: cepat naik, lalu menghilang. Tanpa ini cincin terasa
    // "ditempel", bukan meledak.
    final double kilat = (1 - (t / 0.22)).clamp(0.0, 1.0);
    if (kilat > 0) {
      canvas.drawCircle(
        pusat,
        radiusMaks * 0.5,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.34 * kilat),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: pusat, radius: radiusMaks * 0.5),
          ),
      );
    }

    // Dua cincin: yang kedua sedikit tertinggal supaya terasa beruntun.
    _cincin(canvas, pusat, radiusMaks, t.clamp(0.0, 1.0), 0);
    _cincin(
      canvas,
      pusat,
      radiusMaks,
      ((t - 0.16) / 0.84).clamp(0.0, 1.0),
      1,
    );
  }

  void _cincin(Canvas canvas, Offset pusat, double radiusMaks, double p, int urutan) {
    if (p <= 0) return;
    final double eased = Curves.easeOutCubic.transform(p);
    final double radius = radiusMaks * eased;
    final double alpha = (1 - p) * (urutan == 0 ? 0.75 : 0.45);
    if (alpha <= 0.01) return;

    final Rect kotak = Rect.fromCircle(center: pusat, radius: radius);
    canvas.drawCircle(
      pusat,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, 26 * (1 - eased))
        ..shader = SweepGradient(
          colors: <Color>[
            AppTransisi.warnaPortal[0].withValues(alpha: alpha),
            AppTransisi.warnaPortal[1].withValues(alpha: alpha),
            AppTransisi.warnaPortal[2].withValues(alpha: alpha),
            AppTransisi.warnaPortal[0].withValues(alpha: alpha),
          ],
          transform: const GradientRotation(0),
        ).createShader(kotak),
    );
  }

  @override
  bool shouldRepaint(_PelukisLedakan lama) => lama.t != t;
}
