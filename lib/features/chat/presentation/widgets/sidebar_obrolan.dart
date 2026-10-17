import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_env.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/kontrol_chat.dart';
import '../../../../domain/entities/model_ai.dart';
import '../../../../domain/entities/percakapan.dart';
import '../../../../domain/entities/setelan.dart';

/// Sidebar ala Claude: daftar percakapan di kiri, pencarian, dan navigasi.
///
/// Bedanya dengan bottom sheet riwayat lama: ini drawer yang bisa dibuka dari
/// mana saja lewat tombol hamburger, daftar dikelompokkan berdasarkan waktu
/// (hari ini / 7 hari / bulan ini / lebih lama), dan footer berisi pintasan
/// ke Pustaka Skill, Memori, Koneksi, dan Pengaturan - supaya semuaexpert
/// yang sudah ada di app bisa dijangkau dalam satu goresan.
class SidebarObrolan extends ConsumerStatefulWidget {
  const SidebarObrolan({super.key});

  @override
  ConsumerStatefulWidget createState() => _SidebarObrolanState();
}

class _SidebarObrolanState extends ConsumerState<SidebarObrolan> {
  final TextEditingController _cari = TextEditingController();

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StateChat state = ref.watch(chatProvider);
    final SetelanApp setelan = ref.watch(setelanProvider);
    final ModelAi model = ref.watch(modelProvider);
    final String q = _cari.text.trim().toLowerCase();
    final List<Percakapan> semua = <Percakapan>[
      for (final Percakapan p in state.daftar)
        if (p.judul.isNotEmpty &&
            (q.isEmpty || p.judul.toLowerCase().contains(q)))
          p,
    ]..sort((Percakapan a, Percakapan b) =>
        b.diperbarui.compareTo(a.diperbarui));

    final DateTime sekarang = DateTime.now();
    bool hariIni(DateTime d) =>
        d.year == sekarang.year &&
        d.month == sekarang.month &&
        d.day == sekarang.day;

    final DateTime tujuhHariLalu =
        sekarang.subtract(const Duration(days: 7));
    final DateTime awalBulan = DateTime(sekarang.year, sekarang.month, 1);

    final List<Percakapan> gHariIni = <Percakapan>[
      for (final Percakapan p in semua)
        if (hariIni(p.diperbarui)) p,
    ];
    final List<Percakapan> gTujuh = <Percakapan>[
      for (final Percakapan p in semua)
        if (!hariIni(p.diperbarui) && p.diperbarui.isAfter(tujuhHariLalu)) p,
    ];
    final List<Percakapan> gBulan = <Percakapan>[
      for (final Percakapan p in semua)
        if (!hariIni(p.diperbarui) &&
            !p.diperbarui.isAfter(tujuhHariLalu) &&
            p.diperbarui.isAfter(awalBulan))
          p,
    ];
    final List<Percakapan> gLama = <Percakapan>[
      for (final Percakapan p in semua)
        if (!p.diperbarui.isAfter(awalBulan)) p,
    ];

    return Drawer(
      width: 312,
      backgroundColor: context.cs.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: context.cs.primary,
                      borderRadius: AppRadius.br12,
                    ),
                    child: Center(
                      child: Text(
                        'D',
                        style: context.teks.titleSmall?.copyWith(
                          color: context.cs.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppConfig.appName,
                          style: context.teks.titleSmall,
                        ),
                        Text(model.label, style: context.teks.labelSmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: FilledButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await ref.read(chatProvider.notifier).buatPercakapanBaru();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.squarePen, size: 18),
                label: const Text('Chat baru'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _cari,
                onChanged: (_) => setState(() {}),
                style: AppTypography.mono(size: 13),
                decoration: InputDecoration(
                  hintText: 'Cari percakapan',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: semua.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          q.isEmpty
                              ? 'Belum ada percakapan.\nMulai dari kolom pesan.'
                              : 'Tidak ada yang cocok "$q".',
                          textAlign: TextAlign.center,
                          style: context.teks.bodySmall,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSpacing.lg,
                      ),
                      children: <Widget>[
                        _Kelompok(
                          judul: 'Hari ini',
                          items: gHariIni,
                          onPilih: _pilih,
                          ref: ref,
                        ),
                        _Kelompok(
                          judul: '7 hari terakhir',
                          items: gTujuh,
                          onPilih: _pilih,
                          ref: ref,
                        ),
                        _Kelompok(
                          judul: 'Bulan ini',
                          items: gBulan,
                          onPilih: _pilih,
                          ref: ref,
                        ),
                        _Kelompok(
                          judul: 'Lebih lama',
                          items: gLama,
                          onPilih: _pilih,
                          ref: ref,
                        ),
                      ],
                    ),
            ),
            Divider(height: 1, color: context.cs.outlineVariant),
            _Menu(
              ikon: LucideIcons.bookOpen,
              label: 'Pustaka skill',
              detail: '111 panduan kerja di dalam app',
              onTap: () => _pergi(context, '/skills'),
            ),
            _Menu(
              ikon: LucideIcons.brain,
              label: 'Memori',
              detail: 'Yang diingat lintas percakapan',
              onTap: () => _pergi(context, '/memori'),
            ),
            _Menu(
              ikon: LucideIcons.plug,
              label: 'Koneksi AI',
              detail: 'Uji provider + model',
              onTap: () => _pergi(context, '/koneksi'),
            ),
            _Menu(
              ikon: LucideIcons.settings2,
              label: 'Pengaturan',
              detail: setelan.agentAktif ? 'Mode agent aktif' : 'Mode chat',
              onTap: () => _pergi(context, '/setelan'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Text(
                '${AppConfig.appName} ${AppConfig.versi} · build ${AppEnv.appVersion}',
                style: context.teks.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pilih(String id) {
    HapticFeedback.selectionClick();
    ref.read(chatProvider.notifier).pilih(id);
    Navigator.of(context).pop();
  }

  void _pergi(BuildContext context, String rute) {
    Navigator.of(context).pop();
    context.push(rute);
  }
}

class _Kelompok extends StatelessWidget {
  const _Kelompok({
    required this.judul,
    required this.items,
    required this.onPilih,
    required this.ref,
  });

  final String judul;
  final List<Percakapan> items;
  final void Function(String id) onPilih;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final String aktifId = ref.watch(chatProvider).aktifId ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(judul.toUpperCase(), style: context.teks.labelSmall),
        ),
        for (final Percakapan p in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: p.id == aktifId
                  ? context.cs.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: AppRadius.br12,
              child: InkWell(
                borderRadius: AppRadius.br12,
                onTap: () => onPilih(p.id),
                onLongPress: () => _hapus(context, p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        p.kosong
                            ? LucideIcons.messageSquare
                            : LucideIcons.messageSquareText,
                        size: 16,
                        color: context.cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          p.judul,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.teks.bodyMedium?.copyWith(
                            fontWeight: p.id == aktifId
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _hapus(BuildContext context, Percakapan p) async {
    final bool? ya = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Hapus percakapan?'),
        content: Text('"${p.judul}" akan dihapus permanen.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya ?? false) await ref.read(chatProvider.notifier).hapusPercakapan(p.id);
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.ikon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData ikon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(ikon, size: 20),
      title: Text(label, style: context.teks.bodyMedium),
      subtitle: Text(detail, style: context.teks.labelSmall),
    );
  }
}