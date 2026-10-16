import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/app_env.dart';
import '../../domain/entities/model_ai.dart';
import '../models/chat_api.dart';

/// Satu pesan di wire format (OpenAI-compatible).
class PesanApi {
  const PesanApi({
    required this.peran,
    required this.isi,
    this.alat,
    this.idAlat,
    this.namaAlat,
  });

  final String peran;
  final String isi;
  final List<PanggilanAlat>? alat;
  final String? idAlat;
  final String? namaAlat;

  Map<String, dynamic> keJson() => {
        'role': peran,
        'content': isi.isEmpty && alat != null ? null : isi,
        if (alat != null) 'tool_calls':
            alat!.map((PanggilanAlat a) => _panggilanJson(a)).toList(),
        if (idAlat != null) 'tool_call_id': idAlat,
        if (namaAlat != null) 'name': namaAlat,
      };

  static Map<String, dynamic> _panggilanJson(PanggilanAlat a) => {
        'id': a.id,
        'type': 'function',
        'function': {'name': a.nama, 'arguments': a.argumen},
      };

  static PesanApi hasilAlat(String idAlat, String nama, String isi) => PesanApi(
        peran: 'tool',
        isi: isi,
        idAlat: idAlat,
        namaAlat: nama,
      );
}

/// Klien LLM: streaming SSE + tool calling native.
///
/// Semua kegagalan network diterjemahkan ke pesan Bahasa Indonesia yang
/// bisa ditampilkan user apa adanya (tidak ada TypeError senyap).
class KlienLlm {
  KlienLlm({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 120)
      ..sendTimeout = const Duration(seconds: 30)
      ..responseType = ResponseType.stream;
  }

  final Dio _dio;

  static const String _hostGroq = 'api.groq.com';
  static const String _hostGemini = 'generativelanguage.googleapis.com';

  bool _punya(ModelAi m) =>
      m.penyedia == PenyediaModel.groq ? AppEnv.punyaGroq : AppEnv.punyaGemini;

  String _kunci(ModelAi m) =>
      m.penyedia == PenyediaModel.groq ? AppEnv.groqApiKey : AppEnv.geminiApiKey;

  String _url(ModelAi m) {
    if (m.penyedia == PenyediaModel.groq) {
      return 'https://$_hostGroq/openai/v1/chat/completions';
    }
    return 'https://$_hostGemini/v1beta/models/${m.id}'
        ':streamGenerateContent?alt=sse';
  }

  Map<String, String> _header(ModelAi m) {
    if (m.penyedia == PenyediaModel.groq) {
      return {
        'Authorization': 'Bearer ${_kunci(m)}',
        'Content-Type': 'application/json',
        'User-Agent': AppConfig.userAgent,
      };
    }
    return {
      'x-goog-api-key': _kunci(m),
      'Content-Type': 'application/json',
      'User-Agent': AppConfig.userAgent,
    };
  }

  Map<String, dynamic> _body(
    ModelAi m,
    List<PesanApi> pesan, {
    required double suhu,
    List<ToolSpec>? alat,
    bool streaming = true,
  }) {
    if (m.penyedia == PenyediaModel.groq) {
      return {
        'model': m.id,
        'messages': pesan.map((PesanApi p) => p.keJson()).toList(),
        'temperature': suhu,
        'top_p': 0.95,
        'stream': streaming,
        if (streaming) 'stream_options': {'include_usage': false},
        if (alat != null && alat.isNotEmpty)
          'tools': alat.map((ToolSpec t) => t.keJson()).toList(),
        if (alat != null && alat.isNotEmpty)
          'tool_choice': m.dukungAlat ? 'auto' : 'none',
      };
    }
    // Gemini: wire format_system-ish digabung sebagai instruksi pertama.
    final List<Map<String, dynamic>> isi = <Map<String, dynamic>>[];
    for (final PesanApi p in pesan) {
      if (p.peran == 'tool') continue;
      final String peran = switch (p.peran) {
        'assistant' => 'model',
        _ => 'user',
      };
      isi.add({
        'role': peran,
        'parts': [
          {'text': p.peran == 'system' ? '[Instruksi] ${p.isi}' : p.isi},
        ],
      });
    }
    return {
      'contents': isi,
      'generationConfig': {
        'temperature': suhu,
        'topP': 0.95,
      },
    };
  }

