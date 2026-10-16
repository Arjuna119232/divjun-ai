import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/teks.dart';
import '../../../data/repositories/repositori_riwayat.dart';
import '../../../domain/entities/memori.dart';
import '../../../domain/entities/model_ai.dart';
import '../../../domain/entities/percakapan.dart';
import '../../../domain/entities/setelan.dart';
import '../../../services/tool_executor.dart';
import '../../agent/loop/agent_loop.dart';
import '../../agent/tools/alat.dart';

/// State chat: daftar percakapan + percakapan aktif + status sibuk.
class StateChat {
  const StateChat({
    this.daftar = const <Percakapan>[],
    this.aktifId,
    this.sibuk = false,
    this.sudahSiap = false,
    this.langkahAgent = 0,
  });

  final List<Percakapan> daftar;
  final String? aktifId;
  final bool sibuk;
  final bool sudahSiap;
  final int langkahAgent;

  Percakapan? get aktif {
    if (aktifId == null) return null;
    for (final Percakapan p in daftar) {
      if (p.id == aktifId) return p;
    }
    return null;
  }

  bool get adaPesan => (aktif?.pesan.isNotEmpty) ?? false;

  StateChat salin({
    List<Percakapan>? daftar,
    String? aktifId,
    bool? sibuk,
    bool? sudahSiap,
    int? langkahAgent,
    bool resetAktif = false,
  }) =>
      StateChat(
        daftar: daftar ?? this.daftar,
        aktifId: resetAktif ? aktifId : (aktifId ?? this.aktifId),
        sibuk: sibuk ?? this.sibuk,
        sudahSiap: sudahSiap ?? this.sudahSiap,
        langkahAgent: langkahAgent ?? this.langkahAgent,
      );
}

/// Controller percakapan: kirim pesan, stream jawaban, jalankan agent,
/// simpan ke storage, dan batalkan saat user menekan stop.
class ChatController extends Notifier<StateChat> {
  Timer? _throttle;
  bool _batal = false;
  final Map<String, StringBuffer> _buffer = <String, StringBuffer>{};

  RepositoriRiwayat get _repo => ref.read(repoRiwayatProvider);

  @override
  StateChat build() {
    ref.onDispose(() {
      _throttle?.cancel();
      ref.read(streamingServiceProvider).stop();
    });
    return const StateChat();
  }

  Future<void> muat() async {
    final List<Percakapan> daftar = await _repo.semua();
    state = StateChat(
      daftar: daftar,
      aktifId: daftar.isEmpty ? null : daftar.first.id,
      sudahSiap: true,
    );
  }

  // ------------------------------------------------------------ percakapan

  Future<Percakapan> _atauBuat() async {
    final Percakapan? sekarang = state.aktif;
    if (sekarang != null) return sekarang;
    final Percakapan baru = await _repo.buat();
    state = state.salin(
      daftar: <Percakapan>[baru, ...state.daftar],
      aktifId: baru.id,
      sudahSiap: true,
    );
    return baru;
  }

  void pilih(String id) {
    if (id == state.aktifId) return;
    state = state.salin(aktifId: id);
  }

  Future<void> buatPercakapanBaru() async {
    final Percakapan baru = await _repo.buat();
    state = state.salin(
      daftar: <Percakapan>[baru, ...state.daftar],
      aktifId: baru.id,
    );
  }

  Future<void> hapusPercakapan(String id) async {
    await _repo.hapus(id);
    final List<Percakapan> baru =
        state.daftar.where((Percakapan p) => p.id != id).toList();
    state = state.salin(
      daftar: baru,
      aktifId: state.aktifId == id ? null : state.aktifId,
      resetAktif: state.aktifId == id,
    );
  }

  Future<void> hapusSemua() async {
    await _repo.hapusSemua();
    state = const StateChat(daftar: <Percakapan>[], sudahSiap: true);
  }

  // ------------------------------------------------------------ kirim

