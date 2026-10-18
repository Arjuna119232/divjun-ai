import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_theme.dart';

/// Pose robot pada gambar cadangan.
enum PoseRobotGambar { melambai, berpikir, bekerja, mengingat }

/// Area aset robot untuk onboarding + halaman login.
///
/// Memakai Lottie kalau berkasnya benar-benar ada di bundle. Kalau belum
/// (aset diunduh sendiri nanti), `errorBuilder` menurunkan ke [RobotGambar] -
/// robot yang digambar kode dan tetap beranimasi. Jadi layar ini tidak pernah
/// menampilkan kotak kosong atau error merah hanya karena satu aset belum ada.
class AsetRobot extends StatelessWidget {
  const AsetRobot({
    super.key,
    required this.berkas,
    this.pose = PoseRobotGambar.melambai,
    this.ukuran = 190,
  });

  /// Path asset, mis. `assets/animations/robot_waving.json`.
  final String berkas;

  /// Pose gambar cadangan.
  final PoseRobotGambar pose;

  /// Sisi area (lebar = tinggi), selalu proporsional.
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: Lottie.asset(
        berkas,
        repeat: true,
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object e, StackTrace? s) =>
            RobotGambar(pose: pose),
      ),
    );
  }
}

/// Robot cadangan: digambar penuh dengan [CustomPainter] + satu
/// [AnimationController], jadi tidak butuh aset apa pun.
class RobotGambar extends StatefulWidget {
  const RobotGambar({super.key, this.pose = PoseRobotGambar.melambai});

  final PoseRobotGambar pose;

  @override
  State<RobotGambar> createState() => _RobotGambarState();
}

class _RobotGambarState extends State<RobotGambar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

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
        builder: (BuildContext context, Widget? _) => CustomPaint(
          size: Size.infinite,
          painter: _RobotPainter(t: _c.value, pose: widget.pose),
        ),
      ),
    );
  }
}

/// Sudut lengan dipakai searah jarum jam, 0 = lurus ke bawah, negatif =
/// terangkat. Panjang ikut per-pose supaya tangan bisa menyentuh kepala.
class _Lengan {
  const _Lengan(this.sudut, this.panjang);

  final double sudut;
  final double panjang;
}

class _RobotPainter extends CustomPainter {
  const _RobotPainter({required this.t, required this.pose});

  /// 0..1 berulang.
  final double t;
  final PoseRobotGambar pose;

  _Lengan get _kiri => switch (pose) {
    PoseRobotGambar.melambai => const _Lengan(0.30, 24),
    PoseRobotGambar.berpikir => const _Lengan(0.45, 24),
    PoseRobotGambar.bekerja => const _Lengan(1.05, 24),
    PoseRobotGambar.mengingat => const _Lengan(0.35, 24),
  };

  _Lengan get _kanan => switch (pose) {
    PoseRobotGambar.melambai => _Lengan(-2.45 + _ayunan, 26),
    // Tangan dekat dagu = "berpikir".
    PoseRobotGambar.berpikir => const _Lengan(-2.80, 18),
    PoseRobotGambar.bekerja => const _Lengan(-1.05, 24),
    PoseRobotGambar.mengingat => const _Lengan(-2.30, 26),
  };

  /// Ayunan tangan, hanya untuk pose melambai.
  double get _ayunan => math.sin(t * 2 * math.pi) * 0.38;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide / 100;
    canvas.save();
    canvas.translate(
      size.width / 2,
      size.height / 2 + math.sin(t * 2 * math.pi) * 1.2 * s,
    );
    canvas.scale(s);

    _cahaya(canvas);
    _bayangan(canvas);
    _leher(canvas);
    _badan(canvas);
    // Lengan digambar SESUDAH badan: kalau sebelum, panjang lengan tertutup
    // badan dan yang terlihat hanya dua tonjolan kecil di bawah -
    // persis bug yang ketahuan dari render pratinjau.
    _lengan(canvas, -20, 11, _kiri);
    _lengan(canvas, 20, 11, _kanan);
    _kepala(canvas);
    _penandaPose(canvas);

