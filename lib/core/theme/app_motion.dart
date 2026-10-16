import 'package:flutter/animation.dart';

/// Token gerak. Satu tempat supaya semua animasi punya "watak" yang sama:
/// masuk cepat ( emphasised ), keluar lembut.
abstract final class AppMotion {
  static const Duration instan = Duration(milliseconds: 90);
  static const Duration cepat = Duration(milliseconds: 160);
  static const Duration sedang = Duration(milliseconds: 260);
  static const Duration lambat = Duration(milliseconds: 420);
  static const Duration sangatLambat = Duration(milliseconds: 620);

  ///-loop untuk shimmer skeleton.
  static const Duration shimmer = Duration(milliseconds: 1250);

  static const Curve masuk = Curves.easeOutCubic;
  static const Curve keluar = Curves.easeInCubic;
  static const Curve elas = Curves.easeOutBack;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve smooth = Curves.easeInOutSine;

  static const Duration d20 = Duration(milliseconds: 20);
  static const Duration d40 = Duration(milliseconds: 40);
}
