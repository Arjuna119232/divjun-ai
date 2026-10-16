import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/waktu.dart';
import '../../../domain/entities/model_ai.dart';
import '../../../domain/entities/percakapan.dart';
import '../../../domain/entities/setelan.dart';
import '../../settings/presentation/layar_setelan.dart';
import '../data/kontrol_chat.dart';
import 'widgets/gelembung_pesan.dart';
import 'widgets/kolom_tulis.dart';
import 'widgets/lembar_riwayat.dart';
import 'widgets/status_kosong.dart';

class LayarChat extends ConsumerStatefulWidget {
  const LayarChat({super.key});

  @override
  ConsumerState<LayarChat> createState() => _LayarChatState();
}

class _LayarChatState extends ConsumerState<LayarChat> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).muat();
      ref.read(memoriProvider.notifier).muat();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _keBawah({bool animasi = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final double target = _scroll.position.maxScrollExtent;
      if (animasi) {
        _scroll.animateTo(
          target,
          duration: AppMotion.sedang,
          curve: AppMotion.emphasized,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final StateChat state = ref.watch(chatProvider);
    final SetelanApp setelan = ref.watch(setelanProvider);
    final ModelAi model = ref.watch(modelProvider);
    final List<Pesan> pesan = state.aktif?.pesan ?? const <Pesan>[];

    ref.listen<int>(chatProvider.select((StateChat s) => s.daftar.fold<int>(
        0, (int a, Percakapan p) => a + p.pesan.length)),
        (int? sebelum, int? sesudah) {
      if (sebelum != sesudah) _keBawah();
    });

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: IconButton(
          tooltip: 'Riwayat percakapan',
          icon: const Icon(LucideIcons.panelLeft, size: 22),
          onPressed: () => LembarRiwayat.tampilkan(context, ref),
        ),
        title: InkWell(
          borderRadius: AppRadius.br12,
          onTap: () => _pilihModel(model),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        model.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.teks.titleSmall
                            ?.copyWith(color: context.cs.onSurface),
                      ),
                      Text(
                        state.sibuk
                            ? 'agent ${state.langkahAgent > 0 ? 'langkah ${state.langkahAgent}' : 'menjawab'}…'
                            : (setelan.agentAktif
                                ? 'mode agent'
                                : 'mode chat'),
                        style: context.teks.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(LucideIcons.chevronDown,
                    size: 16, color: context.cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Pustaka skill',
            icon: const Icon(LucideIcons.bookOpen, size: 22),
            onPressed: () => context.push('/skills'),
          ),
          IconButton(
            tooltip: 'Memori',
            icon: const Icon(LucideIcons.brain, size: 22),
            onPressed: () => context.push('/memori'),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(LucideIcons.settings2, size: 22),
            onPressed: () => context.push('/setelan'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: context.cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: pesan.isEmpty
                  ? StatusKosong(
                      salam: Waktu.salam(DateTime.now()),
                      saran: _saran,
                      onPilih: (String s) {
                        HapticFeedback.selectionClick();
                        ref.read(chatProvider.notifier).kirim(s);
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(chatProvider.notifier).muat(),
                      color: context.cs.primary,
                      backgroundColor: context.cs.surfaceContainer,
                      child: ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.xs,
                        ),
                        itemCount: pesan.length,
                        itemBuilder: (BuildContext context, int i) {
                          final Pesan p = pesan[i];
                          final bool terakhir = i == pesan.length - 1;
                          return GelembungPesan(
                            pesan: p,
                            sedangAlir: terakhir &&
                                state.sibuk &&
                                p.dariAi &&
                                p.sedangMengalir,
                            onSalin: () => _salin(p.isi),
                            onUlang: terakhir && !state.sibuk
                                ? () => ref
                                    .read(chatProvider.notifier)
                                    .kirimUlang()
                                : null,
                            onRingkas: terakhir && p.dariAi && p.isi.length > 400
                                ? () => ref
                                    .read(chatProvider.notifier)
                                    .ringkasJawabanTerakhir()
                                : null,
                            onEdit: p.dariPengguna && !state.sibuk
                                ? () => _edit(p)
                                : null,
                            onHapus: !state.sibuk
                                ? () => ref
                                    .read(chatProvider.notifier)
                                    .hapusPesan(p.id)
                                : null,
                            onCobaLagi: terakhir &&
                                    p.dariAi &&
                                    p.status == StatusPesan.gagal &&
                                    !state.sibuk
                                ? () => ref
                                    .read(chatProvider.notifier)
                                    .kirimUlang()
                                : null,
                          );
                        },
                      ),
                    ),
            ),
            KolomTulis(
              sibuk: state.sibuk,
              onKirim: (String t) {
                HapticFeedback.lightImpact();
                ref.read(chatProvider.notifier).kirim(t);
                _keBawah();
              },
              onStop: () {
                HapticFeedback.mediumImpact();
                ref.read(chatProvider.notifier).stop();
              },
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _saran = <String>[
    'Buatkan draf email minta cuti 3 hari',
    'Hitung 1.250.000 + 15% dari 3.400.000',
    'Ringkas ide fitur untuk aplikasi warga',
    'Buat kode Dart untuk parse JSON',
  ];

  void _salin(String teks) {
    Clipboard.setData(ClipboardData(text: teks));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Disalin ke papan klip')),
      );
  }

  Future<void> _edit(Pesan p) async {
    final String? baru = await tampilkanEditor(
      context,
      judul: 'Edit pesan',
      awal: p.isi,
      konfirmasi: 'Simpan',
    );
    if (baru == null || baru.trim() == p.isi) return;
    await ref.read(chatProvider.notifier).editPesan(p.id, baru.trim());
  }

  Future<void> _pilihModel(ModelAi sekarang) async {
    final List<ModelAi>? pilihan = await tampilkanPemilihModel(
      context,
      sekarang: sekarang,
    );
    if (pilihan == null || pilihan.isEmpty) return;
    await ref.read(setelanProvider.notifier).setModel(pilihan.first.id);
  }
}
