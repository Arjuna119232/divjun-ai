import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../data/katalog_ide_ai.dart';
import '../domain/template_ai.dart';

/// Halaman jelajahi ide AI dari awesome-llm-apps.
///
/// Tiap kartu adalah ide agen AI open source (Apache-2.0). User bisa:
/// - membuka sumber di GitHub, atau
/// - menyalin "prompt starter" ke papan klip lalu mencobanya di chat.
class LayarExplore extends StatefulWidget {
  const LayarExplore({super.key});

  @override
  State<LayarExplore> createState() => _LayarExploreState();
}

class _LayarExploreState extends State<LayarExplore> {
  final TextEditingController _cari = TextEditingController();
  String _kategori = 'Semua';

  List<IdeTemplate> get _daftar {
    final q = _cari.text.trim().toLowerCase();
    return katalogIdeAi.where((t) {
      if (_kategori != 'Semua' && t.kategori != _kategori) return false;
      if (q.isEmpty) return true;
      final haystack =
          '${t.judul} ${t.deskripsi} ${t.kategori}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  List<String> get _kategoriSemua {
    final set = <String>{'Semua'};
    for (final t in katalogIdeAi) set.add(t.kategori);
    return set.toList()..sort();
  }

  void _bukaGitHub(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _salinPrompt(IdeTemplate t) {
    if (t.promptStarter == null || t.promptStarter!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: t.promptStarter!));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Prompt disalin ke papan klip.'),
          action: SnackBarAction(
            label: 'Buka chat',
            onPressed: () => context.go('/chat'),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daftar = _daftar;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jelajahi Ide AI'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm,
            ),
            child: Text(
              'Ratusan ide agen AI dari awesome-llm-apps '
              '(open source, Apache-2.0). Salin prompt starter dan coba di chat, '
              'atau buka sumber di GitHub.',
              style: context.teks.bodySmall
                  ?.copyWith(color: context.cs.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
            ),
            child: TextField(
              controller: _cari,
              onChanged: (String _) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari ide…',
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
                for (final k in _kategoriSemua)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(k),
                      selected: _kategori == k,
                      showCheckmark: false,
                      onSelected: (bool _) => setState(() => _kategori = k),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: daftar.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            LucideIcons.search,
                            size: 40,
                            color: context.cs.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Tidak ada ide yang cocok.',
                            style: context.teks.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                    itemCount: daftar.length,
                    separatorBuilder: (BuildContext _, int __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) =>
                        _KartuIde(t: daftar[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
            ),
            child: TextButton.icon(
              icon: const Icon(LucideIcons.arrowUpRight, size: 16),
              onPressed: () => _bukaGitHub(
                'https://github.com/Shubhamsaboo/awesome-llm-apps',
              ),
              label: const Text(
                'Sumber: awesome-llm-apps (Shubham Saboo) — Apache-2.0',
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuIde extends StatelessWidget {
  const _KartuIde({required this.t});

  final IdeTemplate t;

  @override
  Widget build(BuildContext context) {
    final bool adaPrompt = t.promptStarter != null && t.promptStarter!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.cs.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.br12,
                ),
                child: Icon(
                  t.ikon,
                  size: 20,
                  color: context.cs.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: context.cs.surfaceContainerHigh,
                  borderRadius: AppRadius.br8,
                ),
                child: Text(
                  t.kategori,
                  style: context.teks.labelSmall
                      ?.copyWith(color: context.cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            t.judul,
            style: context.teks.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            t.deskripsi,
            style: context.teks.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.arrowUpRight, size: 16),
                  onPressed: () => _bukaGitHub(t.link),
                  label: const Text('Buka di GitHub'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.cs.onSurfaceVariant,
                    side: BorderSide(color: context.cs.outlineVariant),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              if (adaPrompt) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    onPressed: () => _salinPrompt(t),
                    label: const Text('Salin prompt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.cs.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
