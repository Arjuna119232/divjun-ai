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
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: batas.maxHeight - 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[AppColors.brand, AppColors.brandDeep],
                    ),
                    borderRadius: AppRadius.br16,
                  ),
                  child: const Center(
                    child: Text(
                      'D',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: AppTypography.ui,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
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
                for (final String s in saran)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _KartuSaran(teks: s, onTekan: () => onPilih(s)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KartuSaran extends StatelessWidget {
  const _KartuSaran({required this.teks, required this.onTekan});

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
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                LucideIcons.arrowUpRight,
                size: 16,
                color: context.cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(teks, style: context.teks.bodyMedium),
              ),
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
