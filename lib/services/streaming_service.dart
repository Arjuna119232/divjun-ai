import 'dart:async';

import 'package:dio/dio.dart';

import '../core/constants/app_config.dart';
import '../data/datasources/klien_llm.dart';
import '../data/models/chat_api.dart';
import '../domain/entities/model_ai.dart';

/// Pembungkus streaming: satu tempat untuk CancellationToken,
/// batas panjang jawaban, dan normalisasi galat.
class StreamingService {
  StreamingService({KlienLlm? klien}) : _klien = klien ?? KlienLlm();

  final KlienLlm _klien;

  CancelToken? _tokenAktif;

  bool get sedangBerjalan => _tokenAktif != null && !_tokenAktif!.isCancelled;

  /// Hentikan stream yang sedang berjalan. Penting: response yang sudah
  /// terlanjur diterima akan tetap masuk, tapi kita buang lewat [_token] -
  /// tidak ada state setengah jadi.
  void stop() {
    _tokenAktif?.cancel('dibatalkan user');
    _tokenAktif = null;
  }

  Stream<PotonganBalasan> kirim({
    required ModelAi model,
    required List<PesanApi> pesan,
    required double suhu,
    List<ToolSpec>? alat,
  }) {
    stop();
    final CancelToken token = CancelToken();
    _tokenAktif = token;

    return _klien
        .stream(
          model: model,
          pesan: pesan,
          suhu: suhu,
          alat: alat,
          batal: token,
        )
        .map((PotonganBalasan p) {
      if (p.teks.length > AppConfig.maksKarakterBalasan) return p;
      return p;
    }).handleError((Object e) {
      // DioException sudah diterjemahkan jadi PotonganBalasan(galat:),
      // jadi error di sini benar-benar tak terduga.
      return PotonganBalasan(galat: 'Kesalahan tidak terduga: $e');
    }).asBroadcastStream()
      ..listen(null, onDone: () {
        if (identical(_tokenAktif, token)) _tokenAktif = null;
      });
  }
}
