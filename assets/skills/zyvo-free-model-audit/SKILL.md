---
name: zyvo-free-model-audit
description: Cara mengaudit dan memperbarui daftar model AI gratis di zyvo/OpenCode Zen -artes Live-test chat/completions per model, pulihkan config yang tertimpa `zyvo update`, dan bangun fallback_models. Use when the user says "update opencode zen", "update model AI free", "modelnya mati", "zypo/zypo gratis", "kuota habis", "ganti model", atau saat fallback_models perlu disegarkan.
---

# Audit model AI gratis zyvo (OpenCode Zen)

## Kapan dipakai
- "modelnya mati", "ganti model", "kuota habis", "update zyvo/opencode"
- Setelah `zyvo update` (installer menimpa `~/.config/zyvo/zyvo.json`)
- Saat pruning `fallback_models`

## 0. Dua jebakan yang PALING mahal
| Jebakan | Gejala | Solusi |
|---|---|---|
| `max_tokens` kecil (`<300`) | Model reasoning (`glm-5.3`, `gpt-oss-120b`) balas `content:null` → apparent MATI | Selalu `max_tokens >= 300` |
| Audit PARALEL ke apinex | 4 model balas `400 "The request is invalid..."` padahal sehat | Konfirmasi dg **1 request SERIAL** |

Yang kedua pernah hampir menghapus model utama `gpt-6.1-sol` dari config.
`429` = rate-limit/sementara (retry 2-3x, `sleep 4`). `402` = permanen buang.

## 1. Jaring pengaman (SELALU, sebelum edit)
```bash
cd ~/.config/zyvo
cp zyvo.json "zyvo.json.bak-prune-$(date +%Y%m%d-%H%M%S)"
```
`zyvo update` juga bikin `.bak-*` sendiri (keadaan SEBELUM update).

## 2. Baca config
```bash
python -c "
import json;d=json.load(open('/data/data/com.termux/files/home/.config/zyvo/zyvo.json'))
print('model:',d['model'],'| small:',d['small_model'])
print('fallback:',len(d.get('fallback_models',[])))
for p,v in d['provider'].items(): print(p,'->',list((v.get('models') or {}).keys()))"
```
`baseURL` & `apiKey` ada di `v['options']`.

## 3. Audit live SEMUA model (provider.models + fallback + utama)
Kumpulkan `set` dari ketiganya, lalu `ThreadPoolExecutor(8)` ke
`{baseURL}/chat/completions`. Header WAJIB: `Authorization: Bearer`,
`Content-Type: application/json`, `User-Agent` **browser** (Tanpa UA browser
Cloudflare balas 403 dalam 0.0s -> semua provider apparent mati).
Klasifikasikan: `200 OK` (isi `content` ATAU `reasoning_content` non-kosong)
/ `402` (buang) / `404` (buang) / `429,525,502,503` (retry).
Hasil 400 dari apinex saat paralel = **rate-limit, konfirmasi serial dulu**.

## 4. PRAGMA "NOL TAGIHAN" - buang ROUTER
Model seperti `kilo-auto/*` = **router**, bukan model. Balance 0 tetap balas
200 (pilih rute termurah) tapi bisa sewaktu-waktu meneruskan ke model
**berbayar**. Keamanan nol tagihan => **router wajib dibuang** dari
`provider.models` DAN `fallback_models`. Sama: nama yang mengandung `claude`,
`opus`, `anthropic` = 402 top-up di semua provider (tidak ada Claude gratis).

## 5. Prune
Buang 402/404 dari `provider[p]['models']` (dict) + `fallback_models` (list).
`model` & `small_model` tidak boleh berubah tanpa alasan (pilihan user).
Validasi: `json.load` lagi + `grep -c "kilo-auto\|claude\|opus\|glm-5\.2" zyvo.json` -> 0.

## 6. Ganti model config
Edit `~/.config/zyvo/zyvo.json` langsung, **lalu user restart zyvo sendiri**.
⛔ JANGAN `pkill zyvo` saat menulis config = bunuh diri sendiri.
⚠️ **Setiap edit manual WAJIB disinkronkan** ke `zyvo.json.mine` (lihat §8) —
shim restore membacanya, `.mine` basi = mengembalikan versi lama.

## 7. Jebakan tes: "PASS" palsu saat uji guard update

