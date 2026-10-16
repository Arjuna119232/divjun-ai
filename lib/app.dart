import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/setelan.dart';

class DivjunApp extends ConsumerWidget {
  const DivjunApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SetelanApp setelan = ref.watch(setelanProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? terang, ColorScheme? gelap) {
        return MaterialApp.router(
          title: 'DIVJUN AI',
          debugShowCheckedModeBanner: false,
          themeMode: setelan.tema.themeMode,
          theme: AppTheme.light(setelan.pakaiWarnaDinamis ? terang : null),
          darkTheme: AppTheme.dark(setelan.pakaiWarnaDinamis ? gelap : null),
          routerConfig: appRouter,
          builder: (BuildContext context, Widget? child) {
            // Batasi textScale supaya layout tidak pecah di font besar,
            // tapi tetap hormati sebagian preferensi user.
            final MediaQueryData mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

extension TemaModeX on TemaMode {
  static ThemeMode dari(TemaMode m) => switch (m) {
        TemaMode.sistem => ThemeMode.system,
        TemaMode.terang => ThemeMode.light,
        TemaMode.gelap => ThemeMode.dark,
      };
}

extension SetelanTemaX on SetelanApp {
  ThemeMode get themeMode => TemaModeX.dari(tema);
}
