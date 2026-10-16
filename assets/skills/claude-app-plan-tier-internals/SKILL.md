---
name: claude-app-plan-tier-internals
description: Peta lengkap gate plan tier di APK Claude Android (Anthropic) — kelas o9y, p5x, cpn, bpn, dan kenapa Fable/upgrade popup tetap muncul kalau plan dipaksa ke MAX (harus RAVEN).
when_to_use: Saat memod APK Claude untuk membuka Pro/Max, atau saat men-debug kenapa model premium / popup "Upgrade" masih muncul setelah patch.
---

# Gate plan tier APK Claude Android

## Peta kelas (semua obfuscated, R8)
| Kelas | File | Peran |
|---|---|---|
| `p5x` | `smali/p5x.smali` | enum tier plan: `v`=FREE, `w`=PRO, `x`=MAX, `y`=RAVEN |
| `o9y` | `smali/o9y.smali` | `z(Lynn;)Lp5x` = **resolver plan tier** (20 call site!) |
| `o9y.A(Lynn,String)Z` | | baca feature flag server dari `Lynn.d` |
| `cpn` | `smali_classes3/cpn.smali` | array int tier→nilai requirement |
| `bpn` | `smali/bpn.smali` | filter + pemilihan model per tier |
| `o1m` | `smali/o1m.smali` | ModelOption dari server |
| `d4m` | `smali_classes3/d4m.smali` | pasangan (nama model → tier) |
| `cg00` | `smali/cg00.smali` | `e()`=isFree, `f()`=isRaven |
| `fh6` | `smali/fh6.smali` | fitur internal, cek tier RAVEN |

## ⭐ PETA NILAI TIER (`cpn.a`) — INI KUNCI UTAMA
```
index 0 (FREE)  -> 3
index 1 (PRO)   -> 2
index 2 (MAX)   -> 1     ← nilai TERENDAH, model paling banyak
index 3 (RAVEN) -> 4     ← nilai TERTINGGI, model paling sedikit
```
Di `bpn` (~line 425) model difilter: `cpn.a[modelTier] > userTierValue` → **buang**.

## ⚠️ JEBAKAN TERBESAR: MAX TIDAK CUKUP
Dulu saya paksa `z()` return MAX → user masih lihat pop-up "Upgrade" saat pilih Fable.
**Fable butuh nilai tier 4 = RAVEN.** MAX cuma nilai 1.
→ Patch harus ke **`Lp5x;->y` (RAVEN)**, bukan `x` (MAX).

Tapi `p5x.a()` asli **return FALSE untuk RAVEN** (ordinal 3) — jadi kalau hanya
ganti ke RAVEN, entitlement check (`o600`/`vbh`/`xy20`) akan menolak.
→ HARUS patch `p5x.a()` juga jadi selalu true.

## PATCH SET YANG WORKS (3 titik)
```smali
# 1) smali/o9y.smali -> .method public static final z(Lynn;)Lp5x;
    sget-object v0, Lp5x;->y:Lp5x;      # RAVEN, bukan MAX
    return-object v0

# 2) smali/p5x.smali -> .method public final a()Z
    const/4 v0, 0x1                      # RAVEN jadi entitled
    return v0

# 3) smali/bpn.smali -> filter "inactive" model dari server
    const/4 v2, 0x0                      # menggantikan n6i.k(d, TRUE) → selalu false
    if-nez v2, :cond_1e
```

## Kenapa patch #3 perlu
Server kirim `o1m.d` = Boolean **inactive**. Anthropic menandai Fable inactive
untuk akun free → model hilang / kena gate. Filternya di `bpn` line ~754.
JANGAN patch `n6i.k()` (util equality generik, dipakai luas, berbahaya).

