import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// Judul bagian (A, B, C, ...) dengan ikon dan keterangan singkat.
///
/// Pemisahan judul dari isi penting: isi tiap bagian bisa tinggi berbeda
/// (slider, daftar tombol) tanpa membuat header ikut memanjang.
class BagianSetelan extends StatelessWidget {
  const BagianSetelan({
    required this.judul,
    required this.keterangan,
    required this.ikon,
  });

  final String judul;
  final String keterangan;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(ikon, size: 15, color: context.cs.primary),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                judul.toUpperCase(),
                style: context.teks.labelMedium?.copyWith(
                  letterSpacing: 0.9,
                  color: context.cs.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(keterangan, style: context.teks.labelSmall),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Wadah isi bagian: background sedikit beda + garis tipis pemisah.
///
/// Inilah yang membuat lima bagian A-E terlihat terpisah jelas, tanpa perlu
/// garis tebal atau jarak besar di antaranya.
class KartuSetelan extends StatelessWidget {
  const KartuSetelan({required this.anak});

  final List<Widget> anak;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLow,
        borderRadius: AppRadius.br16,
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(children: anak),
    );
  }
}

/// Sakelar satu baris dengan keterangan singkat.
class SakelarSetelan extends StatelessWidget {
  const SakelarSetelan({
    required this.judul,
    required this.nilai,
    required this.onChanged,
    this.keterangan,
  });

  final String judul;
  final String? keterangan;
  final bool nilai;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: nilai,
      onChanged: onChanged,
      title: Text(judul),
      subtitle: keterangan == null ? null : Text(keterangan!),
    );
  }
}

/// Baris navigasi dengan tanda panah ke kanan.
///
/// [bahaya] memberi warna merah untuk aksi yang menghapus - dipakai tombol
/// "Hapus Semua Riwayat Chat".
class BarisSetelan extends StatelessWidget {
  const BarisSetelan({
    required this.judul,
    required this.onTap,
    this.keterangan,
    this.ikon,
    this.bahaya = false,
  });

  final String judul;
  final String? keterangan;
  final IconData? ikon;
  final VoidCallback onTap;
  final bool bahaya;

  @override
  Widget build(BuildContext context) {
    final Color warna = bahaya ? context.cs.error : context.cs.onSurface;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ikon == null ? null : Icon(ikon, size: 20, color: warna),
      title: Text(judul, style: TextStyle(color: warna)),
      subtitle: keterangan == null ? null : Text(keterangan!),
      trailing: Icon(LucideIcons.chevronRight, size: 18),
      onTap: onTap,
    );
  }
}

/// Tombol besar berwarna merah untuk aksi merusak.
class TombolBahaya extends StatelessWidget {
  const TombolBahaya({
    required this.judul,
    required this.onTap,
    this.keterangan,
  });

  final String judul;
  final String? keterangan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(LucideIcons.trash2, size: 18),
      label: Text(judul),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.cs.error,
        side: BorderSide(color: context.cs.error.withValues(alpha: 0.5)),
        minimumSize: const Size.fromHeight(46),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br12),
      ),
    );
  }
}