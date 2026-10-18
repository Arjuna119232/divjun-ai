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
import '../../skills/data/skill_providers.dart';

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

  bool get adaPesan => aktif?.pesan.isNotEmpty ?? false;

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
  final Map<String, _Akumulator> _buffer = <String, _Akumulator>{};

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

  /// Sematkan / lepas sematan. Tidak mengubah `diperbarui` supaya urutan
  /// "Terbaru" tetap stabil saat hanya menyematkan.
  Future<void> sematkan(String id, bool nilai) async {
    final Percakapan? p = _cari(id);
    if (p == null || p.disematkan == nilai) return;
    final Percakapan baru = Percakapan(
      id: p.id,
      judul: p.judul,
      dibuat: p.dibuat,
      diperbarui: p.diperbarui,
      pesan: p.pesan,
      disematkan: nilai,
    );
    state = state.salin(
      daftar: state.daftar
          .map((Percakapan q) => q.id == id ? baru : q)
          .toList(),
    );
    await _repo.simpan(baru);
  }

  /// Ganti nama percakapan. Judul kosong diabaikan.
  Future<void> gantiNama(String id, String judul) async {
    final String bersih = judul.trim();
    final Percakapan? p = _cari(id);
    if (p == null || bersih.isEmpty || bersih == p.judul) return;
    final Percakapan baru = Percakapan(
      id: p.id,
      judul: bersih,
      dibuat: p.dibuat,
      diperbarui: p.diperbarui,
      pesan: p.pesan,
      disematkan: p.disematkan,
    );
    state = state.salin(
      daftar: state.daftar
          .map((Percakapan q) => q.id == id ? baru : q)
          .toList(),
    );
    await _repo.simpan(baru);
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
    // Auto-pilih model selalu aktif (v3.0.0): lihat SetelanApp.modeAgent.
    final ModelAi model = AgentLoop.pilihOtomatis(
      pesan: isi,
      katalog: katalog,
      fallback: terpilih,
    );

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

    // Pustaka skill internal: kalau ada skill yang cocok dengan pertanyaan,
    // isinya disuntik sebagai prosedur kerja (bukan sumber jawaban).
    // Panduan skill selalu disuntik (v3.0.0): lihat SetelanApp.pakaiSkillPanduan.
    final String? panduanSkill =
        await ref.read(skillRepositoryProvider).panduanUntuk(isi);

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
          panduanSkill: panduanSkill,
        ),
        riwayat: riwayat,
        onTeks: (String potongan) => _appendTeks(idPesanAi, potongan),
        onPenalaran: (String potongan) => _appendPenalaran(idPesanAi, potongan),
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
      // PENTING: ambil isi buffer SEBELUM dihapus. Urutan lama
      // (remove dulu, baru baca) membuat seluruh teks yang sudah tampil
      // hilang begitu stream gagal - user cuma lihat bubble kosong.
      final _Akumulator? sisa = _buffer[idPesanAi];
      final String teksSisa = sisa?.teks.toString() ?? '';
      final String penalaranSisa = sisa?.penalaran.toString().trim() ?? '';
      final int msSisa = sisa == null || penalaranSisa.isEmpty
          ? 0
          : DateTime.now().difference(sisa.mulai).inMilliseconds;
      _buffer.remove(idPesanAi);
      _tulisPesanAi(
        idPesanAi,
        Pesan(
          id: idPesanAi,
          peran: Peran.ai,
          isi: teksSisa,
          waktu: DateTime.now(),
          status: StatusPesan.gagal,
          pesanGalat: 'Gagal memproses: $e',
          penalaran: penalaranSisa,
          penalaranMs: msSisa,
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

  /// Riwayat untuk model: semua pesan kecuali pesan AI yang sedang mengalir.
  List<Pesan> _pesanUntukModel(String idPercakapan, String idDilewati) {
    final Percakapan? p = _cari(idPercakapan);
    if (p == null) return <Pesan>[];
    List<Pesan> pesan =
        p.pesan.where((Pesan x) => x.id != idDilewati).toList();

    // Manajemen konteks: kalau riwayat menumpuk, ringkas jadi 1 pesan +
    // 6 pesan terakhir supaya token tetap hemat.
    final int karakter =
        pesan.fold<int>(0, (int a, Pesan x) => a + x.isi.length);
    // Auto-ringkas selalu aktif (v3.0.0): lihat SetelanApp.autoRingkas.
    if (karakter > AppConfig.ambangRingkas && pesan.length > 8) {
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
        disematkan: p.disematkan,
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
    (_buffer[idPesan] ??= _Akumulator()).teks.write(potongan);
    _jadwalFlush();
  }

  /// Penalaran dikirim terpisah dari jawaban; dicatat terpisah juga supaya
  /// blok "Berpikir" bisa tampil live lalu menyimpan durasinya.
  void _appendPenalaran(String idPesan, String potongan) {
    final _Akumulator a = _buffer[idPesan] ??= _Akumulator();
    a.penalaran.write(potongan);
    _jadwalFlush();
  }

  void _jadwalFlush() {
    _throttle ??= Timer(AppMotion.d40, () {
      _throttle = null;
      _flushBuffer();
    });
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;
    for (final MapEntry<String, _Akumulator> e in _buffer.entries) {
      final _Akumulator a = e.value;
      state = state.salin(
        daftar: state.daftar.map((Percakapan p) => _salin(
              p,
              isi: <Pesan>[
                for (final Pesan x in p.pesan)
                  if (x.id == e.key)
                    x.salin(
                      isi: a.teks.toString(),
                      penalaran: a.penalaran.toString(),
                      penalaranMs: a.penalaran.isEmpty
                          ? x.penalaranMs
                          : DateTime.now().difference(a.mulai).inMilliseconds,
                    )
                  else
                    x,
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

/// Penampung token yang belum dirapikan ke state (throttled 40 ms).
///
/// Dua buffer terpisah: jawaban ([teks]) dan isi berpikir ([penalaran]).
/// Dicampur dalam satu StringBuffer = blok "Berpikir" tidak bisa dipisah
/// dari jawaban di UI.
class _Akumulator {
  _Akumulator() : mulai = DateTime.now();

  final DateTime mulai;
  final StringBuffer teks = StringBuffer();
  final StringBuffer penalaran = StringBuffer();
}
