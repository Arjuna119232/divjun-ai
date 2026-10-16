import 'dart:async';

import '../../../core/constants/app_config.dart';
import '../../../core/utils/teks.dart';
import '../../../data/datasources/klien_llm.dart';
import '../../../data/models/chat_api.dart';
import '../../../domain/entities/model_ai.dart';
import '../../../domain/entities/percakapan.dart';
import '../../../domain/entities/setelan.dart';
import '../../../services/memory_service.dart';
import '../../../services/streaming_service.dart';
import '../../../services/tool_executor.dart';
import '../tools/alat.dart';
import '../tools/daftar_alat.dart';

typedef EmitTeks = void Function(String potongan);
typedef EmitAlat = void Function(CatatanAlat catatan);
typedef CekBatal = bool Function();

/// Agent loop: plan -> act -> observe -> repeat.
///
/// Satu putaran = satu panggilan LLM. Kalau model meminta tool, tool
/// dieksekusi, hasilnya ditempel sebagai pesan `tool`, lalu model dipanggil
/// lagi dengan hasil tersebut. Maks [AppConfig.maksLangkahAgent] putaran,
/// lalu berhenti dan jujur bilang ke user kalau mentok.
class AgentLoop {
  AgentLoop({
    required StreamingService streaming,
    required MemoryService memori,
    required ToolExecutor executor,
    required DaftarAlat daftar,
  })  : _streaming = streaming,
        _memori = memori,
        _executor = executor,
        _daftar = daftar;

  final StreamingService _streaming;
  final MemoryService _memori;
  final ToolExecutor _executor;
  final DaftarAlat _daftar;

  Future<Pesan> jalankan({
    required String idPesan,
    required ModelAi model,
    required SetelanApp setelan,
    required String systemPrompt,
    required List<Pesan> riwayat,
    required EmitTeks onTeks,
    required EmitAlat onAlat,
    required CekBatal sudahBatal,
    required KonteksAlat konteks,
  }) async {
    _daftar.terapkan(setelan);
    _executor.langkahBaru();

    // Parameter `model` bersifat final, jadi buat variabel lokal yang bisa
    // ditukar saat auto-fallback.
    ModelAi modelAktif = model;

    final bool agentAktif = setelan.agentAktif && modelAktif.dukungAlat;
    final List<PesanApi> wire = _memori.keWire(
      systemPrompt: systemPrompt,
      pesan: riwayat,
    );

    final StringBuffer isi = StringBuffer();
    final List<CatatanAlat> catatan = <CatatanAlat>[];
    final List<ModelAi> percobaan = <ModelAi>[modelAktif];
    final List<String> catatFallback = <String>[];
    String galat = '';
    int kodeGalat = KodeGalat.GalatKosong;
    bool mentok = false;

    /// Kandidat model berikutnya saat yang sekarang ditolak provider.
    ModelAi? _berikutnya(List<ModelAi> dicoba, List<ModelAi> katalog) {
      final List<ModelAi> urut = ModelAi.cadangan(dicoba.first, katalog);
      for (final ModelAi m in urut) {
        if (!dicoba.any((ModelAi d) => d.id == m.id)) return m;
      }
      return null;
    }

    final List<ModelAi> katalog = <ModelAi>[
      modelAktif,
      ...ModelAi.cadangan(modelAktif),
    ];

    for (int langkah = 1; langkah <= AppConfig.maksLangkahAgent; langkah++) {
      if (sudahBatal()) break;

      final List<PanggilanAlat> panggil = <PanggilanAlat>[];
      bool selesai = false;

      await for (final PotonganBalasan potongan in _streaming.kirim(
        model: modelAktif,
        pesan: wire,
        suhu: setelan.suhu,
        alat: agentAktif ? _daftar.specs() : null,
      )) {
        if (potongan.galat.isNotEmpty) {
          galat = potongan.galat;
          kodeGalat = potongan.kodeGalat;
          selesai = true;
          break;
        }
        if (potongan.teks.isNotEmpty) {
          isi.write(potongan.teks);
          onTeks(potongan.teks);
        }
        if (potongan.alat.isNotEmpty) {
          panggil.addAll(potongan.alat);
        }
        if (potongan.selesai) {
          selesai = true;
          break;
        }
      }

      if (galat.isNotEmpty) {
        // Auto-fallback: model ditolak / kuota habis -> coba kandidat lain
        // SEKALI dalam langkah yang sama (jangan mengulang tanpa batas).
        final bool perluCobaLagi = kodeGalat == KodeGalat.modelTidakAda ||
            kodeGalat == KodeGalat.kuotaHabis ||
            kodeGalat == KodeGalat.kunciDitolak;
        if (perluCobaLagi && !sudahBatal() && percobaan.length <= 3) {
          final ModelAi? berikutnya = _berikutnya(percobaan, katalog);
          if (berikutnya != null) {
            percobaan.add(berikutnya);
            modelAktif = berikutnya;
            catatFallback.add(
              'Model sebelumnya ditolak provider; diganti ke '
              '${modelAktif.label}.',
            );
            // PENTING: jangan sentuh `wire` di sini - daftar percakapan tetap
            // utuh, hanya model yang ditukar.
            galat = '';
            kodeGalat = KodeGalat.GalatKosong;
            continue;
          }
        }
        break;
      }
      if (panggil.isEmpty) {
        // Tidak ada tool call = agent sudah selesai (turn selesai normal).
        selesai = true;
      }
      if (!selesai && !sudahBatal()) break;
      if (panggil.isEmpty) break;

      // Act: kirim jawaban tool ke model sebagai pesan `tool`.
      wire.add(PesanApi(peran: 'assistant', isi: '', alat: panggil));
      for (final PanggilanAlat call in panggil) {
        if (sudahBatal()) break;
        final HasilPanggilan hasil =
            await _executor.jalankan(call, konteks);
        wire.add(PesanApi.hasilAlat(
          call.id,
          call.nama,
          hasil.teksUntukModel,
        ));
        final CatatanAlat c = CatatanAlat(
          nama: call.nama,
          argumen: call.argumen,
          hasil: hasil.hasil.isi,
          status: hasil.hasil.gagal ? StatusAlat.gagal : StatusAlat.selesai,
          waktu: DateTime.now(),
          ringkasan: hasil.hasil.ringkasan,
        );
        catatan.add(c);
        onAlat(c);
      }
      if (sudahBatal()) break;
      // Kalau langkah terakhir masih memicu tool, berarti agent mentok.
      if (langkah == AppConfig.maksLangkahAgent && panggil.isNotEmpty) {
        mentok = true;
      }
    }

    String teksAkhir = isi.toString().trimRight();
    if (catatFallback.isNotEmpty) {
      teksAkhir = '${_sisipBaris(teksAkhir)}\n\n_(${catatFallback.join(' ')})_';
    }
    if (mentok) {
      teksAkhir = '${_sisipBaris(teksAkhir)}\n\n_(agent berhenti setelah '
          '${AppConfig.maksLangkahAgent} langkah)_';
    }
    if (teksAkhir.trim().isEmpty && catatan.isNotEmpty) {
      teksAkhir = catatan
          .map((CatatanAlat c) => '- ${c.nama}: ${c.hasil}')
          .join('\n');
    }

    return Pesan(
      id: idPesan,
      peran: Peran.ai,
      isi: teksAkhir,
      waktu: DateTime.now(),
      status: sudahBatal()
          ? StatusPesan.dibatalkan
          : (galat.isNotEmpty ? StatusPesan.gagal : StatusPesan.selesai),
      modelId: modelAktif.id,
      catatanAlat: catatan,
      pesanGalat: galat,
    );
  }

