import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/artifak.dart';

/// Kartu blok kode di dalam jawaban AI.
///
/// Blok yang bisa dipratinjau (HTML/SVG/Markdown) mendapat tombol "Buka";
/// kode biasa hanya "Lihat" (layar penuh, teks bisa disalin per bagian).
/// Selama jawaban masih mengalir ([Artifak.terbuka]) tombolnya dimatikan —
/// pratinjau dokumen setengah jadi hanya bikin bingung.
class KartuArtifak extends StatelessWidget {
  const KartuArtifak({super.key, required this.artifak});

  final Artifak artifak;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = context.cs;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color latar =
        gelap ? cs.surfaceContainerHigh : cs.surfaceContainerLowest;
    final Color garis = cs.outlineVariant.withValues(alpha: 0.55);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: latar,
        borderRadius: AppRadius.br14,
        border: Border.all(color: garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Kepala(
            artifak: artifak,
            onBuka: () => _buka(context),
            onSalin: () => _salin(context),
          ),
          if (artifak.isi.trim().isNotEmpty) ...<Widget>[
            Divider(height: 1, thickness: 1, color: garis),
            _Cuplikan(artifak: artifak),
          ],
          _Kaki(artifak: artifak, onBuka: () => _buka(context)),
        ],
      ),
    );
  }

  void _buka(BuildContext context) {
    if (artifak.terbuka) return;
    context.push<void>('/artifak', extra: artifak);
  }

  Future<void> _salin(BuildContext context) async {
    final ScaffoldMessengerState pesan = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: artifak.isi));
    pesan
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Kode disalin')));
  }
}

class _Kepala extends StatelessWidget {
  const _Kepala({
    required this.artifak,
    required this.onBuka,
    required this.onSalin,
  });

  final Artifak artifak;
  final VoidCallback onBuka;
  final VoidCallback onSalin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = context.cs;
    return InkWell(
      onTap: onBuka,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                borderRadius: AppRadius.br8,
              ),
              child: Icon(
                artifak.jenis == JenisArtifak.kode
                    ? LucideIcons.code
                    : LucideIcons.fileCode,
                size: 16,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    artifak.judul,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.teks.labelLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    artifak.terbuka
                        ? '${artifak.label} · menulis...'
                        : '${artifak.label} · ${artifak.jumlahBaris} baris',
                    style: context.teks.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSalin,
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              tooltip: 'Salin kode',
              icon: Icon(LucideIcons.copy, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beberapa baris pertama isi blok. Bukan pratinjau penuh — cukup untuk
/// memutuskan "perlu dibuka atau tidak".
class _Cuplikan extends StatelessWidget {
  const _Cuplikan({required this.artifak});

  final Artifak artifak;

  static const int _maksBaris = 8;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = context.cs;
    final List<String> baris = artifak.isi.trimRight().split('\n');
    final bool dipotong = baris.length > _maksBaris;
    final String isi = dipotong
        ? '${baris.take(_maksBaris).join('\n')}\n...'
        : baris.join('\n');

    return Container(
      width: double.infinity,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        isi,
        maxLines: _maksBaris + 1,
        overflow: TextOverflow.clip,
        softWrap: true,
        style: TextStyle(
          fontFamily: AppTypography.monoFamily,
          fontSize: 12,
          height: 1.45,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Kaki extends StatelessWidget {
  const _Kaki({required this.artifak, required this.onBuka});

  final Artifak artifak;
  final VoidCallback onBuka;

  @override
  Widget build(BuildContext context) {
    final bool aktif = !artifak.terbuka;
    final IconData ikon =
        artifak.bisaPratinjau ? LucideIcons.maximize2 : LucideIcons.code;
    final String label = artifak.bisaPratinjau ? 'Buka' : 'Lihat kode';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            onPressed: aktif ? onBuka : null,
            icon: Icon(ikon, size: 15),
            label: Text(label),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: context.teks.labelMedium,
            ),
          ),
          if (artifak.bisaPratinjau) ...<Widget>[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                'dibuka di dalam app',
                style: context.teks.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
