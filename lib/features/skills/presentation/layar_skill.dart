import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/teks.dart';
import '../../../domain/entities/setelan.dart';
import '../../../shared/widgets/tampilan_markdown.dart';
import '../data/skill_providers.dart';
import '../data/skill_repository.dart';
import '../domain/skill.dart';

/// Halaman daftar skill: pencarian + jumlah file/ukuran.
class LayarSkill extends ConsumerStatefulWidget {
  const LayarSkill({super.key});

  @override
  ConsumerState<LayarSkill> createState() => _LayarSkillState();
}

class _LayarSkillState extends ConsumerState<LayarSkill> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<IndeksSkill> async = ref.watch(indeksSkillProvider);
    final SetelanApp setelan = ref.watch(setelanProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pustaka Skill')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => _PesanGagal(pesan: '$e'),
        data: (IndeksSkill idx) {
          final List<Skill> daftar = idx.cari(_c.text.trim());
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _c,
                  onChanged: (String _) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari skill (${idx.jumlah} terpasang)…',
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _c.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _c.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${daftar.length} skill · '
                        '${idx.totalBerkas} berkas · '
                        '${(idx.totalUkuran / 1024 / 1024).toStringAsFixed(1)} MB',
                        style: context.teks.labelSmall,
                      ),
                    ),
                    if (setelan.pakaiSkillPanduan)
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
                          'AI memakai ini sebagai panduan',
                          style: context.teks.labelSmall
                              ?.copyWith(color: context.cs.primary),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: daftar.isEmpty
                    ? const _PesanGagal(pesan: 'Tidak ada skill yang cocok.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xxxl,
                        ),
                        itemCount: daftar.length,
                        separatorBuilder: (BuildContext _, int __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int i) =>
                            _KartuSkill(skill: daftar[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KartuSkill extends StatelessWidget {
  const _KartuSkill({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.surfaceContainerLow,
      borderRadius: AppRadius.br16,
      child: InkWell(
        borderRadius: AppRadius.br16,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => DetailSkill(skill: skill),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(LucideIcons.bookOpen,
                      size: 15, color: context.cs.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(skill.nama, style: context.teks.titleSmall),
                  ),
                  Icon(LucideIcons.chevronRight,
                      size: 16, color: context.cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                skill.deskripsi.isEmpty
                    ? '(tanpa deskripsi)'
                    : skill.deskripsi,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.teks.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${skill.jumlahFile} berkas · '
                '${(skill.size / 1024).toStringAsFixed(0)} KB',
                style: context.teks.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail: isi SKILL.md sebagai markdown + daftar berkas pendukung.
class DetailSkill extends ConsumerWidget {
  const DetailSkill({super.key, required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SkillRepository repo = ref.watch(skillRepositoryProvider);
    final Future<String?> isi = repo.bacaSkill(skill);
    final List<BerkasSkill> lain = skill.berkas
        .where((BerkasSkill b) => b.path != 'SKILL.md')
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(Teks.potong(skill.nama, 28))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          if (skill.deskripsi.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: context.cs.primary.withValues(alpha: 0.10),
                borderRadius: AppRadius.br12,
              ),
              child: Text(skill.deskripsi, style: context.teks.bodySmall),
            ),
          FutureBuilder<String?>(
            future: isi,
            builder: (BuildContext context, AsyncSnapshot<String?> snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final String? teks = snap.data;
              if (teks == null || teks.isEmpty) {
                return Text(
                  'Isi SKILL.md tidak terbaca.',
                  style: context.teks.bodyMedium,
                );
              }
              return TampilanMarkdown(teks: teks);
            },
          ),
          if (lain.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xxl),
            Text('Berkas pendukung (${lain.length})',
                style: context.teks.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final BerkasSkill b in lain.take(60))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.file, size: 16),
                title: Text(
                  b.path,
                  style: AppTypography.mono(
                    size: 12,
                    color: context.cs.onSurface,
                  ),
                ),
                subtitle: Text('${(b.size / 1024).toStringAsFixed(1)} KB'),
                onTap: () => _bukaBerkas(context, ref, b.path),
              ),
            if (lain.length > 60)
              Text(
                '…${lain.length - 60} berkas lain tidak ditampilkan di daftar.',
                style: context.teks.labelSmall,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _bukaBerkas(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) async {
    final String? isi = await ref
        .watch(skillRepositoryProvider)
        .bacaBerkas(skill, path);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (BuildContext sheetContext, ScrollController scroll) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(path, style: context.teks.titleSmall),
              ),
              Expanded(
                child: isi == null
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text('Berkas tidak terbaca (format biner?).'),
                      )
                    : ListView(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        children: <Widget>[
                          SelectableText(
                            isi.length > 60000
                                ? '${isi.substring(0, 60000)}\n…(dipotong)'
                                : isi,
                            style: AppTypography.mono(
                              size: 12,
                              color: context.cs.onSurface,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _PesanGagal extends StatelessWidget {
  const _PesanGagal({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(pesan, textAlign: TextAlign.center),
      ),
    );
  }
}