  Future<void> kirim(String teks) async {
    final String isi = teks.trim();
    if (isi.isEmpty || state.sibuk) return;

    final Percakapan percakapan = await _atauBuat();
    _batal = false;

    _tambahPesan(
      percakapan.id,
      Pesan(
        id: 'msg-${Id.pendek(12)}',
        peran: Peran.pengguna,
        isi: isi,
        waktu: DateTime.now(),
      ),
    );
    state = state.salin(sibuk: true, langkahAgent: 0);

    final SetelanApp setelan = ref.read(setelanProvider);
    final List<ModelAi> katalog =
        ref.read(katalogModelProvider).valueOrNull ?? ModelAi.bawaan;
    final ModelAi terpilih = ref.read(modelProvider);
    final ModelAi model = setelan.modeAgent == ModeAgent.auto
        ? AgentLoop.pilihOtomatis(
            pesan: isi,
            katalog: katalog,
            fallback: terpilih,
          )
        : terpilih;

    final String idPesanAi = 'msg-${Id.pendek(12)}';
    _tambahPesan(
      percakapan.id,
      Pesan(
        id: idPesanAi,
        peran: Peran.ai,
        isi: '',
        waktu: DateTime.now(),
        status: StatusPesan.mengalir,
        modelId: model.id,
      ),
    );

    // Memori: ambil yang relevan dengan pesan ini, bukan semua.
    final List<EntriMemori> memori = setelan.ingatMemori
        ? await ref.read(repoMemoriProvider).cari(isi, maks: 5)
        : <EntriMemori>[];
    if (memori.isNotEmpty) {
      await ref
          .read(repoMemoriProvider)
          .tandaiDipakai(memori.map((EntriMemori e) => e.id).toList());
    }

    final List<Pesan> riwayat = _pesanUntukModel(percakapan.id, idPesanAi);

    final AgentLoop loop = AgentLoop(
      streaming: ref.read(streamingServiceProvider),
      memori: ref.read(memoryServiceProvider),
      executor: ToolExecutor(ref.read(daftarAlatProvider)),
      daftar: ref.read(daftarAlatProvider),
    );

    try {
      final Pesan hasil = await loop.jalankan(
        idPesan: idPesanAi,
        model: model,
        setelan: setelan,
        systemPrompt: ref.read(memoryServiceProvider).systemPrompt(
          namaPengguna: setelan.namaPengguna,
          agentAktif: setelan.agentAktif,
          promptTambahan: setelan.promptSistemTambahan,
          memori: memori,
          bisaWeb: setelan.izinkanWeb,
        ),
        riwayat: riwayat,
        onTeks: (String potongan) => _appendTeks(idPesanAi, potongan),
        onAlat: (CatatanAlat c) {
          state = state.salin(langkahAgent: state.langkahAgent + 1);
          _tambahCatatan(idPesanAi, c);
        },
        sudahBatal: () => _batal,
        konteks: KonteksAlat(
          setelan: setelan,
          simpanMemori: ({required String isi, String kategori = 'umum'}) =>
              ref.read(repoMemoriProvider).tambah(isi: isi, kategori: kategori),
          bacaMemori: (String kueri) =>
              ref.read(repoMemoriProvider).cari(kueri),
          sudahBatal: () => _batal,
        ),
      );
      _buffer.remove(idPesanAi);
      _tulisPesanAi(idPesanAi, hasil);
    } catch (e) {
      _buffer.remove(idPesanAi);
      _tulisPesanAi(
        idPesanAi,
        Pesan(
          id: idPesanAi,
          peran: Peran.ai,
          isi: _bufferTeks(idPesanAi),
          waktu: DateTime.now(),
          status: StatusPesan.gagal,
          pesanGalat: 'Gagal memproses: $e',
        ),
      );
    } finally {
      _throttle?.cancel();
      _throttle = null;
      state = state.salin(sibuk: false, langkahAgent: 0);
      await _simpanAktif();
    }
  }

  void stop() {
    _batal = true;
    ref.read(streamingServiceProvider).stop();
    _throttle?.cancel();
    _throttle = null;
    _tandai(status: StatusPesan.dibatalkan);
    state = state.salin(sibuk: false, langkahAgent: 0);
  }

