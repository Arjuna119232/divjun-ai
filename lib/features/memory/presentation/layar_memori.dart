import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/teks.dart';
import '../../../core/utils/waktu.dart';
import '../../../domain/entities/memori.dart';
import '../../chat/presentation/widgets/lembar_riwayat.dart';
import '../../settings/presentation/layar_setelan.dart';

/// Layar memori jangka panjang: cari, tambah, hapus, bersihkan.
class LayarMemori extends ConsumerStatefulWidget {
  const LayarMemori({super.key});

  @override
  ConsumerState<LayarMemori> createState() => _LayarMemoriState();
}

class _LayarMemoriState extends ConsumerState<LayarMemori> {
  final TextEditingController _cari = TextEditingController();
  String _kategori = 'semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memoriProvider.notifier).muat();
    });
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<EntriMemori> semua = ref.watch(memoriProvider);
    final String q = _cari.text.trim().toLowerCase();
    final List<EntriMemori> daftar = <EntriMemori>[
      for (final EntriMemori e in semua)
        if ((_kategori == 'semua' || e.kategori == _kategori) &&
            (q.isEmpty || e.isi.toLowerCase().contains(q)))
          e,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memori'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Tambah memori',
            icon: const Icon(LucideIcons.plus, size: 20),
            onPressed: _tambah,
          ),
          IconButton(
            tooltip: 'Bersihkan semua',
            icon: const Icon(LucideIcons.trash2, size: 20),
            onPressed: semua.isEmpty
                ? null
                : () async {
                    final bool ya = await konfirmasi(
                      context,
                      judul: 'Hapus semua memori?',
                      pesan:
                          '${semua.length} entri akan dihapus permanen dari '
                          'perangkat ini.',
                      labelYa: 'Hapus semua',
                    );
                    if (ya) {
                      await ref.read(memoriProvider.notifier).hapusSemua();
                    }
                  },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _cari,
              onChanged: (String _) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari memori…',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _cari.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () {
                          _cari.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: <Widget>[
                _Chip(
                  label: 'Semua',
                  aktif: _kategori == 'semua',
                  onTap: () => setState(() => _kategori = 'semua'),
                ),
                for (final String k in KategoriMemori.semua)
                  _Chip(
                    label: KategoriMemori.label(k),
                    aktif: _kategori == k,
                    onTap: () => setState(() => _kategori = k),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: daftar.isEmpty
                ? _Kosong(
                    pesan: semua.isEmpty
                        ? 'Belum ada memori. AI akan mengingat fakta saat '
                            'kamu bilang "ingat ini".'
                        : 'Tidak ada entri yang cocok dengan pencarian.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                    itemCount: daftar.length,
                    separatorBuilder: (BuildContext _, int __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) {
                      final EntriMemori e = daftar[i];
                      return Dismissible(
                        key: ValueKey<String>(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: context.cs.error.withValues(alpha: 0.14),
                            borderRadius: AppRadius.br12,
                          ),
                          child: Icon(LucideIcons.trash2,
                              size: 20, color: context.cs.error),
                        ),
                        onDismissed: (DismissDirection _) async {
                          HapticFeedback.lightImpact();
                          await ref
                              .read(memoriProvider.notifier)
                              .hapus(e.id);
                        },
                        child: _KartuMemori(entri: e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _tambah() async {
    final String? isi = await tampilkanEditor(
      context,
      judul: 'Tambah memori',
      awal: '',
      konfirmasi: 'Simpan',
      hint: 'Contoh: Nama saya Budi, kerjaan di Jakarta',
      multiline: true,
    );
    if (isi == null || isi.trim().isEmpty) return;
    await ref.read(memoriProvider.notifier).simpan(isi.trim(), 'umum');
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.aktif,
    required this.onTap,
  });

  final String label;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: aktif,
        showCheckmark: false,
        onSelected: (bool _) => onTap(),
      ),
    );
  }
}

class _KartuMemori extends StatelessWidget {
  const _KartuMemori({required this.entri});

  final EntriMemori entri;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLow,
        borderRadius: AppRadius.br16,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.cs.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.br8,
                ),
                child: Text(
                  KategoriMemori.label(entri.kategori),
                  style: context.teks.labelSmall
                      ?.copyWith(color: context.cs.primary),
                ),
              ),
              const Spacer(),
              Text(
                Waktu.relatif(entri.dibuat),
                style: context.teks.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(entri.isi, style: context.teks.bodyMedium),
          if (entri.dipakai > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Dipakai ${entri.dipakai}× dalam jawaban',
              style: context.teks.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              LucideIcons.brain,
              size: 40,
              color: context.cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              pesan,
              textAlign: TextAlign.center,
              style: context.teks.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
