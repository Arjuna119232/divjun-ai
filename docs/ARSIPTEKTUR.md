# Arsitektur DIVJUN AI (Flutter)

## Alur satu pesan

```
KolomTulis (UI)
   -> ChatController.kirim()            lib/features/chat/data/kontrol_chat.dart
      1. simpan pesan user ke storage
      2. pilih model (auto / manual)
      3. ambil memori relevan (search lokal)
      4. bangun system prompt + riwayat (ringkas bila melewati ambang)
   -> AgentLoop.jalankan()              lib/features/agent/loop/agent_loop.dart
      for langkah in 1..6:
        StreamingService.kirim()        lib/services/streaming_service.dart
           -> KlienLlm.stream()         lib/data/datasources/klien_llm.dart
              -> Dio SSE (data: ... diparsing per chunk)
        <- token demi token (UI update tiap 40 ms)
        <- tool_calls?  -> ToolExecutor -> DaftarAlat -> alat/*.dart
           -> hasil tool ditempel sebagai pesan `tool`
           -> ulangi (observe)
   -> Pesan final (selesai / gagal / dibatalkan) -> disimpan ke storage
```

## Lapisan

| Lapisan | Isi | Aturan |
|---|---|---|
| `lib/core` | tema, router, konstanta, util, provider | tidak boleh tahu fitur apa pun |
| `lib/domain/entities` | model domain (Pesan, Setelan, EntriMemori, ModelAi) | tidak boleh import Flutter |
| `lib/data` | repository, datasource, model wire (SSE/JSON) | tidak boleh menyentuh UI |
| `lib/services` | streaming, memori, tool executor | orkestrasi lintas lapisan |
| `lib/features/*` | agent (tools/loop/memory) + presentation | satu fitur satu folder |
| `test/` | uji pure-Dart (kalkulator, url guard) | jalan tanpa device |

## Token warna

Semua warna dari `lib/core/theme/app_colors.dart`. Tidak ada `Color(0x...)`
di luar file itu. Warna brand dipakai lewat `ColorScheme`, sehingga Material You
tetap bisa menimpa primary di HP Android 12+.

## Penyimpanan

| Data | Tempat | Alasan |
|---|---|---|
| Pengaturan | SharedPreferences | kecil, sering ditulis, sinkron |
| Riwayat percakapan | `documents/divjun/riwayat.json` | data besar, ditulis atomik (tmp + rename) |
| Memori | `documents/divjun/memori.json` | sama, + pencarian lokal |

Tidak pakai Hive/Isar di v1: butuh codegen, punya sejarah masalah ABI di
Android 16, dan data app ini hanya ribuan baris JSON. Naik ke Isar kalau
riwayat tumbuh sampai ratusan MB.

## Keamanan tool web

1. hanya `http`/`https`, port 80/443;
2. blokir host privat & internal (`localhost`, `*.local`, `169.254.169.254`,
   `10/8`, `172.16/12`, `192.168/16`, `127/8`, IPv6 ULA & link-local);
3. cek hasil resolusi DNS (anti DNS-rebinding ke IP privat);
4. batasi ukuran unduhan + timeout 12 detik.

## Kenapa tidak vector DB

Pencarian memori memakai skor tumpang-tindih kata kunci + bonus kesegaran.
Untuk puluhan/ribuan entri itu cukup dan jalan offline. Vector DB baru
dibutuhkan kalau entri tumbuh jadi ribuan dokumen panjang.
