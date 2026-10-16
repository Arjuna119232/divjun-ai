import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_env.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/klien_llm.dart';
import '../../../domain/entities/model_ai.dart';
import '../../../domain/entities/setelan.dart';

/// Halaman Koneksi: diagnosis kenapa AI tidak merespons.
///
/// Isinya: status kunci per provider, isi/ubah kunci, tombol "Tes model"
/// per model (request nyata ke provider), tombol segarkan katalog model.
class HalamanKoneksi extends ConsumerWidget {
  const HalamanKoneksi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SetelanApp setelan = ref.watch(setelanProvider);
    final SetelanController c = ref.read(setelanProvider.notifier);
    final AsyncValue<List<ModelAi>> katalog = ref.watch(katalogModelProvider);
    final String kunciGroq = ref.watch(kunciGroqAktifProvider);
    final String kunciGemini = ref.watch(kunciGeminiAktifProvider);

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
            judul: 'Status kunci API',
            ikon: LucideIcons.key,
            anak: <Widget>[
              _BarisKunci(
                nama: 'Groq',
                terisi: kunciGroq.trim().isNotEmpty,
                dariBuild: setelan.kunciGroq.trim().isEmpty &&
                    AppEnv.groqApiKey.trim().isNotEmpty,
              ),
              const SizedBox(height: AppSpacing.md),
              _BarisKunci(
                nama: 'Gemini',
                terisi: kunciGemini.trim().isNotEmpty,
                dariBuild: setelan.kunciGemini.trim().isEmpty &&
                    AppEnv.geminiApiKey.trim().isNotEmpty,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonalIcon(
                onPressed: () => context.push('/kunci'),
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const Text('Masukkan / ganti kunci API'),
              ),
            ],
          ),
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
                  '${tanpaBayar.length} bisa dipakai kunci gratis',
                ),
              const SizedBox(height: AppSpacing.sm),
              if (tanpaBayar.isEmpty)
                _Teks(
                  'Belum ada model gratis terdeteksi. Perbarui kunci API lalu '
                  'tekan tombol segarkan.',
                  warna: context.cs.error,
                )
              else
                for (final ModelAi m in tanpaBayar.take(12))
                  _BarisUji(model: m),
            ],
          ),
          _Blok(
            judul: 'Cara cepat',
            ikon: LucideIcons.info,
            anak: <Widget>[
              const _Teks(
                'Semua model gagal biasanya karena 3 hal: (1) kunci API kosong '
                'atau kadaluarsa, (2) model yang dipilih hanya tersedia di '
                'paket berbayar, (3) kuota provider habis. Tekan "Tes" di '
                'atas untuk melihat penyebabnya persis.',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _Teks(
                'Kunci gratis: Groq (console.groq.com) dan Gemini '
                '(aistudio.google.com) - keduanya tanpa kartu kredit.',
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

class _BarisKunci extends StatelessWidget {
  const _BarisKunci({
    required this.nama,
    required this.terisi,
    required this.dariBuild,
  });

  final String nama;
  final bool terisi;
  final bool dariBuild;

  @override
  Widget build(BuildContext context) {
    final Color warna =
        terisi ? context.cs.secondary : context.cs.error;
    return Row(
      children: <Widget>[
        Icon(
          terisi ? LucideIcons.circleCheck : LucideIcons.circleAlert,
          size: 16,
          color: warna,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('$nama', style: context.teks.bodyMedium),
        ),
        Text(
          terisi
              ? (dariBuild ? 'terpasang saat build' : 'diisi di aplikasi')
              : 'belum diisi',
          style: context.teks.labelSmall?.copyWith(color: warna),
        ),
      ],
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
                child: Text(model.label, style: context.teks.bodyMedium),
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