  /// Stream jawaban model. Meng Hasilkan [PotonganBalasan] per token.
  ///
  /// [batal] dipakai controller untuk stop; stream ditutup bersih supaya
  /// tidak ada "response completed after abort" (race condition).
  Stream<PotonganBalasan> stream({
    required ModelAi model,
    required List<PesanApi> pesan,
    required double suhu,
    List<ToolSpec>? alat,
    CancelToken? batal,
  }) async* {
    if (!_punya(model)) {
      yield PotonganBalasan(
        galat: 'API key untuk ${model.penyedia.name} belum diisi. '
            'Isi di pengaturan atau build ulang dengan --dart-define.',
      );
      return;
    }

    final Response<dynamic> respons;
    try {
      respons = await _dio.post<dynamic>(
        _url(model),
        data: _body(model, pesan, suhu: suhu, alat: alat),
        cancelToken: batal,
        options: Options(
          headers: _header(model),
          responseType: ResponseType.stream,
        ),
      );
    } on DioException catch (e) {
      yield PotonganBalasan(galat: _petakanGalat(e));
      return;
    } catch (e) {
      yield PotonganBalasan(galat: 'Gagal menghubungi server: $e');
      return;
    }

    final _PenguraiSse pengurai = _PenguraiSse(model.penyedia);
    final Map<int, _AlatAkumulator> alatAkum = <int, _AlatAkumulator>{};

    try {
      final Stream<String> baris = (respons.data as Stream<List<int>>)
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final String mentah in baris) {
        if (batal?.isCancelled ?? false) return;
        final String barisTunggal = mentah.trim();
        if (barisTunggal.isEmpty) continue;

        for (final _IrisanSse iris in pengurai.urai(barisTunggal)) {
          if (iris.teks.isNotEmpty) {
            yield PotonganBalasan(teks: iris.teks);
          }
          iris.perubahanAlat.forEach((int idx, _IrisanAlat a) {
            alatAkum.putIfAbsent(idx, () => _AlatAkumulator());
            alatAkum[idx]!.tambah(a);
          });
        }
      }
    } on DioException catch (e) {
      if (batal?.isCancelled ?? false) return;
      yield PotonganBalasan(galat: _petakanGalat(e));
      return;
    } catch (e) {
      yield PotonganBalasan(galat: 'Stream terputus: $e');
      return;
    }

    final List<PanggilanAlat> panggil = alatAkum.values
        .map((_AlatAkumulator a) => a.selesai())
        .where((PanggilanAlat a) => a.nama.isNotEmpty)
        .toList();

