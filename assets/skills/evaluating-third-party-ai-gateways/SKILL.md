---
name: evaluating-third-party-ai-gateways
description: Cara menguji dan menilai gateway AI pihak ketiga (OpenAI-compatible) dari Termux — cek endpoint hidup/tak hidup, bedakan free tier asli vsXpembunyi, deteksi halaman harga palsu, dan menilai "model ini setara apa di dunia". Gunakan saat user tanya "AI ini bagus/tuah/equivalentsapa", saat/engine baru AI lokal proposed (mis. Sahabat-AI, Neosantara, SahabatMobile, Deka LLM), atau saat mau menambah provider ke zyvo config.
---

# Evaluasi Gateway AI Pihak Ketiga (bukan model frontier global)

Skill ini untuk hal yang **beda** dari `zyvo-free-model-audit`: yang itu
mengaudit provider yang sudah dipakai (apakah model masih hidup). Skill ini
untuk **provider baru yang akan dievaluasi dari nol** — belum ada key, belum
ada config, sering marketing-nya lebih besar dari kenyataannya.

## 0. Jebakan Termux yang costing waktu

```bash
curl -o /tmp/resp.txt ...    # ❌ /tmp TIDAK ADA di Termux
curl -o "$TMPDIR/resp.txt"   # ✅ selalu pakai $TMPDIR
```
Gejalanya: server balas 200 dengan `content-length: 133398`, tapi curl
melaporkan "0 bytes" dan `head` bilang file tidak ada. Itu **artefak -o**, bukan
server kosong. KalauATHERbisnis cholat.empty result, cek dulu `-o` path sebelum
simpulkan endpoint mati. (Kejadian nyata saat tes Neosantara, 10 Okt 2026.)

## 1. Probe 3 lapis (urutan wajib)

```bash
UA="Mozilla/5.0 Chrome/154.0"
# Lapis 1 — host hidup?
curl -sIL --max-time 12 -A "$UA" "$BASE" -o /dev/null -w "%{http_code} %{url_effective}\n"
# Lapis 2 — katalog model (sering PUBLIK walau chat butuh key)
curl -s --max-time 20 -A "$UA" "$BASE/v1/models" -o "$TMPDIR/m.json" -w "HTTP %{http_code} %{size_download}B\n"
# Lapis 3 — chat TANPA key (untuk melihat pesan's apa)
curl -s --max-time 30 -A "$UA" -X POST "$BASE/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"<id>","messages":[{"role":"user","content":"tes"}],"max_tokens":300}' \
  -w "\n[HTTP %{http_code} %{time_total}s]\n"
```

⚠️ **UA WAJIB browser** — gateway/proxy Indonesia banyak yang balas 403/timeout
ke UA non-browser dalam 0.0s (pola yang sama seperti provider global).

## 2. Tentukan status gateway

| `/v1/models` | chat tanpa key | Arti |
|---|---|---|
| 401 | 401 | hidup, korporat, wajib signup |
| **200 + daftar model** | **401** | **katalog publik, chat butuh key** — ini yang paling sering terjadi |
| 404 | 404 | endpoint salah, cari baseURL yang benar di docs |
| 200 tapi body 0 byte | — | cek dulu `-o` path (lihat §0), baru simpulkan mati |

Katalog publik **adalah sinyal terbaik** bahwa gateway hidup — bisa count model,
lihat `context_window`, `owned_by`, `description` tanpa bayar apa pun.
Gateway yang katalognya 401 padahal `/` live → hampir pasti butuh key.

## 3. Cek halaman marketing — 4 red flag yang sudah terbukti

Tiap-tiap ini ditemukan nyata di **SahabatMobile** (Okt 2026):

1. **Bug konversi mata uang di tabel harga.** `OpenAI o1-pro` ditulis
   "Rp 4.920.467 per 1M token" — itu US$4,92 yang salah diformat jadi rupiah
   (pembuat halaman mengira angkanya sudah USD lalu menempelkan "Rp").
   Tanda: harga flagship玩意儿 terlihat mustahil (> Rp1 juta/1M token).
2. **Docs model salah nama.** `{"openai/gpt-4o": {"name": "Claude Sonnet 4"}}` —
   copy-paste, artinya tabel tidak pernah di-review.
3. **Widget tractionodnahan marketing.** Klaim "#1 di Indonesia" tapi widget
   sendiri: 32 pengguna terdaftar, 5 pelanggan bayar, 568 API call/30 hari.
   → **marketing, bukan fakta.** Catat angkanya apa adanya.
4. **"Mulai Rp 0" / "gratis"** → selalu scroll cari: apakah free tier-nya model
   asing (bukan model yang mereka klaim develop), dan apakah perlu top-up dulu.

⚠️ Free tier yang *benar-benar* gratis biasanya punya syarat: daftar email,
tanpa kartu kredit, kuota harian kecil, dan modelnya **asing** (Poolside,
Cohere, Gemini Flash) — bukan model milik provider itu sendiri. Itu normal dan
bukandishonest — tapi jangan disuruh useráníhápaid untuk "mendukung AI nasional".

## 4. Menguji model open-weight (bukan gateway)

```bash
curl -s -A "$UA" "https://huggingface.co/api/models?author=<Org>" | python3 -c "
import sys,json
for m in json.load(sys.stdin): print(m['modelId'],'| dl:',m.get('downloads'),'| gated:',m.get('gated'))"
```
- `downloads` dari API = total; **angka "Downloads last month"** di halaman web =
  berbeda (langsung lebih besar). Sebut yang mana yang dipakai.
- `gated: None` = bobot bebas unduh.
- Cari `?search=<nama>` untuk model di luar org utama (mis. sahabatai-70b tidak
  ada di org GoTo, tapi ada di org Sahabat-AI).
- **Adopsi = bukti.** Model 70B dengan 36 download berarti proyek research,
  bukan produk. Klaim "paling sophisticated" tidak ada artinya tanpa base user.

## 5. Menjawab "setara apa di dunia?" — cara yang jujur

Jangan bandingkan berdasarkan nama marketing. **Bongkar base-nya** dari model
card:
- Baris `base architecture` / `Model size` / `tokenizer` → model的基础 apa.
- Llama 3.1 70B + CPT/SFT = **kemampuan setara base-nya saja**, tidak lebih.
  Yang Ditambah =coverage bahasa/budaya, bukan intelligence.
-词语kuncinya: **Continued Pre-Training (CPT)** menambah bahasa;
  **Instruction/Preference Tuning (SFT/DPO)** menambah kepatuhan;
  ** distillation/pretraining dari nol** = intelligence baru. Bedakan tiga ini
  dalam jawaban, karena itu yang jujur.
- **Cek judge/benchmark di model card** — kalau benchmark-nya memakai
  `gpt-3.5-turbo` sebagai baseline dan `gpt-4-1106-preview` sebagai judge,
  itu artinya era benchmark-nya 2023-2024 → model ini memang kelas itu.
- Bandingkan berdasarkan **tahun base model**, bukan tahun klaim produk.

## 6. Format jawaban yang dipakai (terbukti dipakai user)

- Kasih **angka** (params, context, VRAM, jumlah download, jumlah model).
- Kasih **base model** dan apa artinya secara praktis.
- Kasih **jarak generasi** ("1,5–2 generasi di belakang"), bukan "lebih rendah".
- **Tutup dengan verdict 1 kalimat + probabilitas**, dan **satu langkah nyata
  berikutnya** — jangan berhenti di "menarik tapi belum".
- Tidak pernah|Uses yang tidak diuji sebagai kalau sudah diuji.