import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/model_ai.dart';
import 'bagian_setelan.dart';
import 'layar_setelan.dart';

/// Sub-halaman "Pengaturan Lanjut".
///
/// Isi yang tidak dipakai sehari-hari dipindah ke sini supaya halaman
/// Pengaturan utama bersih: pilihan model, uji koneksi, dan kunci API.
/// Halaman utama TIDAK lagi menampilkan nama provider apa pun (v3.0.0).
class LayarLanjutan extends ConsumerWidget {
  const LayarLanjutan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ModelAi model = ref.watch(modelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Lanjut')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          const BagianSetelan(
            judul: 'Model',
            keterangan: 'DIVJUN memilih sendiri sesuai jenis pertanyaan.',
            ikon: LucideIcons.brain,
          ),
          KartuSetelan(
            anak: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(model.label),
                subtitle: const Text('Diganti otomatis bila perlu.'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final List<ModelAi>? pilih =
                      await tampilkanPemilihModel(context, sekarang: model);
                  if (pilih != null && pilih.isNotEmpty) {
                    await ref.read(setelanProvider.notifier).setModel(
                          pilih.first.id,
                        );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          BagianSetelan(
            judul: 'Koneksi',
            keterangan: 'Hanya perlu diubah kalau jawaban tidak muncul.',
            ikon: LucideIcons.plug,
          ),
          KartuSetelan(
            anak: <Widget>[
              _Baris(
                ikon: LucideIcons.wifi,
                judul: 'Uji koneksi',
                keterangan: 'Cek apakah AI bisa menghubungi layanan.',
                onTap: () => context.push('/koneksi'),
              ),
              _Baris(
                ikon: LucideIcons.keyRound,
                judul: 'Kunci akses',
                keterangan: 'Masukkan kunci supaya jawaban tidak terputus.',
                onTap: () => context.push('/kunci'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Baris navigasi dengan ikon, judul, keterangan, dan tanda panah.
class _Baris extends StatelessWidget {
  const _Baris({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ikon, size: 20, color: context.cs.onSurfaceVariant),
      title: Text(judul),
      subtitle: Text(keterangan),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: onTap,
    );
  }
}