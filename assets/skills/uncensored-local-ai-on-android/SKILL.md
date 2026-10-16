# Uncensored / local AI assistant di Android (Termux) — daftar TERVERIFIKASI

Konteks: user cari "AI jahat"/uncensored seperti repo `BadAiTeam/BadAi`
(itu cuma biner Windows `.exe` + Linux x86-64, PyArmor, TIDAK ada build Android).

## PRINSIP UTAMA (jelaskan ke user, ini pertanyaan paling sering salah)
"Uncensored" BUKAN sifat app-nya — app cuma cangkang. Tanpa sensor datang dari
**MODEL** yang dimuat. App GGUF apa pun + model "dolphin"/"abliterated" =
benar-benar tanpa filter. Jadi pilih app yang paling terawat, bukan yang
tulisannya "uncensored" paling besar.

## A. App Android langsung (APK, offline, tanpa root) — cek live 13 Okt 2026

| Repo | Stars | APK | Catatan |
|---|---|---|---|
| `a-ghorbani/pocketpal-ai` | 8.6k (aktif, update harian) | `app-prod-release.apk` 225 MB | **pilihan #1** — paling terawat, download model dari HF langsung di app |
| `Vali-98/ChatterUI` | 2.8k | `ChatterUI_v0.10.1.apk` 62 MB | ringan, bisa GGUF lokal ATAU nyambung ke API provider |
| `techjarves/Uncensored-Local-AI-Multiplatform` | 1.3k | arm64 65 MB / armv7 18 MB | branding "uncensored, 100% offline" — Flutter |
| `mlc-ai/mlc-llm` (MLC Chat) | 23k | APK di Releases | fokus kompilasi model, setup lebih ribet |
| `PapaKoftes/Layla` | kecil | desktop-first | bukan target HP |

Cara pasang (sama untuk semua): download APK → `am start -a android.intent.action.VIEW -d file://<apk> -t application/vnd.android.package-archive`.

### Jalur yang SUDAH terbukti jalan (13 Okt 2026, POCO M7 Pro / MT6855)
App: `a-ghorbani/pocketpal-ai` v1.19.0 → APK 236.912.472 B, package **`com.pocketpalai`**,
label **PocketPal**. Model: `bartowski/Dolphin3.0-Qwen2.5-1.5B-GGUF` →
`Dolphin3.0-Qwen2.5-1.5B-Q4_K_M.gguf` **986.051.648 B** (RAM sisa ~2 GB → aman).
PocketPal bisa muat dari **local storage**: ☰ → Models → **+** → Local storage.
Alur curl: unduh ke `$HOME` (cepat) → `setsid nohup cp` ke `/storage/emulated/0/Download/`
pakai nama titik (`.x.tmp`) → `mv` ke nama final → verifikasi `sha256sum` kedua sisi +
`head -c 4 | od -An -c` = `G G U F`.

## B. Model GGUF tanpa sensor (yang bikin "uncensored" jadi nyata)
Ambil dari Hugging Face, format **GGUF Q4_K_M**. Untuk RAM HP ~2 GB sisa:
- 1–2B: `dolphin3.0-llama3.2-1b`, `gemma-2-2b-it-abliterated`, `Qwen2.5-1.5B-Instruct-abliterated` (huihui-ai)
- 3B: `Llama-3.2-3B-Instruct-abliterated`
- 7–8B: `dolphin-2.9-llama3-8b` (Q4 ≈ 4–5 GB — HP 7,6 GB RAM, ketat)
Keyword pencarian model: "dolphin", "abliterated", "uncensored", "heretic".

## C. Termux native (paling dekat dengan "BadAI" = CLI assistant)
- **llama.cpp** (`ggml-org/llama.cpp`, 131k stars) — build di Termux, lalu
  `llama-cli -m model.gguf`. Native arm64, offline. Ini "AI terminal" yang asli.
- **Anon4You/Termux-Ai** (175 stars) — wrapper CLI Termux, 10+ provider,
  sebagian tanpa API key.
- **ollama via proot-distro ubuntu** — bisa, tapi berat (~1,5 GB rootfs).

## D. Cloud gratis tanpa sensor (kalau HP kewalahan)
- **AI Horde** (`Haidra-Org/AI-Horde`, 1.6k stars) — cluster GPU komunitas,
  gratis, anonymous key `0000000000`. Ada model uncensored (Pygmalion/Tiefighter).
- **Venice AI** — uncensored, tanpa log, ada free tier (butuh akun).

## JEBAKAN
- Model lokal jauh lebih lemah dari cloud model — jangan janjikan setara.
- Jangan arahkan download biner dari repo tanpa deskripsi/rilis (mis. `BadAiTeam/*`)
  → itu binary obfuscated asing, safety scan dulu.
- RAM HP: 3B Q4 = aman; 7B Q4 = mepet di 7,6 GB RAM (MiuiSentinel bisa kill).
