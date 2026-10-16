import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme/app_theme.dart';

/// Tampilan markdown untuk jawaban AI.
///
/// Dipakai di bubble chat dan di halaman detail skill, supaya gaya teks
/// (kode, tabel, blockquote, tautan) konsisten di seluruh app.
class TampilanMarkdown extends StatelessWidget {
  const TampilanMarkdown({
    super.key,
    required this.teks,
    this.selectabel = true,
  });

  final String teks;
  final bool selectabel;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: teks,
      selectable: selectabel,
      styleSheet: gaya(context),
    );
  }

  static MarkdownStyleSheet gaya(BuildContext context) {
    final Color teks = context.cs.onSurface;
    final TextTheme t = context.teks;
    return MarkdownStyleSheet(
      p: t.bodyMedium?.copyWith(color: teks, height: 1.5),
      h1: t.titleLarge?.copyWith(color: teks),
      h2: t.titleMedium?.copyWith(color: teks),
      h3: t.titleSmall?.copyWith(color: teks),
      listBullet: t.bodyMedium?.copyWith(color: teks),
      code: TextStyle(
        fontFamily: AppTypography.monoFamily,
        fontSize: 13,
        height: 1.5,
        color: teks,
      ),
      codeblockDecoration: BoxDecoration(
        color: context.cs.surfaceContainerHigh,
        borderRadius: AppRadius.br12,
        border: Border.all(color: context.cs.outlineVariant),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      blockquoteDecoration: BoxDecoration(
        color: context.cs.surfaceContainer,
        borderRadius: AppRadius.br8,
        border: Border(
          left: BorderSide(color: context.cs.primary, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.all(AppSpacing.md),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.cs.outlineVariant)),
      ),
      a: t.bodyMedium?.copyWith(
        color: context.cs.primary,
        decoration: TextDecoration.underline,
      ),
      tableBorder: TableBorder.all(color: context.cs.outlineVariant, width: 1),
      tableHead: t.labelMedium?.copyWith(color: teks),
      tableBody: t.bodySmall?.copyWith(color: teks),
    );
  }
}