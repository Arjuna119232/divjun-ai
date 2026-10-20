import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tampilan_markdown.dart';
import '../domain/artifak.dart';
import 'kartu_artifak.dart';

/// Isi satu jawaban AI: teks markdown + kartu untuk setiap blok kode.
///
/// Tanpa blok kode, widget ini langsung menyerahkan ke [TampilanMarkdown]
/// supaya tidak ada lapisan tambahan di jalur terpanas (jawaban mengalir).
class IsiJawaban extends StatelessWidget {
  const IsiJawaban({super.key, required this.teks, this.selectabel = true});

  final String teks;
  final bool selectabel;

  @override
  Widget build(BuildContext context) {
    final List<BagianTeks> bagian = PemecahJawaban.pecah(teks);

    if (bagian.length == 1 && !bagian.first.kode) {
      return TampilanMarkdown(teks: teks, selectabel: selectabel);
    }

    final List<Widget> anak = <Widget>[];
    for (final BagianTeks b in bagian) {
      if (anak.isNotEmpty) {
        anak.add(const SizedBox(height: AppSpacing.sm));
      }
      if (b.kode) {
        anak.add(KartuArtifak(artifak: b.artifak!));
      } else {
        anak.add(TampilanMarkdown(teks: b.teks, selectabel: selectabel));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: anak,
    );
  }
}
