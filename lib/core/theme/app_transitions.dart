import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_colors.dart';

/// Transisi antar halaman DIVJUN.
///
/// Tiga rasa, dipilih sesuai hubungan antar layar:
///
/// - [portal]: untuk perpindahan "menuju dunia baru" (onboarding -> chat).
///   Layar lama melesat ke depan sambil memudar, layar baru datang dari
///   sedikit lebih jauh lalu menapak. Dua arah dihitung dari satu
///   [transitionsBuilder], jadi transisi masuk dan transisi keluar TIDAK
///   saling menimpa: dua widget terpisah hanya akan menimpa satu arah.
/// - [halus]: untuk halaman turunan (chat -> pengaturan). Geser kecil + fade,
///   supaya navigasi sehari-hari tidak terasa dramatis.
/// - [langsung]: durasi nol, untuk halaman yang memang tidak boleh beranimasi.
///
/// Semuanya [CustomTransitionPage]: animasi milik route, bukan milik widget
/// di dalam layar, jadi tidak ikut diputar ulang saat Riverpod rebuild.
abstract final class AppTransisi {
  static const Duration durasiPortal = Duration(milliseconds: 620);
  static const Duration durasiHalus = Duration(milliseconds: 300);

  /// Arah "dunia baru": masuk dari jauh (1.10) dan keluar melesat (1.28).
  ///
  /// [animasi] = 0..1 saat halaman MASUK, [sekunder] = 0..1 saat halaman
  /// KELUAR. Keduanya digabung dengan nilai terbesar supaya tidak saling
  /// menimpa.
  static Widget portal(
    BuildContext context,
    Animation<double> animasi,
    Animation<double> sekunder,
    Widget child,
  ) {
    final double scale = math.max(
      1.10 - (0.10 * animasi.value),
      1 + (0.28 * sekunder.value),
    );
    final double opacity = math.max(animasi.value, 1 - sekunder.value);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(scale: scale, alignment: Alignment.center, child: child),
    );
  }

  /// Muncul dari bawah sedikit + fade - untuk halaman turunan.
  static Widget halus(
    BuildContext context,
    Animation<double> animasi,
    Animation<double> sekunder,
    Widget child,
  ) {
    final double opacity = math.max(animasi.value, 1 - sekunder.value);
    final double geser = math.max(0.05 * (1 - animasi.value), 0.05 * sekunder.value);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, geser),
        child: child,
      ),
    );
  }

  static Widget langsung(
    BuildContext context,
    Animation<double> animasi,
    Animation<double> sekunder,
    Widget child,
  ) =>
      child;

  /// Bungkus route biasa (splash, pengaturan, skill, memori).
  static CustomTransitionPage<T> halaman<T extends Object?>(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      transitionDuration: durasiHalus,
      reverseTransitionDuration: durasiHalus,
      child: child,
      transitionsBuilder: halus,
    );
  }

  /// Bungkus route "dunia baru" (onboarding, chat).
  static CustomTransitionPage<T> portalPage<T extends Object?>(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      transitionDuration: durasiPortal,
      reverseTransitionDuration: durasiPortal,
      child: child,
      transitionsBuilder: portal,
    );
  }

  /// Warna ledakan transisi - dipakai overlay ledakan cahaya di onboarding.
  static const List<Color> warnaPortal = <Color>[
    AppColors.mint,
    AppColors.brand,
    Color(0xFF6E6EF0),
  ];
}
