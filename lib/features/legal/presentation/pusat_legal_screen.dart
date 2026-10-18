import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../data/legal_service.dart';

/// Pusat Legal: daftar dokumen hukum aplikasi.
///
/// Isi tiap dokumen dibaca dari `assets/legal/*.md` (lihat [LegalService]),
/// jadi tidak ada teks hukum yang ditulis di dalam kode UI.
class PusatLegalScreen extends StatelessWidget {
  const PusatLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pusat Legal')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Dokumen resmi DIVJUN AI. Ketuk salah satu untuk membacanya.',
              style: context.teks.bodySmall?.copyWith(
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ),
          for (final DokumenLegal d in LegalService.daftar)
            ListTile(
              leading: Icon(_ikon(d.id)),
              title: Text(d.judul),
              subtitle: Text(d.ringkas),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => context.push('/legal/dokumen/${d.id}'),
            ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              'Terakhir diperbarui: ${LegalService.diperbarui}',
              style: context.teks.bodySmall?.copyWith(
                fontSize: 12,
                color: context.cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ikon per dokumen; dipetakan dari id supaya data tetap bebas dari widget.
IconData _ikon(String id) {
  switch (id) {
    case 'privasi':
      return LucideIcons.eye;
    case 'penggunaan':
      return LucideIcons.bookOpen;
    default:
      return LucideIcons.file;
  }
}
