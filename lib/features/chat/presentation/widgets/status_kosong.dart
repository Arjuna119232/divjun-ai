import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';

/// Empty state yang dirancang, bukan layar kosong:
/// logo + salam + 4 saran yang bisa langsung diklik.
class StatusKosong extends StatelessWidget {
  const StatusKosong({
    super.key,
    required this.salam,
    required this.saran,
    required this.onPilih,
  });

  final String salam;
  final List<String> saran;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints batas) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: batas.maxHeight - 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _LambangBerdenyut(),
                const SizedBox(height: AppSpacing.xl),
                Text(salam, style: context.teks.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tanya apa saja. DIVJUN bisa hitung, buka web, '
                  'ingat catatan, dan membuat draf email.',
                  style: context.teks.bodyMedium?.copyWith(
                    color: context.cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Coba ini', style: context.teks.labelMedium),
                const SizedBox(height: AppSpacing.sm),
                // Wrap, bukan kolom: di layar sempit chip membungkus sendiri,
                // jadi tidak ada kartu selebar layar yang terbaca seperti form.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String s in saran)
                      _ChipSaran(teks: s, onTekan: () => onPilih(s)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lambang berdenyut: gradasian brand + halo yang berdenyut pelan. State-nya
/// bergerak, jadi layar kosong tidak terasa mati.
class _LambangBerdenyut extends StatefulWidget {
  const _LambangBerdenyut();

  @override
  State<_LambangBerdenyut> createState() => _LambangBerdenyutState();
}

class _LambangBerdenyutState extends State<_LambangBerdenyut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) {
        return Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.brand, AppColors.brandDeep],
            ),
            borderRadius: AppRadius.br16,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.18 + _c.value * 0.22),
                blurRadius: 18 + _c.value * 14,
                spreadRadius: _c.value * 2,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'D',
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppTypography.ui,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChipSaran extends StatelessWidget {
  const _ChipSaran({required this.teks, required this.onTekan});

  final String teks;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cs.surfaceContainer,
      borderRadius: AppRadius.br14,
      child: InkWell(
        borderRadius: AppRadius.br14,
        onTap: onTekan,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 11,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                LucideIcons.arrowUpRight,
                size: 15,
                color: context.cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(teks, style: context.teks.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton shimmer - dipakai selagi riwayat dimuat (bukan spinner polos).
class KerangkaPesan extends StatefulWidget {
  const KerangkaPesan({super.key, required this.dariPengguna});

  final bool dariPengguna;

  @override
  State<KerangkaPesan> createState() => _KerangkaPesanState();
}

class _KerangkaPesanState extends State<KerangkaPesan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.dariPengguna
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          final double t = (_c.value * 2) % 2;
          final double opacity = 0.35 + (t < 1 ? t : 2 - t) * 0.3;
          return Container(
            width: widget.dariPengguna ? 180 : 240,
            height: 58,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerHigh
                  .withValues(alpha: opacity),
              borderRadius: AppRadius.bubble(isUser: widget.dariPengguna),
            ),
          );
        },
      ),
    );
  }
}

class KerangkaRiwayat extends StatelessWidget {
  const KerangkaRiwayat({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          KerangkaPesan(dariPengguna: true),
          KerangkaPesan(dariPengguna: false),
          KerangkaPesan(dariPengguna: false),
          KerangkaPesan(dariPengguna: true),
        ],
      ),
    );
  }
}
