import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/waktu.dart';
import '../../../../domain/entities/percakapan.dart';
import '../../../../shared/widgets/tampilan_markdown.dart';
import '../../../artifacts/presentation/isi_jawaban.dart';

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
              if (!user) ...<Widget>[
                Text(Waktu.jam(pesan.waktu), style: context.teks.labelSmall),
              ],
            ],
          ),
          if (pesan.status == StatusPesan.gagal && onCobaLagi != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _KartuGalat(pesan: pesan, onCobaLagi: onCobaLagi!),
          ],
          // Deretan aksi + disclaimer: hanya untuk jawaban AI yang sudah
          // selesai (bukan saat mengalir / gagal).
          if (!user &&
              pesan.status == StatusPesan.selesai &&
              pesan.isi.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _AksiPesan(pesan: pesan, onUlang: onUlang),
          ],
        ],
      ),
    );
  }

  Widget _isi(BuildContext context, Color teks) {
    final bool adaPenalaran = pesan.punyaPenalaran;

    if (pesan.isi.isEmpty) {
      // Belum ada token final sama sekali: masih awal proses berpikir.
      if (pesan.status == StatusPesan.mengalir) {
        return _BlokBerpikir(
          sedangAlir: true,
          penalaranMs: pesan.penalaranMs,
        );
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

    // AI sudah ada isi final.
    if (pesan.status == StatusPesan.mengalir) {
      // Masih memproses: tampilkan HANYA "Berpikir..." + titik-tiga.
      // Sembunyikan teks mentah proses berpikir dan teks jawaban yang masih
      // mengalir agar user tidak melihat isi mentah dari API.
      return _BlokBerpikir(
        sedangAlir: true,
        penalaranMs: pesan.penalaranMs,
      );
    }

    // Selesai: tampilkan jawaban final, lalu accordion untuk proses berpikir.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IsiJawaban(teks: pesan.isi),
        if (adaPenalaran) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _BlokBerpikir(
            sedangAlir: false,
            penalaranMs: pesan.penalaranMs,
            pesan: pesan,
          ),
        ],
      ],
    );
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

/// Blok "Berpikir": proses berpikir model.
///
/// - Saat `sedangAlir == true`: hanya tampilkan teks "Berpikir..." dengan
///   animasi titik-tiga, **jangan pernah** render teks mentah proses berpikir
///   dari API agar pengguna tidak melihat isi mentahnya.
/// - Saat `sedangAlir == false` dan ada [penalaran]: tampilkan judul
///   "Berpikir selama X detik" sebagai ExpansionTile (accordion). Diklik baru
///   teks mentah proses berpikir ditampilkan.
class _BlokBerpikir extends StatefulWidget {
  const _BlokBerpikir({
    required this.sedangAlir,
    required this.penalaranMs,
    this.pesan,
  });

  final bool sedangAlir;
  final int penalaranMs;
  final Pesan? pesan;

  @override
  State<_BlokBerpikir> createState() => _BlokBerpikirState();
}

class _BlokBerpikirState extends State<_BlokBerpikir> {
  /// Accordion belum pernah dibuka oleh user.
  bool _buka = false;

  String get _judul {
    final int ms = widget.penalaranMs;
    if (ms <= 0) return 'Berpikir selama 0 detik';
    return 'Berpikir selama ${Waktu.durasi(ms)}';
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
            onTap: widget.sedangAlir
                ? null
                : () {
                    setState(() => _buka = !_buka);
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
                    widget.sedangAlir ? 'Berpikir...' : _judul,
                    style: context.teks.labelMedium?.copyWith(color: aksen),
                  ),
                  const Spacer(),
                  if (!widget.sedangAlir)
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
                  if (widget.sedangAlir) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    _Titik(
                      warna: aksen,
                      muncul: true,
                    ),
                    const SizedBox(width: 4),
                    _Titik(
                      warna: aksen,
                      muncul: true,
                    ),
                    const SizedBox(width: 4),
                    _Titik(
                      warna: aksen,
                      muncul: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!widget.sedangAlir &&
              widget.pesan != null &&
              widget.pesan!.penalaran.trim().isNotEmpty &&
              _buka)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              // Redup: isi berpikir bukan jawaban.
              child: Opacity(
                opacity: 0.6,
                child: TampilanMarkdown(
                  teks: widget.pesan!.penalaran,
                  kecil: true,
                ),
              ),
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

/// Deretan ikon aksi di bawah jawaban AI + disclaimer kecil.
///
/// Muncul HANYA setelah jawaban selesai. Ikon outline abu di baris atas,
/// teks disclaimer di bawahnya - keduanya DI LUAR bubble (bukan bagian dari
/// kotak warna) supaya terasa seperti metadata, bukan isi jawaban.
class _AksiPesan extends StatefulWidget {
  const _AksiPesan({required this.pesan, this.onUlang});

  final Pesan pesan;
  final VoidCallback? onUlang;

  @override
  State<_AksiPesan> createState() => _AksiPesanState();
}

class _AksiPesanState extends State<_AksiPesan> {
  /// 0 = belum dinilai, 1 = suka, 2 = tidak suka.
  int _nilai = 0;

  void _pesanSingkat(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(teks), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Color abu = context.cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Ikon(
                ikon: LucideIcons.copy,
                tooltip: 'Salin',
                warna: abu,
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: widget.pesan.isi),
                  );
                  if (mounted) _pesanSingkat('Teks disalin');
                },
              ),
              const SizedBox(width: 18),
              _Ikon(
                ikon: LucideIcons.share,
                tooltip: 'Bagikan',
                warna: abu,
                onTap: () => SharePlus.instance.share(
                  ShareParams(text: widget.pesan.isi),
                ),
              ),
              const SizedBox(width: 18),
              _Ikon(
                ikon: LucideIcons.play,
                tooltip: 'Bacakan',
                warna: abu,
                onTap: () => _pesanSingkat('Fitur bacakan suara segera hadir'),
              ),
              const SizedBox(width: 18),
              _Ikon(
                ikon: LucideIcons.thumbsUp,
                tooltip: 'Jawaban bagus',
                warna: _nilai == 1 ? context.cs.primary : abu,
                onTap: () {
                  setState(() => _nilai = 1);
                  _pesanSingkat('Terima kasih atas masukannya');
                },
              ),
              const SizedBox(width: 18),
              _Ikon(
                ikon: LucideIcons.thumbsDown,
                tooltip: 'Jawaban kurang',
                warna: _nilai == 2 ? context.cs.error : abu,
                onTap: () {
                  setState(() => _nilai = 2);
                  _pesanSingkat('Masukan Anda dicatat');
                },
              ),
              const SizedBox(width: 18),
              _Ikon(
                ikon: LucideIcons.refreshCw,
                tooltip: 'Buat ulang',
                warna: abu,
                onTap: widget.onUlang,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${AppConfig.appName} adalah AI dan dapat melakukan kesalahan.',
            style: context.teks.labelSmall?.copyWith(color: abu),
          ),
        ],
      ),
    );
  }
}

class _Ikon extends StatelessWidget {
  const _Ikon({
    required this.ikon,
    required this.tooltip,
    required this.warna,
    this.onTap,
  });

  final IconData ikon;
  final String tooltip;
  final Color warna;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 20,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Icon(
          ikon,
          size: 18,
          color: onTap == null ? warna.withValues(alpha: 0.4) : warna,
        ),
      ),
    );
  }
}