    canvas.restore();
  }

  void _cahaya(Canvas canvas) {
    canvas.drawCircle(
      Offset.zero,
      40,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.brand.withValues(alpha: 0.30),
            Colors.transparent,
          ],
        ).createShader(const Rect.fromCircle(center: Offset.zero, radius: 40)),
    );
  }

  void _bayangan(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 44), width: 42, height: 7),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
  }

  void _leher(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-7, -10, 14, 16),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.brandDeep,
    );
  }

  void _lengan(Canvas canvas, double x, double y, _Lengan l) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(l.sudut);
    canvas.drawLine(
      Offset.zero,
      Offset(0, l.panjang),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.brandDeep,
    );
    // Bahu + tangan: dua lingkaran supaya sambungan tidak terlihat terpotong.
    canvas.drawCircle(Offset.zero, 3.6, Paint()..color = AppColors.brandDeep);
    canvas.drawCircle(
      Offset(0, l.panjang),
      4.2,
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  void _badan(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, 2, 40, 34),
        const Radius.circular(11),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.brand, AppColors.brandDeep],
        ).createShader(const Rect.fromLTWH(-20, 2, 40, 34)),
    );
    final Rect layar = const Rect.fromLTWH(-14, 9, 28, 15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(layar, const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(layar, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.30),
    );
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'DIVJUN AI',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontFamily: AppTypography.ui,
          fontSize: 6.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, layar.top + 4.3));

    canvas.drawCircle(
      const Offset(0, 29),
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _kepala(Canvas canvas) {
    canvas.drawLine(
      const Offset(0, -32),
      const Offset(0, -40),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.brandDeep,
    );
    canvas.drawCircle(const Offset(0, -42), 3, Paint()..color = AppColors.mint);

    final Rect kepala = const Rect.fromLTWH(-19, -32, 38, 26);
    canvas.drawRRect(
      RRect.fromRectAndRadius(kepala, const Radius.circular(9)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Colors.white, AppColors.brandSoft],
        ).createShader(kepala),
    );

    final Rect visor = const Rect.fromLTWH(-14, -27, 28, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(visor, const Radius.circular(6)),
      Paint()..color = AppColors.inkDark.withValues(alpha: 0.88),
    );
    final bool kedip = (t % 1) > 0.94;
    final double tinggiMata = kedip ? 0.8 : 3.1;
    for (final double x in <double>[-6.2, 6.2]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, -20),
            width: 4.4,
            height: tinggiMata * 2,
          ),
          const Radius.circular(2.2),
        ),
        Paint()..color = AppColors.mint,
      );
    }
  }

  /// Penanda kecil yang menjelaskan pose: gelembung pikiran saat berpikir,
  /// kilau saat mengerjakan, tanda centang kecil saat mengingat.
  void _penandaPose(Canvas canvas) {
    switch (pose) {
      case PoseRobotGambar.berpikir:
        for (int i = 0; i < 3; i++) {
          final double f = (t * 3 + i * 0.25) % 1;
          final double r = 1.5 + i * 0.8;
          canvas.drawCircle(
            Offset(12 + i * 7, -40 - f * 9),
            r,
            Paint()
              ..color = AppColors.mint.withValues(
                alpha: (0.75 - f * 0.6).clamp(0.0, 1.0),
              ),
          );
        }
      case PoseRobotGambar.bekerja:
        final Paint kilau = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = AppColors.mint.withValues(alpha: 0.85);
        final double denyut = 0.7 + (0.3 * math.sin(t * 2 * math.pi));
        final Offset p = Offset(37, 12);
        canvas.drawLine(p.translate(-7, 0), p.translate(-7, 4), kilau);
        canvas.drawLine(p.translate(-7, 0), p.translate(-3, 0), kilau);
        canvas.drawLine(p.translate(7, 0), p.translate(7, 4), kilau);
        canvas.drawLine(p.translate(7, 0), p.translate(3, 0), kilau);
        canvas.drawCircle(
          p,
          6 * denyut,
          Paint()..color = AppColors.mint.withValues(alpha: 0.10),
        );
      case PoseRobotGambar.mengingat:
        final Paint c = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = AppColors.mint.withValues(alpha: 0.9);
        canvas.drawLine(const Offset(37, -13), const Offset(42, -8), c);
        canvas.drawLine(const Offset(42, -8), const Offset(48, -17), c);
      case PoseRobotGambar.melambai:
        break;
    }
  }

  @override
  bool shouldRepaint(_RobotPainter lama) => lama.t != t || lama.pose != pose;
}