Membandingkan `sha256sum zyvo.json` SEBELUM update dengan file **yang sudah
terlanjur tertimpa** menghasilkan "PASS" yang tidak benar. Urutan yang benar:

```bash
cd ~/.config/zyvo
# 1. tulis config curated dulu
CUR=$(sha256sum zyvo.json | cut -c1-16)
# 2. baru jalankan update
zyvo update
# 3. bandingkan
[ "$(sha256sum zyvo.json | cut -c1-16)" = "$CUR" ] && echo LULUS || echo GAGAL
```

Ini bukan teori — terjadi sekali pada 13 Okt 2026: config sudah ketimpa
sebelum shim dipasang, lalu "PASS" muncul karena kedua-duanya sudah sama
yangsalah.

## 8. `zyvo update` menimpa config — DIJAGA PERMANEN oleh shim `~/bin/zyvo`

Dua titik di `zyvo9/ZYVO-AI/install.sh` yang merusak:

| # | Lokasi installer | Akibat |
|---|---|---|
| 1 | `refresh_config()` ~baris 328-344: `mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"` **tanpa syarat** | `zyvo.json` diganti config default tiap update |
| 2 | baris ~103-109 & 483-484: `cp ... "$PREFIX/bin/${BINARY_NAME}"` | wrapper `$PREFIX/bin/zyvo` ditulis ulang tiap update |

⛔ **Konsekuensi:** patch di dalam `$PREFIX/bin/zyvo` **selalu mati** — installer
menimpanya lagi. Terbukti patch 155 baris hilang jadi 132 setelah 2 update.

✅ **Shim di `$HOME/bin/zyvo`** = satu-satunya tempat yang bertahan:

```
$HOME/bin  (PERTAMA di PATH)   ← installer tidak pernah menulis ke sini
$PREFIX/bin/zyvo               ← installer menimpa tiap update
```

PATH Termux urut `~/bin` → `$PREFIX/bin`, jadi shim menang. Isinya:
- semua perintah selain `update` → `exec "$PREFIX/bin/zyvo" "$@"`
- `update` → (a) `cp zyvo.json zyvo.json.mine`, (b) pipe installer lewat
  `sed` yang mengganti baris `mv` dengan versi bersyarat **dan** mengganti
  pesan `info "Default config installed"` (pesan itu baris TERPISAHAH di bawah
  `mv` — kalau hanya menambal `mv`, pesan bohong tetap tercetak),
  (c) restore `.mine` bila file berubah.
- Fresh install tetap dapat config default (file belum ada).
- Escape hatch: `ZYVO_FORCE_DEFAULT=1 zyvo update`.

