import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_env.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/model_ai.dart';
import '../../../domain/entities/setelan.dart';
import '../../onboarding/presentation/layar_onboarding.dart';
import '../../skills/data/skill_providers.dart';
import '../../skills/domain/skill.dart';

class LayarSetelan extends ConsumerWidget {
  const LayarSetelan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SetelanApp s = ref.watch(setelanProvider);
    final ModelAi model = ref.watch(modelProvider);
    final int jumlahSkill = ref.watch(jumlahSkillProvider);
    final IndeksSkill idxSkill =
        ref.watch(indeksSkillProvider).valueOrNull ?? IndeksSkill.kosong;
    final SetelanController c = ref.read(setelanProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          _Bagian(
            judul: 'Model AI',
            ikon: LucideIcons.brain,
            anak: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(model.label),
                subtitle: Text(
                  '${model.penyedia.name} · '
                  '${model.dukungAlat ? 'support agent' : 'chat saja'}',
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final List<ModelAi>? pilih =
                      await tampilkanPemilihModel(context, sekarang: model);
                  if (pilih != null && pilih.isNotEmpty) {
                    await c.setModel(pilih.first.id);
                  }
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.modeAgent == ModeAgent.auto,
                title: const Text('Pilih model otomatis'),
                subtitle: const Text(
                  'Model dipilih otomatis sesuai jenis pertanyaan.',
                ),
                onChanged: (bool v) =>
                    c.setModeAgent(v ? ModeAgent.auto : ModeAgent.selalu),
              ),
            ],
          ),
          _Bagian(
            judul: 'Tampilan',
            ikon: LucideIcons.palette,
            anak: <Widget>[
              SegmentedButton<TemaMode>(
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
                onSelectionChanged: (Set<TemaMode> v) =>
                    c.setTema(v.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.pakaiWarnaDinamis,
                title: const Text('Warna dinamis (Material You)'),
                subtitle: const Text(
                  'Ambil palet warna dari wallpaper HP (Android 12+).',
                ),
                onChanged: c.setWarnaDinamis,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.bookOpen),
                title: const Text('Tampilkan lagi onboarding'),
                subtitle: const Text(
                  'Ulangi 3 halaman perkenalan DIVJUN AI.',
                ),
                onTap: () async {
                  // Kunci dihapus dulu supaya "/onboarding" yang dibuka manual
                  // tetap menyimpan status selesai saat user menekan "Mulai".
                  await ref
                      .read(simpanCepitProvider)
                      .hapus(kunciOnboarding);
                  if (!context.mounted) return;
                  context.push('/onboarding');
                },
              ),
            ],
          ),
          _Bagian(
            judul: 'Agent & alat',
            ikon: LucideIcons.wand,
            anak: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.ingatMemori,
                title: const Text('Memori jangka panjang'),
                subtitle: const Text(
                  'AI boleh mengingat fakta yang kamu minta disimpan.',
                ),
                onChanged: c.setIngatMemori,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.izinkanKalkulator,
                title: const Text('Kalkulator'),
                onChanged: c.setIzinKalkulator,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.izinkanWeb,
                title: const Text('Buka web'),
                subtitle: const Text(
                  'Alamat privat & internal diblokir demi keamanan.',
                ),
                onChanged: c.setIzinWeb,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.izinkanEmail,
                title: const Text('Draf email'),
                subtitle: const Text(
                  'AI hanya membuat draf; kamu yang menekan kirim.',
                ),
                onChanged: c.setIzinEmail,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kelola memori'),
                subtitle: const Text('Lihat, hapus, atau bersihkan semua entri.'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => context.push('/memori'),
              ),
            ],
          ),
          _Bagian(
            judul: 'Pustaka skill',
            ikon: LucideIcons.bookOpen,
            anak: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Skill bawaan'),
                subtitle: Text(
                  '${jumlahSkill} skill tersimpan di dalam app '
                  '(offline, tidak butuh internet).',
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => context.push('/skills'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.pakaiSkillPanduan,
                title: const Text('AI memakai skill sebagai panduan'),
                subtitle: const Text(
                  'Skill yang cocok dengan pertanyaan ikut disuntik ke '
                  'instructions, jadi jawaban AI mengikuti prosedur kerja '
                  'yang sudah teruji.',
                ),
                onChanged: ref.read(setelanProvider.notifier).setPakaiSkill,
              ),
            ],
          ),
          _Bagian(
            judul: 'Perilaku',
            ikon: LucideIcons.sliders,
            anak: <Widget>[
              _SliderSuhu(
                nilai: s.suhu,
                onChanged: c.setSuhu,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.autoRingkas,
                title: const Text('Ringkas riwayat otomatis'),
                subtitle: const Text(
                  'Riwayat panjang diringkas agar hemat token.',
                ),
                onChanged: c.setAutoRingkas,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Nama kamu'),
                subtitle: Text(
                  s.namaPengguna.isEmpty ? 'Belum diisi' : s.namaPengguna,
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final String? v = await tampilkanEditor(
                    context,
                    judul: 'Nama kamu',
                    awal: s.namaPengguna,
                    konfirmasi: 'Simpan',
                    hint: 'Dipakai AI untuk menyapa',
                  );
                  if (v != null) await c.setNama(v);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Instruksi tambahan'),
                subtitle: Text(
                  s.promptSistemTambahan.isEmpty
                      ? 'Contoh: selalu balas singkat'
                      : TeksRingkas.potong(s.promptSistemTambahan, 60),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () async {
                  final String? v = await tampilkanEditor(
                    context,
                    judul: 'Instruksi tambahan',
                    awal: s.promptSistemTambahan,
                    konfirmasi: 'Simpan',
                    hint: 'Misal: gunakan Bahasa Indonesia casual',
                    multiline: true,
                  );
                  if (v != null) await c.setPromptTambahan(v);
                },
              ),
            ],
          ),
          _Bagian(
            judul: 'Tentang',
            ikon: LucideIcons.info,
            anak: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Versi'),
                subtitle: Text(
                  '${AppConfig.appName} ${AppConfig.versi} · build ${AppEnv.appVersion}',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pustaka skill di dalam app'),
                subtitle: Text(
                  '$jumlahSkill skill · ${idxSkill.totalBerkas} berkas · '
                  '${(idxSkill.totalUkuran / 1024 / 1024).toStringAsFixed(1)} MB '
                  '· offline, ikut terpasang di APK',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.plug),
                title: const Text('Koneksi AI'),
                subtitle: Text(
                  ref.watch(kunciGroqAktifProvider).trim().isNotEmpty ||
                          ref.watch(kunciGeminiAktifProvider).trim().isNotEmpty
                      ? 'Uji koneksi, ganti kunci API, lihat model yang hidup.'
                      : 'Belum ada kunci API. Tekan untuk memasukkan kunci '
                          'gratis (tanpa kartu kredit).',
                  style: TextStyle(
                    color: (ref.watch(kunciGroqAktifProvider).trim().isEmpty &&
                            ref.watch(kunciGeminiAktifProvider).trim().isEmpty)
                        ? context.cs.error
                        : null,
                  ),
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
                onTap: () => context.push('/koneksi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bagian extends StatelessWidget {
  const _Bagian({required this.judul, required this.ikon, required this.anak});

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

class _SliderSuhu extends StatelessWidget {
  const _SliderSuhu({required this.nilai, required this.onChanged});

  final double nilai;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Kreativitas jawaban', style: context.teks.bodyLarge),
            ),
            Text(nilai.toStringAsFixed(1), style: context.teks.labelMedium),
          ],
        ),
        Slider(
          value: nilai.clamp(0, 2),
          min: 0,
          max: 2,
          divisions: 8,
          label: nilai.toStringAsFixed(1),
          onChanged: onChanged,
        ),
        Text(
          'Rendah = fokus dan singkat · Tinggi = lebih beragam',
          style: context.teks.labelSmall,
        ),
      ],
    );
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
