import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/klien_llm.dart';
import '../data/datasources/penyimpan_lokal.dart';
import '../data/repositories/repositori_memori.dart';
import '../data/repositories/repositori_riwayat.dart';
import '../data/repositories/repositori_setelan.dart';
import '../domain/entities/memori.dart';
import '../domain/entities/model_ai.dart';
import '../domain/entities/setelan.dart';
import '../features/agent/tools/daftar_alat.dart';
import '../services/memory_service.dart';
import '../services/streaming_service.dart';

/// Semua provider dikumpulkan di satu tempat supaya dependensinya jelas
/// dan tidak ada dua sumber kebenaran untuk state yang sama.

/// Di-override di main() setelah storage siap (lihat main.dart).
final Provider<SimpanCepit> simpanCepitProvider = Provider<SimpanCepit>(
  (ref) => throw UnimplementedError('simpanCepitProvider harus di-override'),
);

final Provider<SimpanBerkas> simpanBerkasProvider = Provider<SimpanBerkas>(
  (ref) => throw UnimplementedError('simpanBerkasProvider harus di-override'),
);

final Provider<RepositoriSetelan> repoSetelanProvider =
    Provider<RepositoriSetelan>((ref) =>
        RepositoriSetelan(ref.watch(simpanCepitProvider)));

final Provider<RepositoriRiwayat> repoRiwayatProvider =
    Provider<RepositoriRiwayat>((ref) =>
        RepositoriRiwayat(ref.watch(simpanBerkasProvider)));

final Provider<RepositoriMemori> repoMemoriProvider =
    Provider<RepositoriMemori>((ref) =>
        RepositoriMemori(ref.watch(simpanBerkasProvider)));

final Provider<KlienLlm> klienLlmProvider = Provider<KlienLlm>(
  (ref) => KlienLlm(),
);

final Provider<StreamingService> streamingServiceProvider =
    Provider<StreamingService>((ref) => StreamingService(
          klien: ref.watch(klienLlmProvider),
        ));

final Provider<MemoryService> memoryServiceProvider =
    Provider<MemoryService>((ref) => const MemoryService());

/// Daftar tool aktif mengikuti setelan terbaru.
final Provider<DaftarAlat> daftarAlatProvider = Provider<DaftarAlat>(
  (ref) => DaftarAlat(setelan: ref.watch(setelanProvider)),
);

// ---------------------------------------------------------------- setelan

class SetelanController extends Notifier<SetelanApp> {
  @override
  SetelanApp build() =>
      ref.watch(repoSetelanProvider).baca();

  Future<void> ubah(SetelanApp baru) async {
    state = baru;
    await ref.read(repoSetelanProvider).simpan(baru);
  }

  Future<void> setModel(String id) =>
      ubah(state.salin(modelId: id));

  Future<void> setTema(TemaMode m) => ubah(state.salin(tema: m));

  Future<void> setModeAgent(ModeAgent m) => ubah(state.salin(modeAgent: m));

  Future<void> setSuhu(double v) => ubah(state.salin(suhu: v.clamp(0, 2)));

  Future<void> setIzinWeb(bool v) => ubah(state.salin(izinkanWeb: v));

  Future<void> setIzinEmail(bool v) => ubah(state.salin(izinkanEmail: v));

  Future<void> setIzinKalkulator(bool v) =>
      ubah(state.salin(izinkanKalkulator: v));

  Future<void> setIngatMemori(bool v) => ubah(state.salin(ingatMemori: v));

  Future<void> setNama(String v) => ubah(state.salin(namaPengguna: v.trim()));

  Future<void> setWarnaDinamis(bool v) =>
      ubah(state.salin(pakaiWarnaDinamis: v));

  Future<void> setAutoRingkas(bool v) => ubah(state.salin(autoRingkas: v));

  Future<void> setPakaiSkill(bool v) =>
      ubah(state.salin(pakaiSkillPanduan: v));

  Future<void> setPromptTambahan(String v) =>
      ubah(state.salin(promptSistemTambahan: v));
}

final NotifierProvider<SetelanController, SetelanApp> setelanProvider =
    NotifierProvider<SetelanController, SetelanApp>(SetelanController.new);

// ---------------------------------------------------------------- katalog model

/// Diambil langsung dari provider (bukan daftar hardcode) supaya model baru
/// langsung muncul tanpa build ulang.
final FutureProvider<List<ModelAi>> katalogModelProvider =
    FutureProvider<List<ModelAi>>((ref) async {
  return ref.watch(klienLlmProvider).daftarModel();
});

/// Model yang sedang dipakai: mengikuti setelan, jatuh ke bawaan bila id
/// tidak ada (mis. user downgrade / provider berubah).
final Provider<ModelAi> modelProvider = Provider<ModelAi>((ref) {
  final SetelanApp s = ref.watch(setelanProvider);
  final AsyncValue<List<ModelAi>> katalog = ref.watch(katalogModelProvider);
  final List<ModelAi> daftar = katalog.valueOrNull ?? ModelAi.bawaan;
  return ModelAi.cari(s.modelId, daftar) ??
      ModelAi.cari(s.modelId) ??
      daftar.first;
});

// ---------------------------------------------------------------- memori

class MemoriController extends Notifier<List<EntriMemori>> {
  @override
  List<EntriMemori> build() => <EntriMemori>[];

  Future<void> muat() async {
    state = await ref.read(repoMemoriProvider).semua();
  }

  Future<EntriMemori?> simpan(String isi, String kategori) async {
    final EntriMemori e = await ref
        .read(repoMemoriProvider)
        .tambah(isi: isi, kategori: kategori);
    await muat();
    return e;
  }

  Future<void> hapus(String id) async {
    await ref.read(repoMemoriProvider).hapus(id);
    await muat();
  }

  Future<void> hapusSemua() async {
    await ref.read(repoMemoriProvider).hapusSemua();
    state = <EntriMemori>[];
  }
}

final NotifierProvider<MemoriController, List<EntriMemori>> memoriProvider =
    NotifierProvider<MemoriController, List<EntriMemori>>(MemoriController.new);

final FutureProviderFamily<List<EntriMemori>, String> memoriCariProvider =
    FutureProvider.family<List<EntriMemori>, String>(
  (ref, String kueri) =>
      ref.watch(repoMemoriProvider).cari(kueri, maks: 5),
);