Verifikasi dua jalur (keduanya wajib, jangan asal):
```bash
# jalur "up to date" (refresh_config baris ~388) — live
sha256sum ~/.config/zyvo/zyvo.json > /tmp/a; zyvo update; sha256sum ... 
# jalur full install (baris ~503) — sandbox, jangan di $HOME sungguhan
SB=$(mktemp -d); mkdir -p $SB/.config/zyvo; echo '{"my":"config"}' > $SB/.config/zyvo/zyvo.json
HOME=$SB bash <installer-yang-sudah-di-sed>   # cek $SB/.config/zyvo/zyvo.json masih isinya

## 9. Bug headless `zyvo v1.17.9`: `Service not found: @opencode/Provider`

**Status 13 Okt 2026: BELUM DIPERBAIKI — bawaan build Android, bukan config.**

| Perintah | Hasil |
|---|---|
| TUI (`zyvo`) | ✅ jalan |
| `zyvo models` / `run` / `auth list` / `mcp list` / `debug config` | ❌ crash |
| `zyvo --version`, `--help` | ✅ jalan |

Yang sudah dibuktikan (jangan ulangi riset ini):
- Terjadi walau `OPENCODE_CONFIG_DIR` berisi `{}` → **bukan** masalah config.
- Tetap sama tanpa `LD_PRELOAD=libtagfix.so` → **bukan** libtagfix.
- Bundle punya **2 salinan** (offset ~113 MB & ~135 MB). Keduanya mendeklarasikan
  service dengan benar:
  `Service56 = class Service56 extends Context.Service()("@opencode/Provider")`
- `defaultLayer42` (= `layer83` + 7 sub-layer) juga **lengkap dan benar**.
- Penyebabnya: di jalur headless, layer itu tidak pernah di-*merge* ke context
  sebelum `use13()` dipanggil → `Effect` melempar
  `serviceNotFoundError`. Ini bug wiring upstream di build Android, bukan
  masalah konfigurasi lokal.

⛔ **Jangan coba patch binary 172 MB** untuk ini — risk/reward-nya buruk.
Pakai TUI. Kalau user butuh headless, sampaikan jujur statusnya.

## Verifikasi akhir
```
44/44 hidup | 5 provider | 26 fallback | router: 0 | claude/opus: 0
```
Semua model config harus 200 OK dengan isi benar sebelum bilang "selesai".

## Katalog gratis Zen: live `/v1/models` vs models.dev (13 Okt 2026)

Dua sumber ini **tidak boleh dicampur** —hasilnya saling bertentangan:

| Sumber | Jumlah "gratis" | Arti |
|---|---|---|
| `models.dev/api.json`, provider `opencode`, filter cost==0 | **38** | metadata registri statis, termasuk model yang tidak dikasih ke akun free |
| `GET opencode.ai/zen/v1/1models` dengan `oc_sk_` milik akun | **10** | ✅ **ini yang benar-benar bisa dipakai** |

Jadi `exo-free`, `glm-5-free`, `minimax-m3-free`, `qwen3.6-plus-free` dll
**ada di models.dev tapi TIDAK ada di katalog live** — jangan tambah ke config
berdasarkan models.dev saja. Sumber kebenaran = `/v1/models`.

Katalog live gratis (10, per 13 Okt 2026): `space-bunny-free` · `big-pickle` ·
`nemotron-3.5-lightning-free` · `ling-3.1-flash-free` ·
`longcat-2.5-preview-free` · `mimo-v2.6-flash-free` ·
`muse-spark-1.2-contributor-free` · `muse-spark-1.3-contributor-free` ·
`step-5-preview-free` · `jev-1.13-free`.

Cek cepat:
```bash
curl -s -H "Authorization: Bearer $KEY" \
  -H "User-Agent: Mozilla/5.0 Chrome/154.0" \
  https://opencode.ai/zen/v1/models \
  | python3 -c "import sys,json;print('\n'.join(sorted(m['id'] for m in json.load(sys.stdin)['data'] if 'free' in m['id'] or m['id'].endswith('pickle'))))"
```

## Membatasi daftar /models (proven 13 Okt 2026)

`/models` mengambil daftar dari katalog server. Untuk **membatasi** isi daftar
itu (user minta "sisakan hanya N model"), tulis blok `models` eksplisit di
provider itu — itu yang meng-override katalog:

```json
"provider": {
  "opencode": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "OpenCode Zen",
    "options": { "baseURL": "https://opencode.ai/zen/v1", "apiKey": "oc_sk_..." },
    "models": { "space-bunny-free": { "name": "Space Bunny Free" } }
  }
}
```
Provider yang bloknya dihapus = seluruh modelnya hilang dari `/models`.
`{ "name": "..." }` saja sudah cukup; `limit`/`tool_call` opsional.

Provider ID = **nama entry di `~/.local/share/zyvo/auth.json`**, bukan nama
bebas. Kalau auth store-nya `opencode`, ID-nya `opencode` — memakai `zen-public`
akibatnya kunci tidak ketemu.

## ⚠️ 403 FreeTierError BUKAN model mati (revisi penting)

Untuk `opencode.ai/zen/v1`:

| Endpoint | Dari luar app | Arti |
|---|---|---|
| `GET /v1/models` | **200** (43 model) | aman dipakai verifikasi nama |
| `POST /chat/completions` | **403 FreeTierError** | NORMAL — "free tier only from within OpenCode" |

Jadi model Zen free **tidak bisa diuji via curl** — jangan simpulkan mati dari
403 itu. Bukti hidup: model itu muncul di `/v1/models` + sesi app jalan di
modelnya. Menolak dengan 403 justru benar secara privasi.

Konsekuensi untuk audit: model dari provider yang butuh "dari dalam app"
(tipe Zen free) **tidak bisa di-pakai sebagai pembuktian live** — hp itu jadi
pembuktiannya, bukan curl.pollanya

## Menambah provider = remember hapus yang mati

Setelah pruning, cek SEMUA referensi: `model`, `small_model`, tiap entri
`fallback_models` harus ada di blok `models` provider-nya. Kalau provider dihapus
tapi `fallback_models` masih nunjuk ke sana, zyvo gagal start.

Script validasi cepat:
```python
prov={k:set(v.get("models",{})) for k,v in d["provider"].items()}
bad=[r for r in [d["model"],d["small_model"]]+d["fallback_models"]
     if r.split("/")[0] not in prov or r.split("/",1)[1] not in prov[r.split("/")[0]]]