  static String _sisipBaris(String s) => s.trim();

  /// Pilih model secara otomatis berdasarkan isi pesan (mode `auto`).
  ///
  /// Heuristik sengaja dibuat simpel dan bisa ditebak user:
  /// angka/operator -> model tool;-url/kata cari -> model tool;
  /// teks panjang atau minta kode -> model besar; selain itu -> default.
  static ModelAi pilihOtomatis({
    required String pesan,
    required List<ModelAi> katalog,
    required ModelAi fallback,
  }) {
    if (katalog.isEmpty) return fallback;
    final List<ModelAi> denganAlat = ModelAi.layakOtomatis(katalog);
    final List<ModelAi> pilihan =
        denganAlat.isEmpty ? ModelAi.layakOtomatis() : denganAlat;
    if (pilihan.isEmpty) return fallback;

    final String p = pesan.toLowerCase();
    final bool adaAngka = RegExp(r'\d').hasMatch(p);
    final bool adaOperator =
        RegExp(r'[+\-*/^%]').hasMatch(pesan.replaceAll(RegExp(r'\d'), ''));
    final bool mintaHitung = adaAngka &&
        (adaOperator ||
            p.contains('berapa') ||
            p.contains('hitung') ||
            p.contains('kalkulasi') ||
            p.contains('total') ||
            p.contains('berapa persen'));
    final bool mintaWeb = p.contains('http://') ||
        p.contains('https://') ||
        p.contains('cari di web') ||
        p.contains('cek berita') ||
        p.contains('buka link');
    final bool mintaKode = p.contains('kode') ||
        p.contains('code') ||
        p.contains('flutter') ||
        p.contains('python') ||
        p.contains('javascript') ||
        p.contains('sql') ||
        p.contains('script');

    // Urutan preferensi: besar dulu (kualitas), turun ke ringan (cepat).
    ModelAi? cariBertanggi(String pola) {
      for (final ModelAi m in pilihan) {
        if (m.id.toLowerCase().contains(pola)) return m;
      }
      return null;
    }

    // PENTING: jangan pernah pilih model khusus paket berbayar untuk kunci
    // gratis - itu penyebab "semua model gagal" (Llama 3.3 70B sudah Enterprise).
    if (pilihan.any((ModelAi m) => m.untukGratis)) {
      pilihan.sort((ModelAi a, ModelAi b) =>
          (a.untukGratis ? 0 : 1).compareTo(b.untukGratis ? 0 : 1));
    }

    if (mintaHitung || mintaWeb) {
      return cariBertanggi('gpt-oss-20b') ??
          cariBertanggi('gpt-oss-120b') ??
          pilihan.first;
    }
    if (mintaKode || pesan.length > 700) {
      return cariBertanggi('gpt-oss-120b') ??
          cariBertanggi('gpt-oss-20b') ??
          pilihan.first;
    }
    // Pertanyaan pendek & biasa -> model paling ringan (respons cepat).
    return cariBertanggi('gpt-oss-20b') ?? fallback;
  }

  /// Ringkas jawaban panjang (dipakai saat konteks hampir penuh).
  static String ringkasJawaban(String teks, {int maks = 600}) =>
      Teks.ringkas(teks, maks);
}