    yield PotonganBalasan(alat: panggil, selesai: true);
  }

  /// Versi non-streaming (dipakai saat regenerate/ringkas riwayWA).
  Future<HasilBalasan> sekali({
    required ModelAi model,
    required List<PesanApi> pesan,
    required double suhu,
  }) async {
    final StringBuffer teks = StringBuffer();
    String galat = '';
    final List<PanggilanAlat> alat = <PanggilanAlat>[];
    try {
      await for (final PotonganBalasan p in stream(
        model: model,
        pesan: pesan,
        suhu: suhu,
      )) {
        if (p.galat.isNotEmpty) {
          galat = p.galat;
          break;
        }
        teks.write(p.teks);
        alat.addAll(p.alat);
      }
    } catch (e) {
      galat = 'Gagal: $e';
    }
    return HasilBalasan(teks: teks.toString(), alat: alat, galat: galat);
  }

  /// Ambil daftar model langsung dari provider (katalog Settings).
  Future<List<ModelAi>> daftarModel() async {
    final List<ModelAi> hasil = <ModelAi>[];

    if (AppEnv.punyaGroq) {
      try {
        final Response<dynamic> r = await _dio.get<Map<String, dynamic>>(
          'https://$_hostGroq/openai/v1/models',
          options: Options(
            headers: _header(ModelAi.bawaan.first),
            responseType: ResponseType.json,
          ),
        );
        final List<dynamic> data =
            (r.data?['data'] as List<dynamic>?) ?? <dynamic>[];
        for (final dynamic m in data) {
          if (m is Map<String, dynamic> && m['id'] is String) {
            final String id = m['id'] as String;
            if (id.startsWith('whisper') || id.startsWith('guard')) continue;
            hasil.add(ModelAi(
              id: id,
              label: _pretty(id),
              penyedia: PenyediaModel.groq,
              dukungAlat: _kemungkinanBisaAlat(id),
              konteks: (m['context_length'] as num?)?.toInt() ?? 8192,
            ));
          }
        }
      } catch (_) {
        // diam: pakai katalog bawaan
      }
    }

    if (AppEnv.punyaGemini) {
      for (final ModelAi m in ModelAi.bawaan) {
        if (m.penyedia == PenyediaModel.gemini) hasil.add(m);
      }
    }

    if (hasil.isEmpty) hasil.addAll(ModelAi.bawaan);
    hasil.sort((ModelAi a, ModelAi b) => a.label.compareTo(b.label));
    return hasil;
  }

  /// Model yang TIDAK mendukung tool calling akan disembunyikan dari agent.
  static bool _kemungkinanBisaAlat(String id) {
    final String s = id.toLowerCase();
    if (s.contains('whisper') || s.contains('guard')) return false;
    if (s.contains('gemma')) return true;
    if (s.contains('gpt-oss')) return true;
    if (s.contains('llama-3.3') || s.contains('llama-3.1')) return true;
    if (s.contains('qwen')) return true;
    if (s.contains('kimi') || s.contains('deepseek')) return true;
    return true; // default: modern Groq model mendukung tools
  }

  static String _pretty(String id) {
    final String nama = id.split('/').last.replaceAll('-', ' ');
    return nama
        .split(' ')
        .where((String e) => e.isNotEmpty)
        .map((String e) => e[0].toUpperCase() + e.substring(1))
        .join(' ');
  }

  static String _petakanGalat(DioException e) {
    final int kode = e.response?.statusCode ?? 0;
    final String isi = _isiGalat(e.response?.data);
    if (kode == 401) {
      return 'API key ditolak. Cek lagi key-nya di pengaturan. $isi';
    }
    if (kode == 429) {
      return 'Kuota model habis sebentar. Tunggu sebentar atau ganti model. $isi';
    }
    if (kode == 404) {
      return 'Model tidak ditemukan di provider. Pilih model lain. $isi';
    }
    if (kode >= 500) {
      return 'Server provider sedang gangguan (HTTP $kode). Coba lagi. $isi';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Koneksi ke provider timeout. Cek internet lalu coba lagi.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak bisa konek ke server AI. Cek koneksi internet.';
    }
    return 'Gagal ($kode). $isi';
  }

  static String _isiGalat(dynamic data) {
    if (data == null) return '';
    try {
      if (data is Stream) return '';
      if (data is String) {
        final Object? dec = jsonDecode(data);
        if (dec is Map<String, dynamic>) {
          final Object? err = dec['error'];
          if (err is Map<String, dynamic> && err['message'] is String) {
            return err['message'] as String;
          }
        }
      }
      if (data is Map<String, dynamic>) {
        final Object? err = data['error'];
        if (err is Map<String, dynamic> && err['message'] is String) {
          return err['message'] as String;
        }
        if (data['message'] is String) return data['message'] as String;
      }
    } catch (_) {
      return '';
    }
    return '';
  }
}

/// Akumulator potongan tool_call yang datangnya terpisah-pisah per chunk.
class _AlatAkumulator {
  String id = '';
  String nama = '';
  final StringBuffer argumen = StringBuffer();

  void tambah(_IrisanAlat a) {
    if (a.id.isNotEmpty) id = a.id;
    if (a.nama.isNotEmpty) {
      nama += a.nama;
    }
    argumen.write(a.argumen);
  }