  String _bufferTeks(String idPesan) => _buffer[idPesan]?.toString() ?? '';

  /// Riwayat untuk model: semua pesan kecuali pesan AI yang sedang mengalir.
  List<Pesan> _pesanUntukModel(String idPercakapan, String idDilewati) {
    final Percakapan? p = _cari(idPercakapan);
    if (p == null) return <Pesan>[];
    final SetelanApp setelan = ref.read(setelanProvider);
    List<Pesan> pesan =
        p.pesan.where((Pesan x) => x.id != idDilewati).toList();

    // Manajemen konteks: kalau riwayat menumpuk, ringkas jadi 1 pesan +
    // 6 pesan terakhir supaya token tetap hemat.
    final int karakter =
        pesan.fold<int>(0, (int a, Pesan x) => a + x.isi.length);
    if (setelan.autoRingkas &&
        karakter > AppConfig.ambangRingkas &&
        pesan.length > 8) {
      final String ringkasan = ref.read(memoryServiceProvider).ringkas(pesan);
      pesan = <Pesan>[
        Pesan(
          id: 'msg-ringkas-${DateTime.now().millisecondsSinceEpoch}',
          peran: Peran.sistem,
          isi: ringkasan,
          waktu: DateTime.now(),
        ),
        ...pesan.skip(pesan.length - 6),
      ];
    }
    return pesan;
  }

  // ------------------------------------------------------------ mutasi state

  Percakapan? _cari(String id) {
    for (final Percakapan p in state.daftar) {
      if (p.id == id) return p;
    }
    return null;
  }

  Percakapan _salin(Percakapan p, {List<Pesan>? isi, String? judul}) =>
      Percakapan(
        id: p.id,
        judul: judul ?? p.judul,
        dibuat: p.dibuat,
        diperbarui: DateTime.now(),
        pesan: isi ?? p.pesan,
      );

  List<Percakapan> _ganti(
    String idPercakapan,
    List<Pesan> Function(List<Pesan> isi) ubah,
  ) =>
      state.daftar.map((Percakapan p) {
        if (p.id != idPercakapan) return p;
        return _salin(p, isi: ubah(p.pesan));
      }).toList();

  void _tambahPesan(String idPercakapan, Pesan pesan) {
    state = state.salin(
      daftar: _ganti(
        idPercakapan,
        (List<Pesan> isi) => <Pesan>[...isi, pesan],
      ),
    );
    // Judul otomatis dari pesan user pertama.
    final Percakapan? p = _cari(idPercakapan);
    if (p != null && pesan.dariPengguna && p.judul == 'Percakapan baru') {
      state = state.salin(
        daftar: state.daftar
            .map((Percakapan q) => q.id == idPercakapan
                ? _salin(q, judul: RepositoriRiwayat.judulOtomatis(pesan.isi))
                : q)
            .toList(),
      );
    }
  }

  /// Token datang sangat cepat; notifikasi Riverpod di-throttle 40 ms supaya
  /// UI tidak rebuild ratusan kali per detik (masih terasa mengalir).
  void _appendTeks(String idPesan, String potongan) {
    (_buffer[idPesan] ??= StringBuffer()).write(potongan);
    _throttle ??= Timer(AppMotion.d40, () {
      _throttle = null;
      _flushBuffer();
    });
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;
    for (final MapEntry<String, StringBuffer> e in _buffer.entries) {
      final String isi = e.value.toString();
      state = state.salin(
        daftar: state.daftar.map((Percakapan p) => _salin(
              p,
              isi: <Pesan>[
                for (final Pesan x in p.pesan)
                  if (x.id == e.key) x.salin(isi: isi) else x,
              ],
            )).toList(),
      );
    }
  }

  void _tulisPesanAi(String idPesan, Pesan baru) {
    state = state.salin(
      daftar: state.daftar.map((Percakapan p) => _salin(
            p,
            isi: <Pesan>[
              for (final Pesan x in p.pesan) x.id == idPesan ? baru : x,
            ],
          )).toList(),
    );
  }