assert not bad, bad
```

## 🔎 Cara jawab "yang gratis dan no limit / limit besar" (proven 15 Okt 2026)

User sering bertanya begitu. **Jawaban jujur: tidak ada free tier tanpa limit.**
Yang bisa diukur = **seberapa lega sekarang**, dan itu berubah tiap hari.

### Metode: burst test, jangan cuma baca `/models`
Kirim N request beruntun ke model `:free` provider itu, hitung berapa yang 200.
Header rate-limit sering TIDAK dikirim sama sekali, jadi **hanya burst test yang
memberi angka**.

```python
from concurrent.futures import ThreadPoolExecutor
# 10 request, 5 worker, satu model :free -> hitung有多少 200
```
`max_tokens >= 300` (lihat §0). `429` setelah burst beruntun = limit-nya
memang kecil. Tanpa error = lega.

### Hasil terukur 15 Okt 2026 (JANGAN认为 masih valid — cek ulang)
| Provider | baseURL | Hasil |
|---|---|---|
| Kilo `api.kilo.ai/api/gateway` | 10/10 **200 OK** | ✅ paling lega, tanpa header limit |
| xkiro `api.xkiro.com/v1` | semua **429**, `gpt-oss:120b` **404** | ❌ |
| Ollama Cloud `ollama.com/v1` | 18 model terdaftar, **semua 429** | ❌ |
| Zen `opencode.ai/zen/v1` | hidup, ~5 req/menit | tidak bisa diuji curl (§403) |

**Ollama/xkiro bisa berubah dari 429 → 200** — itu rate-limit sementara, bukan
mati. Jangan langsung buang; retry dulu. Yang **permanen** dibuang: `402`,
`404`, dan **router**.

### ⛔ ROUTER = wajib buang, bukan cuma "kurang bagus"
`kilo-auto/free` balas 200 dan isi `"OK."` dengan benar — **tetapi dia router**,
bukan model. Dia memilih rute termurah saat itu; sewaktu-waktu bisa meneruskan ke
jalur **berbayar**. Karena pragma "nol tagihan", router berapapun di config =
bug. Guard: `assert 'kilo-auto' not in json.dumps(cfg)`.

### ⛔⛔ Jebakan validator: `opencode` = provider BUILT-IN tanpa blok `models`
Kode validasi di skill ini (dan versi lama) memakai `provider[p]['models']`.
Untuk provider `opencode` blok itu **tidak ada** → semua rujukan
`opencode/big-pickle` dilaporkan "referensi tak dikenal" padahal itu justru
model yang dipakai app. Fix wajib:
```python
prov.setdefault('opencode', {'*'})
def ok(r):
    pid,_,m = r.partition('/')
    return pid in prov and (m in prov[pid] or '*' in prov[pid])
```
Karena itu sudah kejadian **2x berturut** dan sempat menggagalkan edit config
yang sebenarnya sudah benar. ⛔ Validator yang terlalu ketat = omong kosong.

### Urutan aman edit config
```bash
cd ~/.config/zyvo && cp zyvo.json "zyvo.json.bak-$(date +%Y%m%d-%H%M%S)"
# ... edit + validasi ...
cp zyvo.json zyvo.json.mine      # WAJIB, shim restore baca file ini
```
Config tidak hot-reload → **user yang restart zyvo**, jangan `pkill zyvo`.

### ⚠️ Karakter non-Latin bisa bocor dari IME saat menulis notes
Sudah kejadian **3x** (termasuk saat gw sendiri nulis catatan audit ini —
`解决了怎么做`, `就是`, `बकवास`). Setelah append ke AGENTS.md/skill, selalu scan:
```python
bad=[(i,''.join(c for c in l if 0x2E80<=ord(c)<=0x9FFF or 0xAC00<=ord(c)<=0xD7AF
    or 0x0900<=ord(c)<=0x097F or 0xFF00<=ord(c)<=0xFFEF)) for i,l in enumerate(open(f),1)]
print([b for b in bad if b[1]])
```
Ini persis bug yang sudah dicatat di proyek KUNBAR (`check_nonlatin.py`) —
sekarang nyamuk juga di file memori.
