import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/skill.dart';
import 'skill_repository.dart';

final Provider<SkillRepository> skillRepositoryProvider =
    Provider<SkillRepository>((ref) => SkillRepository());

final FutureProvider<IndeksSkill> indeksSkillProvider =
    FutureProvider<IndeksSkill>(
  (ref) => ref.watch(skillRepositoryProvider).muatIndeks(),
);

final Provider<int> jumlahSkillProvider = Provider<int>(
  (ref) => ref.watch(indeksSkillProvider).valueOrNull?.jumlah ?? 0,
);