  void _tambahCatatan(String idPesan, CatatanAlat c) {
    state = state.salin(
      daftar: state.daftar.map((Percakapan p) => _salin(
            p,
            isi: <Pesan>[
              for (final Pesan x in p.pesan)
                if (x.id == idPesan)
                  x.salin(catatanAlat: <CatatanAlat>[...x.catatanAlat, c])
                else
                  x,
            ],
          )).toList(),
    );
  }

  void _tandai({required StatusPesan status}) {
    for (final Percakapan p in state.daftar) {
      final Pesan? terakhir = p.terakhir;
      if (terakhir == null || !terakhir.dariAi || !terakhir.sedangMengalir) {
        continue;
      }
      state = state.salin(
        daftar: state.daftar.map((Percakapan q) {
          if (q.id != p.id) return q;
          return _salin(
            q,
            isi: <Pesan>[
              for (final Pesan x in q.pesan)
                if (x.id == terakhir.id) x.salin(status: status) else x,
            ],
          );
        }).toList(),
      );
      break;
    }
  }

  Future<void> _simpanAktif() async {
    final Percakapan? p = state.aktif;
    if (p != null) await _repo.simpan(p);
  }

  // ------------------------------------------------------------ edit pesan

  Future<void> editPesan(String idPesan, String isiBaru) async {
    final Percakapan? p = state.aktif;
    if (p == null) return;
    state = state.salin(
      daftar: <Percakapan>[
        _salin(
          p,
          isi: <Pesan>[
            for (final Pesan x in p.pesan)
              if (x.id == idPesan) x.salin(isi: isiBaru) else x,
          ],
        ),
        ...state.daftar.where((Percakapan q) => q.id != p.id),
      ],
    );
    await _simpanAktif();
  }

  Future<void> hapusPesan(String idPesan) async {
    final Percakapan? p = state.aktif;
    if (p == null) return;
    state = state.salin(
      daftar: <Percakapan>[
        _salin(
          p,
          isi: p.pesan.where((Pesan x) => x.id != idPesan).toList(),
        ),
        ...state.daftar.where((Percakapan q) => q.id != p.id),
      ],
    );
    await _simpanAktif();
  }

  /// Ulangi jawaban terakhir: buang pesan AI terakhir lalu kirim ulang pesan
  /// user sebelumnya (bukan menambah duplikat).
  Future<void> kirimUlang() async {
    final Percakapan? p = state.aktif;
    if (p == null || state.sibuk) return;

    Pesan? target;
    for (final Pesan x in p.pesan.reversed) {
      if (x.dariPengguna) {
        target = x;
        break;
      }
    }
    if (target == null) return;

    final List<Pesan> dipotong = <Pesan>[];
    bool lewat = false;
    for (final Pesan x in p.pesan) {
      if (x.id == target.id) lewat = true;
      if (!lewat) dipotong.add(x);
    }
    state = state.salin(
      daftar: <Percakapan>[
        _salin(p, isi: dipotong),
        ...state.daftar.where((Percakapan q) => q.id != p.id),
      ],
    );
    await _simpanAktif();
    await kirim(target.isi);
  }

  /// Ringkas jawaban terakhir (tombol di menu bubble).
  Future<void> ringkasJawabanTerakhir() async {
    final Percakapan? p = state.aktif;
    final Pesan? terakhir = p?.terakhir;
    if (p == null || terakhir == null || !terakhir.dariAi) return;
    final String ringkas = Teks.ringkas(terakhir.isi, 320);
    state = state.salin(
      daftar: <Percakapan>[
        _salin(
          p,
          isi: <Pesan>[
            ...p.pesan,
            Pesan(
              id: 'msg-${Id.pendek(12)}',
              peran: Peran.ai,
              isi: 'Ringkasan jawaban:\n\n$ringkas',
              waktu: DateTime.now(),
              modelId: terakhir.modelId,
            ),
          ],
        ),
        ...state.daftar.where((Percakapan q) => q.id != p.id),
      ],
    );
    await _simpanAktif();
  }
}

final NotifierProvider<ChatController, StateChat> chatProvider =
    NotifierProvider<ChatController, StateChat>(ChatController.new);
