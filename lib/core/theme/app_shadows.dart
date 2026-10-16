import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Bayangan lembut (elevation rendah, warna brand kehitaman tipis)
/// supaya terasa modern, bukan card abu-abu tua.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x4D5B5BD6),
      blurRadius: 28,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> bubble(Color warna) => [
        BoxShadow(
          color: warna.withValues(alpha: 0.22),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> none() => const [];

  static Color scrim(BuildContext c) =>
      c.brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.62)
          : AppColors.inkLight.withValues(alpha: 0.38);
}