  PanggilanAlat selesai() => PanggilanAlat(
        id: id.isEmpty ? nama : id,
        nama: nama,
        argumen: argumen.toString(),
      );
}

class _IrisanAlat {
  const _IrisanAlat({this.nama = '', this.argumen = '', this.id = ''});
  final String nama;
  final String argumen;
  final String id;
}

class _IrisanSse {
  const _IrisanSse({this.teks = '', this.perubahanAlat = const <int, _IrisanAlat>{}});
  final String teks;
  final Map<int, _IrisanAlat> perubahanAlat;
}

/// Parser SSE: format OpenAI (Groq) dan Gemini.
class _PenguraiSse {
  _PenguraiSse(this.penyedia);

  final PenyediaModel penyedia;

  List<_IrisanSse> urai(String baris) {
    if (!baris.startsWith('data:')) return const <_IrisanSse>[];
    final String isi = baris.substring(5).trim();
    if (isi.isEmpty || isi == '[DONE]') return const <_IrisanSse>[];
    try {
      final Object? dec = jsonDecode(isi);
      if (dec is! Map<String, dynamic>) return const <_IrisanSse>[];
      return penyedia == PenyediaModel.groq
          ? _uraiGroq(dec)
          : _uraiGemini(dec);
    } catch (_) {
      return const <_IrisanSse>[];
    }
  }

  List<_IrisanSse> _uraiGroq(Map<String, dynamic> j) {
    final List<dynamic> pilihan =
        (j['choices'] as List<dynamic>?) ?? <dynamic>[];
    if (pilihan.isEmpty) return const <_IrisanSse>[];
    final Object? c = pilihan.first;
    if (c is! Map<String, dynamic>) return const <_IrisanSse>[];
    final Object? delta = c['delta'] ?? c['message'];
    if (delta is! Map<String, dynamic>) return const <_IrisanSse>[];

    final String teks = delta['content'] is String
        ? delta['content'] as String
        : (delta['reasoning_content'] is String
            ? delta['reasoning_content'] as String
            : '');

    final Map<int, _IrisanAlat> alat = <int, _IrisanAlat>{};
    final Object? calls = delta['tool_calls'];
    if (calls is List<dynamic>) {
      for (final dynamic item in calls) {
        if (item is! Map<String, dynamic>) continue;
        final int idx = (item['index'] as num?)?.toInt() ??
            (alat.length);
        final Object? fn = item['function'];
        final Map<String, dynamic> f =
            fn is Map<String, dynamic> ? fn : <String, dynamic>{};
        alat[idx] = _IrisanAlat(
          id: item['id'] as String? ?? '',
          nama: f['name'] as String? ?? '',
          argumen: f['arguments'] as String? ?? '',
        );
      }
    }
    if (teks.isEmpty && alat.isEmpty) return const <_IrisanSse>[];
    return <_IrisanSse>[_IrisanSse(teks: teks, perubahanAlat: alat)];
  }

  List<_IrisanSse> _uraiGemini(Map<String, dynamic> j) {
    final List<dynamic> kandidat =
        (j['candidates'] as List<dynamic>?) ?? <dynamic>[];
    if (kandidat.isEmpty) return const <_IrisanSse>[];
    final Object? c = kandidat.first;
    if (c is! Map<String, dynamic>) return const <_IrisanSse>[];
    final Object? konten = c['content'];
    if (konten is! Map<String, dynamic>) return const <_IrisanSse>[];
    final Object? bagian = konten['parts'];
    if (bagian is! List<dynamic>) return const <_IrisanSse>[];
    final StringBuffer teks = StringBuffer();
    for (final dynamic p in bagian) {
      if (p is Map<String, dynamic> && p['text'] is String) {
        teks.write(p['text'] as String);
      }
    }
    if (teks.isEmpty) return const <_IrisanSse>[];
    return <_IrisanSse>[_IrisanSse(teks: teks.toString())];
  }
}
