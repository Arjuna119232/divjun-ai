import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tampilan_markdown.dart';
import '../data/legal_service.dart';

/// Pembaca satu dokumen legal (markdown dari `assets/legal/`).
///
/// Dipakai lewat rute `/legal/dokumen/:id` dan dari tautan di halaman Login.
class HalamanMarkdown extends StatefulWidget {
  const HalamanMarkdown({
    super.key,
    required this.judul,
    required this.berkas,
  });

  final String judul;

  /// Path asset, mis. `assets/legal/terms.md`.
  final String berkas;

  @override
  State<HalamanMarkdown> createState() => _HalamanMarkdownState();
}

class _HalamanMarkdownState extends State<HalamanMarkdown> {
  late Future<String> _isi;

  @override
  void initState() {
    super.initState();
    _isi = LegalService.baca(widget.berkas);
  }

  void _ulangi() {
    setState(() {
      _isi = LegalService.baca(widget.berkas);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.judul)),
      body: FutureBuilder<String>(
        future: _isi,
        builder: (BuildContext context, AsyncSnapshot<String> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final String? teks = snap.data;
          if (snap.hasError || teks == null) {
            return _Gagal(onUlang: _ulangi);
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TampilanMarkdown(teks: teks),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Terakhir diperbarui: ${LegalService.diperbarui}',
                  style: context.teks.bodySmall?.copyWith(
                    fontSize: 12,
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Keadaan gagal: berkas dokumen tidak bisa dibaca dari bundle.
class _Gagal extends StatelessWidget {
  const _Gagal({required this.onUlang});

  final VoidCallback onUlang;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pad24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              LucideIcons.triangleAlert,
              size: 34,
              color: context.cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Dokumen tidak bisa dibuka',
              style: context.teks.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Berkas dokumen tidak ada di dalam aplikasi ini.',
              style: context.teks.bodySmall?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onUlang, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
