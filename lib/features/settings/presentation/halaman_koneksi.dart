import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/klien_llm.dart';
import '../../../domain/entities/model_ai.dart';

/// Halaman Koneksi: diagnosis kenapa AI tidak merespons.
///
/// Isinya: status model tersedia, tombol "Tes model" per model (request nyata
/// ke provider), tombol segarkan katalog model. Semua provider gratis tanpa
/// kunci — tidak ada kunci API yang perlu diisi.
class HalamanKoneksi extends ConsumerWidget {
  const HalamanKoneksi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ModelAi>> katalog = ref.watch(katalogModelProvider);

    final List<ModelAi> daftar = katalog.valueOrNull ?? const <ModelAi>[];
    final List<ModelAi> tanpaBayar =
        daftar.where((ModelAi m) => m.untukGratis).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Koneksi AI'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Segarkan daftar model',
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.invalidate(katalogModelProvider);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Mengambil daftar model…')),
                );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          _Blok(
            judul: 'Model',
            ikon: LucideIcons.brain,
            anak: <Widget>[
              if (katalog.isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: LinearProgressIndicator(),
                )
              else if (katalog.hasError)
                _Teks(
                  'Gagal mengambil daftar model: ${katalog.error}',
                  warna: context.cs.error,
                )
              else
                _Teks(
                  '${daftar.length} model dari provider · '
                  '${tanpaBayar.length} gratis tanpa kunci',
                ),
              const SizedBox(height: AppSpacing.sm),
              if (tanpaBayar.isEmpty)
                _Teks(
                  'Belum ada model gratis terdeteksi. Periksa internet lalu '
                  'tekan tombol segarkan.',
                  warna: context.cs.error,
                )
              else
                for (final ModelAi m in tanpaBayar.take(12))
                  _BarisUji(model: m),
            ],
          ),
          const _Blok(
            judul: 'Cara cepat',
            ikon: LucideIcons.info,
            anak: <Widget>[
              _Teks(
                'Semua model gagal biasanya karena 2 hal: (1) internet tidak '
                'aktif, (2) kuota provider habis sementara. Tekan "Tes" di '
                'atas untuk melihat penyebabnya persis.',
              ),
              SizedBox(height: AppSpacing.sm),
              _Teks(
                'Semua model gratis dan tanpa kunci API — OVHcloud '
                'Endpoints + Pollinations. Tidak ada kunci yang perlu diisi.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Blok extends StatelessWidget {
  const _Blok({required this.judul, required this.ikon, required this.anak});

  final String judul;
  final IconData ikon;
  final List<Widget> anak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(ikon, size: 16, color: context.cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(judul, style: context.teks.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...anak,
        ],
      ),
    );
  }
}

class _Teks extends StatelessWidget {
  const _Teks(this.isi, {this.warna});

  final String isi;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    return Text(
      isi,
      style: context.teks.bodySmall?.copyWith(color: warna),
    );
  }
}

class _BarisUji extends ConsumerWidget {
  const _BarisUji({required this.model});

  final ModelAi model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UjiKoneksi> hasil = ref.watch(ujiKoneksiProvider(model.id));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLow,
        borderRadius: AppRadius.br12,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Model AI', style: context.teks.bodyMedium),
              ),
              if (model.dukungAlat)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.toolSoft.withValues(alpha: 0.5),
                    borderRadius: AppRadius.br8,
                  ),
                  child: Text('agent', style: context.teks.labelSmall),
                ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.invalidate(ujiKoneksiProvider(model.id));
                },
                child: const Text('Tes'),
              ),
            ],
          ),
          hasil.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: LinearProgressIndicator(),
            ),
            error: (Object e, StackTrace _) => _Hasil(
              ok: false,
              pesan: '$e',
            ),
            data: (UjiKoneksi? u) => u == null
                ? const SizedBox.shrink()
                : _Hasil(ok: u.berhasil, pesan: '${u.pesan} (${u.ms} ms)'),
          ),
        ],
      ),
    );
  }
}

class _Hasil extends StatelessWidget {
  const _Hasil({required this.ok, required this.pesan});

  final bool ok;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ok ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            size: 14,
            color: ok ? context.cs.secondary : context.cs.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              pesan,
              style: context.teks.labelSmall?.copyWith(
                color: ok ? context.cs.onSurfaceVariant : context.cs.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
