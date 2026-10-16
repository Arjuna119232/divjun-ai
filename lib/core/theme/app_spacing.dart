import 'package:flutter/widgets.dart';

/// Skala spasi 4pt + radius. Semua jarak di UI harus pakai token ini,
/// bukan angka mentah, supaya rasio antar layar konsisten.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets pad4 = EdgeInsets.all(xxs);
  static const EdgeInsets pad8 = EdgeInsets.all(sm);
  static const EdgeInsets pad12 = EdgeInsets.all(md);
  static const EdgeInsets pad16 = EdgeInsets.all(lg);
  static const EdgeInsets pad20 = EdgeInsets.all(xl);
  static const EdgeInsets pad24 = EdgeInsets.all(xxl);

  static const EdgeInsets h16 = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets v8 = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets v16 = EdgeInsets.symmetric(vertical: lg);

  static const EdgeInsets topSheet = EdgeInsets.fromLTRB(lg, sm, lg, lg);
}

abstract final class AppRadius {
  static const Radius r8 = Radius.circular(8);
  static const Radius r12 = Radius.circular(12);
  static const Radius r14 = Radius.circular(14);
  static const Radius r16 = Radius.circular(16);
  static const Radius r20 = Radius.circular(20);
  static const Radius r28 = Radius.circular(28);

  static const BorderRadius br8 = BorderRadius.all(r8);
  static const BorderRadius br12 = BorderRadius.all(r12);
  static const BorderRadius br14 = BorderRadius.all(r14);
  static const BorderRadius br16 = BorderRadius.all(r16);
  static const BorderRadius br20 = BorderRadius.all(r20);
  static const BorderRadius br28 = BorderRadius.all(r28);

  /// Bubble chat: sisi yang dekat "ekor" pesan lebih kecil.
  static BorderRadius bubble({required bool isUser}) => BorderRadius.only(
        topLeft: isUser ? const Radius.circular(6) : r20,
        topRight: isUser ? r20 : const Radius.circular(6),
        bottomLeft: r20,
        bottomRight: r20,
      );

  /// Bottom sheet + dialog (pill besar = gaya 2026).
  static const BorderRadius sheet = BorderRadius.vertical(top: r28);
  static const BorderRadius dialog = BorderRadius.all(r20);
}
