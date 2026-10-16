# Audit Rebuild: WebView → Native Flutter

Tanggal: 16 Oktober 2026 · Branch: `flutter-native`

## Ringkas

Brief menyebut "Agent AI sudah dalam proses dibangun di sisi JS (agent.js)" dan
memb_WEBAH wa app WebView "memiliki" 7 fitur agent (multi-step loop, tool calling,
memori, validasi URL, anti-duplikasi tool call, manajemen konteks, streaming).

**Setelah membedah repo, tidak satu pun itu ada.** Yang benar:

| Yang disebut brief | Kenyataan di repo |
|---|---|
| `agent.js` | **Tidak pernah ada.** Hanya 3 file JS: `index.html` (137 KB), `md.js`, `keys.js` |
| Multi-step agent loop | Tidak ada. Tidak ada kode agent sama sekali |
| Tool calling (kalkulator, waktu, memori, email, web) | Tidak ada. `grep` tool/kalkulator/memory di `index.html` = 0 hasil |
| Memori jangka panjang + wipe | Tidak ada |
| Validasi URL anti-SSRF | Tidak ada (web browse ada, tapi tanpa penjaga alamat privat) |
| Anti-duplikasi tool call, race cancellation | Tidak ada |
| Streaming response | **Ada** - ini satu-satunya yang benar-benar sudah jadi |
| Manajemen konteks / ringkas riwayat | Tidak ada |

Fitur WebView yang **memang ada** dan jadi acuan parity:
chat Groq + Gemini, mode panggilan suara (SpeechRecognizer + TTS), renderer
markdown (`md.js`), riwayat percakapan, halaman pengaturan, pemilih font,
onboarding, basis pengetahuan offline (`offline_kb.json`), shortcut & share.

## Artinya

Bagian agent di brief ini **bangun dari nol**, bukan migrasi. Semua tool,
loop, memori, dan penjaga keamanan ditulis baru di Dart pada rebuild ini
(`lib/features/agent/`, `lib/services/`).

Yang dipindahkan dari versi lama:
- identitas paket `com.divjun.ai` + keystore yang sama → APK baru bisa
  **update di atas** APK lama tanpa uninstall;
- daftar fitur parity (chat, suara menyusul, pengaturan, riwayat, markdown);
- palet & nama brand.

## Yang TIDAK ikut (sengaja)

- `offline_kb.json` + `offline_help.json`: isinya teks bantuan untuk UI lama
  (selector `id=` yang sudah tidak ada). Bringing them over would be dead
  weight; help text ditulis ulang di UI.
- Pipeline Gradle Kotlin (`app/build.gradle`, `MainActivity.kt`, `Perms.kt`):
  Flutter punya build system sendiri.

## Verifikasi

Semua angka di atas bisa dicek ulang:

```bash
# agent.js benar-benar tidak ada?
find . -iname "*agent*" -not -path "./.git/*"

# tidak ada tool calling di kode lama?
grep -cE "tool_call|toolCalls|function_call" app/src/main/assets/*.js

# hanya 3 file JS?
find . -name "*.js" -not -path "./.git/*"
```