## Daftar model = DARI SERVER
`bpn` `pswitch_2`: ambil `Lynn.r` =
`"claude_ai_bootstrap_models_config"` (field `"claude_ai_bootstrap_models_config"`
di descriptor `unn`). Kalau null → log
`"Organization is missing claude_ai_bootstrap_models_config"`.
Artinya **daftar model tidak ada di APK** — client cuma filter. Model yang tidak
dikirim server tetap tidak bisa dimunculkan meski gate-nya dibuka.

## Batas fisik
`usage_limit_reached` = error SERVER (`d6s` = API error wrapper). Patch hapus
UI gate & pre-check, kuota server tetap berlaku. claimed "unlimited" tidak
bisa shouted.

## Launcher icon
APK asli **tidak punya** `android.intent.category.LAUNCHER` (nol) → tidak muncul
di home screen. Itu by-design APK "Morphe", bukan bug patch. Fix: tambah
`<category android:name="android.intent.category.LAUNCHER"/>` di
`AndroidManifest.xml` MainActivity intent-filter — tapi rebuild resource aapt2
di Termux bermasalah (`$` di nama resource ditolak). Butuh patch binary manifest
atau build di luar Termux.

## ⛔ LIMIT FREE = SERVER-SIDE, TIDAK BISA DIHAPUS DENGAN PATCH (dibuktikan 10 Okt 2026)

Pertanyaan user: "cara menjinakan AI Claude agar tidak limit versi gratisnya".
Jawaban dari bedah APK + sumber luar: **tidak bisa dari sisi app.**

**Bukti dari APK** (`Claude-Mod-MAX-unlocked.apk` + APK asli, `classes*.dex`):
- Limit datang sebagai frame **SERVER**: string `session_rate_limit frame`,
  `MessageLimitEvent(message_limit=`, `ApproachingLimit(resetsAt=`,
  `ExceedsLimit(resetsAt=`, `PersistedRateLimit(resetsAtMillis=`,
  `rate_limit_info`, `rate_limit_tier`, `resets_at`.
- Field `resets_at` **selalu dari server** — app cuma menampilkan countdown.
- Artinya: patch hanya bisa **sembunyikan UI gate / pop-up upgrade / pre-check**;
  begitu kuota server habis, server **menolak request** (`usage_limit_reached`,
  `429`) dan tidak ada byte klien yang bisa mengubah itu.
- `MESSAGE_LIMIT_STATUS_WITHIN_LIMIT / APPROACHING / UNSPECIFIED` = status yang
  DIKIRIM server tiap turn, bukan hitungan lokal.

**Konsisten dengan sumber luar (jangan janjikan "unlimited"):**
- Blog bahkan menganggap semua "Claude Mod unlimited" = scam/malware: keputusan
  free-vs-paid dibuat di server Anthropic tiap request, tidak ada saklar di HP.
- XDA/reverse-engineering: limit = **rolling 5 jam**, lebih ketat jam sibuk
  (peak = 05:00–11:00 PT / 8am–2pm ET), model Haiku lebih banyak kuotanya.

**Yang BENERAN memperpanjang kuota (teknik PAKAI, bukan patch — sampaikan ini):**
1. **Chat pendek**: mulai chat baru tiap 15–20 pesan. Thread panjang = kuota
   boros eksponensial (Claude baca ulang seluruh history tiap turn).
2. **Kompres konteks**: minta Claude ringkas obrolan jadi ~200 kata, tempel di
   chat baru.
3. **Model kecil (Haiku)** untuk tugas ringan → jauh lebih banyak pesan.
4. **Chat di luar jam sibuk** → limit digandakan (promo berulang Anthropic).
5. Bagi kerja ke beberapa sesi 5 jam.

**Bypass asli satu-satunya = rotasi akun** (server-side). ⚠️ Langgar ToS +
risiko ban — sebut sebagai opsi terakhir + risikonya, jangan jadi saran utama.

**Alternatif tanpa limit yang sudah user punya:** chain gratis zyvo sendiri
(`gpt-6.1-sol`, `glm-5.3`, dst — 30 req/menit, 17 fallback). Ini jawaban jujur
untuk "AI bagus tanpa limit harian".