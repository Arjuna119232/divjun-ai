import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/tampilan_markdown.dart';
import '../domain/artifak.dart';

/// Layar penuh untuk satu artifak: pratinjau dokumen (HTML/SVG/Markdown)
/// atau kode mentah yang bisa disalin.
///
/// Layar ini juga bisa dibuka langsung lewat `context.push` (bukan hanya dari
/// kartu di dalam bubble), karena itu isi kosong ditangani sendiri.
class HalamanArtifak extends StatefulWidget {
  const HalamanArtifak({super.key, required this.artifak});

  final Artifak artifak;

  @override
  State<HalamanArtifak> createState() => _HalamanArtifakState();
}

class _HalamanArtifakState extends State<HalamanArtifak> {
  late bool _pratinjau = widget.artifak.bisaPratinjau;

  Artifak get _a => widget.artifak;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = context.cs;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _a.isi.trim().isEmpty ? 'Artifak' : _a.judul,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.teks.titleSmall,
            ),
            Text(
              _a.isi.trim().isEmpty
                  ? 'tidak ditemukan'
                  : '${_a.label} · ${_a.jumlahBaris} baris',
              style: context.teks.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (_a.isi.trim().isNotEmpty) ...<Widget>[
            IconButton(
              tooltip: 'Salin',
              icon: const Icon(LucideIcons.copy, size: 20),
              onPressed: () async {
                final ScaffoldMessengerState pesan = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: _a.isi));
                pesan
                  ..clearSnackBars()
                  ..showSnackBar(const SnackBar(content: Text('Disalin')));
              },
            ),
            IconButton(
              tooltip: 'Bagikan',
              icon: const Icon(LucideIcons.share2, size: 20),
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(text: _a.isi)),
            ),
          ],
        ],
      ),
      body: _a.isi.trim().isEmpty
          ? const _Kosong()
          : Column(
              children: <Widget>[
                if (_a.bisaPratinjau) _Pemilih(nilai: _pratinjau, onUbah: _ganti),
                Expanded(
                  child: IndexedStack(
                    index: _pratinjau && _a.bisaPratinjau ? 0 : 1,
                    children: <Widget>[
                      _Isi(artifak: _a),
                      _Kode(teks: _a.isi),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _ganti(bool nilai) {
    if (nilai == _pratinjau) return;
    setState(() => _pratinjau = nilai);
  }
}

class _Pemilih extends StatelessWidget {
  const _Pemilih({required this.nilai, required this.onUbah});

  final bool nilai;
  final ValueChanged<bool> onUbah;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: true,
              icon: Icon(LucideIcons.eye, size: 16),
              label: Text('Pratinjau'),
            ),
            ButtonSegment<bool>(
              value: false,
              icon: Icon(LucideIcons.code, size: 16),
              label: Text('Kode'),
            ),
          ],
          selected: <bool>{nilai},
          showSelectedIcon: false,
          onSelectionChanged: (Set<bool> s) => onUbah(s.first),
        ),
      ),
    );
  }
}

/// Isi artifak yang punya tampilan: HTML/SVG lewat WebView, Markdown lewat
/// renderer markdown app sendiri (tidak perlu WebView).
class _Isi extends StatelessWidget {
  const _Isi({required this.artifak});

  final Artifak artifak;

  @override
  Widget build(BuildContext context) {
    if (artifak.jenis == JenisArtifak.markdown) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: TampilanMarkdown(teks: artifak.isi),
      );
    }
    return _PratinjauWeb(artifak: artifak);
  }
}

/// Pratinjau dokumen di WebView.
///
/// `flutter_html` sengaja tidak dipakai: dokumen AI sering memuat CSS/JS
/// sendiri (grafik, animasi, tombol) dan hanya mesin browser sungguhan yang
/// bisa menjalankannya. WebView tidak punya akses jaringan khusus — sama
/// seperti browser biasa.
class _PratinjauWeb extends StatefulWidget {
  const _PratinjauWeb({required this.artifak});

  final Artifak artifak;

  @override
  State<_PratinjauWeb> createState() => _PratinjauWebState();
}

class _PratinjauWebState extends State<_PratinjauWeb>
    with AutomaticKeepAliveClientMixin {
  // Bukan `final`: tombol "Coba lagi" membuat controller baru. `late final`
  // akan melempar LateInitializationError tepat di jalur pemulihan itu.
  late WebViewController _ctrl;
  bool _memuat = true;
  String? _galat;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  void _siapkan() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.kertas)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String _) {
            if (mounted) setState(() => _memuat = false);
          },
          onWebResourceError: (WebResourceError e) {
            // Galat sub-resource (gambar/CDN) bukan alasan menutup pratinjau.
            if (!mounted || e.isForMainFrame != true) return;
            setState(() {
              _memuat = false;
              _galat = e.description;
            });
          },
        ),
      )
      ..loadHtmlString(widget.artifak.dokumenHtml());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_galat != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(LucideIcons.circleAlert, color: context.cs.error),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pratinjau gagal dimuat',
                style: context.teks.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _galat!,
                textAlign: TextAlign.center,
                style: context.teks.bodySmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _galat = null;
                    _memuat = true;
                  });
                  _siapkan();
                },
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        WebViewWidget(controller: _ctrl),
        if (_memuat)
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      ],
    );
  }
}

/// Tampilan kode: bisa digulir dua arah, bisa disalin per bagian.
class _Kode extends StatefulWidget {
  const _Kode({required this.teks});

  final String teks;

  @override
  State<_Kode> createState() => _KodeState();
}

class _KodeState extends State<_Kode> {
  final ScrollController _mendatar = ScrollController();
  final ScrollController _tegak = ScrollController();

  @override
  void dispose() {
    _mendatar.dispose();
    _tegak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _mendatar,
      child: SingleChildScrollView(
        controller: _mendatar,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          controller: _tegak,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: SelectableText(
                widget.teks,
                style: TextStyle(
                  fontFamily: AppTypography.monoFamily,
                  fontSize: 13,
                  height: 1.6,
                  color: context.cs.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Kosong extends StatelessWidget {
  const _Kosong();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = context.cs;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(LucideIcons.fileCode, size: 32, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text('Artifak tidak tersedia', style: context.teks.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Buka kartu kode langsung dari jawaban AI.',
              textAlign: TextAlign.center,
              style: context.teks.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
