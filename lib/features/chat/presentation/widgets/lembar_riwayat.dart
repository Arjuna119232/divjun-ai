import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/waktu.dart';
import '../../../../domain/entities/percakapan.dart';
import '../../data/kontrol_chat.dart';

/// Lembar riwayat percakapan (bottom sheet snap 70% layar).
abstract final class LembarRiwayat {
  static Future<void> tampilkan(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => const _IsiLembar(),
    );
  }
}

class _IsiLembar extends ConsumerWidget {
  const _IsiLembar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StateChat state = ref.watch(chatProvider);
    final List<Percakapan> daftar = state.daftar;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController scroll) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text('Riwayat', style: context.teks.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Hapus semua riwayat',
                    icon: const Icon(LucideIcons.trash2, size: 20),
                    onPressed: daftar.isEmpty
                        ? null
                        : () => _konfirmasiHapusSemua(context, ref),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: FilledButton.icon(
                onPressed: () async {
                  await ref.read(chatProvider.notifier).buatPercakapanBaru();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Percakapan baru'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: daftar.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat.',
                        style: context.teks.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      itemCount: daftar.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Percakapan p = daftar[i];
                        final bool aktif = p.id == state.aktifId;
                        return ListTile(
                          selected: aktif,
                          selectedTileColor:
                              context.cs.primary.withValues(alpha: 0.10),
                          title: Text(
                            p.judul,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${Waktu.relatif(p.diperbarui)} · '
                            '${p.pesan.length} pesan',
                          ),
                          onTap: () {
                            ref.read(chatProvider.notifier).pilih(p.id);
                            Navigator.of(context).pop();
                          },
                          trailing: IconButton(
                            tooltip: 'Hapus percakapan',
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () async {
                              await ref
                                  .read(chatProvider.notifier)
                                  .hapusPercakapan(p.id);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _konfirmasiHapusSemua(BuildContext context, WidgetRef ref) async {
    final bool? ya = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
          'Semua percakapan akan dihapus dari perangkat ini. '
          'Memori jangka panjang tidak ikut terhapus.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.cs.error,
              foregroundColor: context.cs.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
    if (ya == true) {
      await ref.read(chatProvider.notifier).hapusSemua();
    }
  }
}

/// Dialog konfirmasi yang bisa dipakai di banyak tempat.
Future<bool> konfirmasi(
  BuildContext context, {
  required String judul,
  required String pesan,
  String labelYa = 'Ya',
  bool bahaya = true,
}) async {
  final bool? hasil = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(judul),
      content: Text(pesan),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: bahaya
              ? FilledButton.styleFrom(
                  backgroundColor: context.cs.error,
                  foregroundColor: context.cs.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(labelYa),
        ),
      ],
    ),
  );
  return hasil ?? false;
}
