import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/model_ai.dart';
import '../../../domain/entities/setelan.dart';
import '../../chat/data/kontrol_chat.dart';
import 'bagian_setelan.dart';

/// Halaman Pengaturan.
///
/// Disusun dalam lima bagian (A-E) supaya pengguna awam bisa memindai halaman
/// dengan cepat. Rombakan v3.0.0: seluruh detail teknis (provider, kunci API,
/// jumlah berkas skill, tombol onboarding) dipindah ke sub-halaman, dan
/// sakelar yang sebenarnya perilaku inti dihapus dari UI.
///
/// Isi helper di bawah file ini dipakai juga oleh layar chat, jadi jangan
/// dipindah tanpa memeriksa pemanggilnya.
class LayarSetelan extends ConsumerWidget {
  const LayarSetelan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SetelanApp s = ref.watch(setelanProvider);
    final SetelanController c = ref.read(setelanProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          // ------------------------------------------------ A. Profil
          const BagianSetelan(
            judul: 'Profil & personalisasi',
            keterangan: 'Supaya DIVJUN terasa seperti milik Anda.',
            ikon: LucideIcons.user,
          ),
          KartuSetelan(
            anak: <Widget>[
              BarisSetelan(
                judul: 'Nama Anda',
                keterangan: s.namaPengguna.isEmpty
                    ? 'Dipakai AI untuk menyapa'
                    : s.namaPengguna,
                onTap: () async {
                  final String? v = await tampilkanEditor(
                    context,
                    judul: 'Nama Anda',
                    awal: s.namaPengguna,
                    konfirmasi: 'Simpan',
                    hint: 'Nama panggilan Anda',
                  );
                  if (v != null) await c.setNama(v);
                },
              ),
              BarisSetelan(
                judul: 'Instruksi Tambahan',
                keterangan: s.promptSistemTambahan.isEmpty
                    ? 'Misal: selalu balas singkat'
                    : TeksRingkas.potong(s.promptSistemTambahan, 50),
                onTap: () async {
                  final String? v = await tampilkanEditor(
                    context,
                    judul: 'Instruksi Tambahan',
                    awal: s.promptSistemTambahan,
                    konfirmasi: 'Simpan',
                    hint: 'Misal: gunakan Bahasa Indonesia santai',
                    multiline: true,
                  );
                  if (v != null) await c.setPromptTambahan(v);
                },
              ),
              _SliderSuhu(nilai: s.suhu, onChanged: c.setSuhu),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // --------------------------------- B. Kecerdasan & memori
          const BagianSetelan(
            judul: 'Kecerdasan & memori',
            keterangan: 'Apa yang boleh DIVJUN ingat dan kuasai.',
            ikon: LucideIcons.brain,
          ),
          KartuSetelan(
            anak: <Widget>[
              SakelarSetelan(
                judul: 'Memori Jangka Panjang',
                keterangan: 'Ingat fakta yang Anda minta disimpan.',
                nilai: s.ingatMemori,
                onChanged: c.setIngatMemori,
              ),
              BarisSetelan(
                judul: 'Kelola Memori',
                keterangan: 'Lihat dan hapus hal yang diingat.',
                onTap: () => context.push('/memori'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // --------------------------------------- C. Izin alat kerja
          const BagianSetelan(
            judul: 'Izin Alat',
            keterangan: 'Beri izin hanya yang memang Anda pakai.',
            ikon: LucideIcons.wand,
          ),
          KartuSetelan(
            anak: <Widget>[
              SakelarSetelan(
                judul: 'Akses Internet',
                keterangan: 'DIVJUN boleh membuka halaman web.',
                nilai: s.izinkanWeb,
                onChanged: c.setIzinWeb,
              ),
              SakelarSetelan(
                judul: 'Kalkulator',
                keterangan: 'Untuk hitungan yang perlu tepat.',
                nilai: s.izinkanKalkulator,
                onChanged: c.setIzinKalkulator,
              ),
              SakelarSetelan(
                judul: 'Pembuat Draf Email',
                keterangan: 'DIVJUN menulis draf, Anda yang mengirim.',
                nilai: s.izinkanEmail,
                onChanged: c.setIzinEmail,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // -------------------------------------------- D. Tampilan
          const BagianSetelan(
            judul: 'Tampilan',
            keterangan: 'Sesuaikan warna dengan liking Anda.',
            ikon: LucideIcons.palette,
          ),
          KartuSetelan(
            anak: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: SegmentedButton<TemaMode>(
                  segments: const <ButtonSegment<TemaMode>>[
                    ButtonSegment<TemaMode>(
                      value: TemaMode.sistem,
                      label: Text('Sistem'),
                      icon: Icon(LucideIcons.smartphone, size: 16),
                    ),
                    ButtonSegment<TemaMode>(
                      value: TemaMode.terang,
                      label: Text('Terang'),
                      icon: Icon(LucideIcons.sun, size: 16),
                    ),
                    ButtonSegment<TemaMode>(
                      value: TemaMode.gelap,
                      label: Text('Gelap'),
                      icon: Icon(LucideIcons.moon, size: 16),
                    ),
                  ],
                  selected: <TemaMode>{s.tema},
                  onSelectionChanged: (Set<TemaMode> v) => c.setTema(v.first),
                ),
              ),
              SakelarSetelan(
                judul: 'Warna Dinamis',
                keterangan: 'Warna app mengikuti wallpaper HP.',
                nilai: s.pakaiWarnaDinamis,
                onChanged: c.setWarnaDinamis,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // -------------------------------------------- E. Lainnya
          const BagianSetelan(
            judul: 'Lainnya',
            keterangan: 'Pilihan yang jarang diganti.',
            ikon: LucideIcons.ellipsis,
          ),
          KartuSetelan(
            anak: <Widget>[
              BarisSetelan(
                judul: 'Tentang',
                keterangan: 'Versi aplikasi dan ringkasan kemampuan.',
                onTap: () => context.push('/setelan/tentang'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TombolBahaya(
            judul: 'Hapus Semua Riwayat Chat',
            onTap: () => _konfirmasiHapus(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _konfirmasiHapus(BuildContext context, WidgetRef ref) async {
    final bool ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext d) => AlertDialog(
            title: const Text('Hapus semua riwayat?'),
            content: const Text(
              'Semua percakapan akan hilang dan tidak bisa dikembalikan.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(d).pop(true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !context.mounted) return;
    await ref.read(chatProvider.notifier).hapusSemua();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Riwayat chat dihapus.')),
    );
  }
}

/// Slider "Gaya jawaban".
///
/// Nilai 0..2 tetap kompatibel dengan model, tapi yang ditampilkan ke user
/// adalah nama gaya (Fokus / Seimbang / Luap / Kreatif) plus dua label ujung.
/// Angka mentah tidak membantu pengguna awam memahami apa yang dia ubah.
class _SliderSuhu extends StatelessWidget {
  const _SliderSuhu({required this.nilai, required this.onChanged});

  final double nilai;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Gaya Jawaban', style: context.teks.bodyLarge),
              ),
              Text(_label, style: context.teks.labelMedium),
            ],
          ),
          Slider(
            value: nilai.clamp(0, 2),
            min: 0,
            max: 2,
            divisions: 4,
            label: _label,
            onChanged: onChanged,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Fokus & Singkat',
                  style: context.teks.labelSmall,
                  textAlign: TextAlign.left,
                ),
              ),
              Expanded(
                child: Text(
                  'Kreatif & Luas',
                  style: context.teks.labelSmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Nama gaya yang dibaca user, bukan angka desimal.
  String get _label {
    if (nilai < 0.5) return 'Fokus';
    if (nilai < 1.1) return 'Seimbang';
    if (nilai < 1.6) return 'Luap';
    return 'Kreatif';
  }
}

/// Helper: dialog edit teks (dipakai juga dari layar chat).
Future<String?> tampilkanEditor(
  BuildContext context, {
  required String judul,
  required String awal,
  required String konfirmasi,
  String? hint,
  bool multiline = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _DialogEditor(
      judul: judul,
      awal: awal,
      konfirmasi: konfirmasi,
      hint: hint,
      multiline: multiline,
    ),
  );
}

/// Helper: bottom sheet pemilih model.
Future<List<ModelAi>?> tampilkanPemilihModel(
  BuildContext context, {
  required ModelAi sekarang,
}) {
  return showModalBottomSheet<List<ModelAi>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext _) => _LembarModel(sekarang: sekarang),
  );
}

class _DialogEditor extends StatefulWidget {
  const _DialogEditor({
    required this.judul,
    required this.awal,
    required this.konfirmasi,
    this.hint,
    this.multiline = false,
  });

  final String judul;
  final String awal;
  final String konfirmasi;
  final String? hint;
  final bool multiline;

  @override
  State<_DialogEditor> createState() => _DialogEditorState();
}

class _DialogEditorState extends State<_DialogEditor> {
  late final TextEditingController _c =
      TextEditingController(text: widget.awal);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.judul),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLines: widget.multiline ? 5 : 1,
        minLines: widget.multiline ? 3 : 1,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_c.text),
          child: Text(widget.konfirmasi),
        ),
      ],
    );
  }
}

class _LembarModel extends ConsumerWidget {
  const _LembarModel({required this.sekarang});

  final ModelAi sekarang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ModelAi>> katalog =
        ref.watch(katalogModelProvider);
    final SetelanApp s = ref.watch(setelanProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scroll) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Pilih model',
                      style: context.teks.titleMedium,
                    ),
                  ),
                  Text(
                    s.modeAgent == ModeAgent.auto ? 'auto aktif' : 'manual',
                    style: context.teks.labelSmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: katalog.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object e, StackTrace s) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text('Gagal memuat daftar model: $e'),
                ),
                data: (List<ModelAi> daftar) {
                  if (daftar.isEmpty) {
                    return const Center(child: Text('Tidak ada model.'));
                  }
                  return ListView.builder(
                    controller: scroll,
                    itemCount: daftar.length,
                    itemBuilder: (BuildContext context, int i) {
                      final ModelAi m = daftar[i];
                      final bool dipilih = m.id == sekarang.id;
                      return ListTile(
                        selected: dipilih,
                        selectedTileColor:
                            context.cs.primary.withValues(alpha: 0.10),
                        title: Text(m.label),
                        subtitle: Text(
                          '${m.penyedia.name} · konteks '
                          '${(m.konteks / 1000).round()}k'
                          '${m.dukungAlat ? ' · agent' : ''}',
                        ),
                        trailing: dipilih
                            ? Icon(LucideIcons.check, size: 18,
                                color: context.cs.primary)
                            : null,
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          if (context.mounted) {
                            Navigator.of(context).pop(<ModelAi>[m]);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }
}

/// Pemotongan teks kecil untuk subtitle (dipisah agar file utama rapi).
abstract final class TeksRingkas {
  static String potong(String s, int maks) =>
      s.length <= maks ? s : '${s.substring(0, maks)}…';
}
