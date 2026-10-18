import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/waktu.dart';
import '../../../../domain/entities/percakapan.dart';
import '../../../../shared/widgets/tampilan_markdown.dart';

/// Satu bubble pesan: user (kanan, warna brand) atau AI (kiri, netral).
///
/// Semua aksi (salin/ulang/ringkas/edit/hapus) lewat menu panjang agar
/// tidak ada tombol kecil yang hard ditekan.
class GelembungPesan extends StatelessWidget {
  const GelembungPesan({
    super.key,
    required this.pesan,
    this.sedangAlir = false,
    this.onSalin,
    this.onUlang,
    this.onRingkas,
    this.onEdit,
    this.onHapus,
    this.onCobaLagi,
  });

  final Pesan pesan;
  final bool sedangAlir;
  final VoidCallback? onSalin;
  final VoidCallback? onUlang;
  final VoidCallback? onRingkas;
  final VoidCallback? onEdit;
  final VoidCallback? onHapus;
  final VoidCallback? onCobaLagi;

  @override
  Widget build(BuildContext context) {
    final bool user = pesan.dariPengguna;
    final Color latar =
        user ? AppColors.brand : AppColors.bubbleAi(context);
    final Color teks = user
        ? Colors.white
        : context.cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment:
            user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (pesan.catatanAlat.isNotEmpty) ...<Widget>[
            _CatatanAlat(pesan: pesan),
            const SizedBox(height: AppSpacing.xs),
          ],
          GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _tampilkanMenu(context);
            },
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.86,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: latar,
                borderRadius: AppRadius.bubble(isUser: user),
                border: user
                    ? null
                    : Border.all(
                        color: context.cs.outlineVariant,
                        width: 1,
                      ),
                boxShadow: user ? AppShadows.bubble(AppColors.brand) : null,
              ),
              child: _isi(context, teks),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (user) ...<Widget>[
                Text(
                  Waktu.jam(pesan.waktu),
                  style: context.teks.labelSmall,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (!user && pesan.modelId.isNotEmpty) ...<Widget>[
                Text(
                  _modelRingkas(pesan.modelId),
                  style: context.teks.labelSmall,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(Waktu.jam(pesan.waktu), style: context.teks.labelSmall),
              ],
            ],
          ),
          if (pesan.status == StatusPesan.gagal && onCobaLagi != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _KartuGalat(pesan: pesan, onCobaLagi: onCobaLagi!),
          ],
        ],
      ),
    );
  }

  Widget _isi(BuildContext context, Color teks) {
    final bool adaPenalaran = pesan.punyaPenalaran;

    // Blok "Berpikir" duduk DI DALAM bubble, di atas jawaban - seperti Claude.
    // Tanpa ini, penalaran yang sudah dipisah di layer data tidak pernah tampil
    // dan user mengira model menjawab tanpa berpikir sama sekali.
    final Widget? blokPenalaran = adaPenalaran
        ? _BlokPenalaran(pesan: pesan, sedangAlir: sedangAlir)
        : null;

    if (pesan.isi.isEmpty) {
      if (blokPenalaran != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            blokPenalaran,
            if (pesan.status == StatusPesan.mengalir) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _TeksSedangMengalir(),
            ],
          ],
        );
      }
      if (pesan.status == StatusPesan.mengalir) {
        return _TeksSedangMengalir();
      }
      return Text(
        pesan.pesanGalat.isEmpty ? '(kosong)' : pesan.pesanGalat,
        style: context.teks.bodyMedium?.copyWith(color: teks),
      );
    }

    if (pesan.dariPengguna) {
      return SelectionArea(
        child: Text(
          pesan.isi,
          style: context.teks.bodyMedium?.copyWith(color: teks, height: 1.45),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (blokPenalaran != null) ...<Widget>[
          blokPenalaran,
          const SizedBox(height: AppSpacing.sm),
        ],
        TampilanMarkdown(teks: pesan.isi),
        if (pesan.status == StatusPesan.mengalir) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _TeksSedangMengalir(),
        ],
      ],
    );
  }

  static String _modelRingkas(String id) {
    final String p = id.split('/').last;
    return p.replaceAll('-', ' ');
  }


  Future<void> _tampilkanMenu(BuildContext context) async {
    final List<_ItemMenu> item = <_ItemMenu>[
      if (onSalin != null) _ItemMenu('Salin', onSalin),
      if (onEdit != null) _ItemMenu('Edit', onEdit),
      if (onUlang != null) _ItemMenu('Jawab ulang', onUlang),
      if (onRingkas != null) _ItemMenu('Ringkas', onRingkas),
      if (onHapus != null) _ItemMenu('Hapus pesan', onHapus, bahaya: true),
    ];
    if (item.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final _ItemMenu x in item)
                ListTile(
                  title: Text(
                    x.label,
                    style: TextStyle(
                      color: x.bahaya ? context.cs.error : null,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    x.aksi?.call();
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

/// Blok "Berpikir": isi penalaran model, bisa dibuka-tutup.
///
/// Default terbuka saat masih mengalir (supaya user lihat prosesnya), lalu
/// menutup sendiri saat jawaban selesai - kecuali user yang membukanya
/// secara manual, pilihan itu dihormati.
class _BlokPenalaran extends StatefulWidget {
  const _BlokPenalaran({required this.pesan, required this.sedangAlir});

  final Pesan pesan;
  final bool sedangAlir;

  @override
  State<_BlokPenalaran> createState() => _BlokPenalaranState();
}

class _BlokPenalaranState extends State<_BlokPenalaran> {
  bool _buka = true;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _buka = widget.sedangAlir;
  }

  @override
  void didUpdateWidget(_BlokPenalaran lama) {
    super.didUpdateWidget(lama);
    // Selesai mengalir -> tutup sendiri, tapi jangan menimpa pilihan user.
    if (lama.sedangAlir && !widget.sedangAlir && !_manual) {
      setState(() => _buka = false);
    }
  }

  String get _judul {
    if (widget.sedangAlir) return 'Berpikir';
    final int ms = widget.pesan.penalaranMs;
    if (ms <= 0) return 'Berpikir';
    return 'Berpikir ${Waktu.durasi(ms)}';
  }

  @override
  Widget build(BuildContext context) {
    final Color aksen = AppColors.amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: aksen.withValues(alpha: 0.45),
            width: 2.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () {
              setState(() {
                _buka = !_buka;
                _manual = true;
              });
            },
            borderRadius: AppRadius.br8,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(LucideIcons.brain, size: 14, color: aksen),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _judul,
                    style: context.teks.labelMedium?.copyWith(color: aksen),
                  ),
                  AnimatedRotation(
                    turns: _buka ? 0.5 : 0,
                    duration: AppMotion.cepat,
                    curve: AppMotion.masuk,
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 14,
                      color: aksen.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.sedang,
            curve: AppMotion.emphasized,
            alignment: Alignment.topCenter,
            child: _buka
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    // Redup: isi berpikir bukan jawaban.
                    child: Opacity(
                      opacity: widget.sedangAlir ? 0.75 : 0.6,
                      child: TampilanMarkdown(
                        teks: widget.pesan.penalaran,
                        kecil: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TeksSedangMengalir extends StatefulWidget {
  @override
  State<_TeksSedangMengalir> createState() => _TeksSedangMengalirState();
}

class _TeksSedangMengalirState extends State<_TeksSedangMengalir>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Titik(warna: context.cs.primary, muncul: _c.value > 0.2),
          const SizedBox(width: AppSpacing.xs),
          _Titik(warna: context.cs.primary, muncul: _c.value > 0.5),
          const SizedBox(width: AppSpacing.xs),
          _Titik(warna: context.cs.primary, muncul: _c.value > 0.8),
        ],
      ),
    );
  }
}

class _Titik extends StatelessWidget {
  const _Titik({required this.warna, required this.muncul});

  final Color warna;
  final bool muncul;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.cepat,
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: warna.withValues(alpha: muncul ? 1 : 0.3),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _CatatanAlat extends StatelessWidget {
  const _CatatanAlat({required this.pesan});

  final Pesan pesan;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final CatatanAlat c in pesan.catatanAlat)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.toolSoft.withValues(
                alpha: context.gelap ? 0.22 : 0.9,
              ),
              borderRadius: AppRadius.br8,
              border: Border.all(
                color: AppColors.tool.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  c.status == StatusAlat.gagal
                      ? LucideIcons.triangleAlert
                      : LucideIcons.circleCheck,
                  size: 13,
                  color: c.status == StatusAlat.gagal
                      ? context.cs.error
                      : AppColors.tool,
                ),
                const SizedBox(width: AppSpacing.xxs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    '${c.nama}${c.ringkasan.isEmpty ? '' : ' · ${c.ringkasan}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.teks.labelSmall
                        ?.copyWith(color: AppColors.tool),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KartuGalat extends StatelessWidget {
  const _KartuGalat({required this.pesan, required this.onCobaLagi});

  final Pesan pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.cs.error.withValues(alpha: 0.10),
        borderRadius: AppRadius.br12,
        border: Border.all(color: context.cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(LucideIcons.circleAlert, size: 18, color: context.cs.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              pesan.pesanGalat.isEmpty
                  ? 'Terjadi kesalahan. Coba lagi.'
                  : pesan.pesanGalat,
              style: context.teks.bodySmall,
            ),
          ),
          TextButton(onPressed: onCobaLagi, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

/// Satu baris di lembar aksi pesan.
class _ItemMenu {
  const _ItemMenu(this.label, this.aksi, {this.bahaya = false});

  final String label;
  final VoidCallback? aksi;
  final bool bahaya;
}
