# Cari bug tersembunyi di Flutter tanpa Flutter terpasang

**Kapan dipakai:** `flutter` tidak ada di Termux, `flutter analyze` di CI di-set
`|| true`, ataumu glance code sudah "hijau" tapi app crash. User minta
"perbaiki bug dan buang yang tak guna" dan kamu butuh bukti, bukan tebakan.

---

## 1. Prinsip yang bikin bug ini tersembunyi

> **Dart hanya mengompilasi file yang terjangkau dari `lib/main.dart`.**
> File mati = bug fatal (`undefined name`) yang **tidak akan pernah** ketahuan
> `flutter build`, `flutter analyze`, atau CI mana pun.

Kasus nyata: `otp_screen.dart` memakai `sessionProvider` tapi tidak meng-import
`core/auth/session.dart` → compile error. Build tetap hijau **4 rilis berturut**,
karena file itu tidak terjangkau dari `main.dart` dan tidak pernah dikompilasi.
Akar masalahnya lebih dalam lagi: `/auth` tidak terdaftar di router → file jadi
yatim → semua file auth mati bersama.

**Konsekuensi:** "build sukses" bukan bukti app bisa jalan. Reachability dari
entrypoint adalah pemeriksaan yang paling penting, dan paling sering dilewatkan.

---

## 2. Bangun `check_dart.py` (python, tanpa dependency)

Cek yang terbukti berguna, urut dari nilai tertinggi:

| Cek | Menangkap apa |
|---|---|
| `DEAD-FILE` | file tidak terjangkau dari `main.dart` (akar bug tersembunyi) |
| `MISSING-IMPORT` | simbol milik project dipakai tanpa import → `undefined name` |
| `ROUTE-UNKNOWN` | `context.go('/x')` ke rute tidak terdaftar → `GoException` |
| `UNUSED-IMPORT` | hygiene |
| `UNUSED-PROVIDER` | Riverpod provider tak pernah di-`watch`/`read` |
| `BRACE` | kurung tak seimbang setelah string & komentar dibuang |
| `NON-LATIN` | karakter IME bocor ke source (lihat skill terpisah) |
| `ASSET` | folder aset di `pubspec` hilang/kosong |

Pasang di CI sebagai **BLOKIR**:

```yaml
- name: Dart static check (blocking)
  run: python3 tool/check_dart.py     # JANGAN `|| true`
```

---

## 3. Jebakan implementasi yang gw buat sendiri (semua sudah diperbaiki)

### a. Cari import di kode yang string-nya sudah dibuang → 0 import terdeteksi

```python
for kind, _, spec, tail in IMPORT_RE.findall(body):
```

`strip()` mengganti `'package:...'` dengan spasi, jadi **tidak ada satu pun import
yang cocok**. Gejalanya jelas: semua file dilaporkan `DEAD-FILE`.

→ Cari import di `raw[f]` (kode mentah). Regex `^[ \t]*import\s+'...'` sudah cukup
presisi, tidak perlu di-strip.

### b. Cek rute di kode yang sama → `ROUTE-UNKNOWN` diam

`'  /auth'` juga string literal. Sama seperti (a): nama rute harus dicari di `raw`.

### c. Extension dicek dari file yang salah → semua `import app_colors.dart` dianggap mati

```python
yang salah di kode Dart (mis.
```

Harus `extension_members(code[target])` — extension yang diekstrak harus milik
file **target**, karena `context.colors` dipakai implisit lewat extension.
Kalau salah: 7 false positive sekaligus.

### d. Ekstraksi member extension yang langsung break

Loop yang mencari `{` lalu `break` begitu `depth == 1` menghasilkan `blk` kosong.
Harus: mulai dari `{` yang cocok, scan sampai `}` pasangannya.

```python
for m in re.finditer(r"\bextension\s+\w+\s+on\s+[\w<>,?\s]+?\{", body):
    depth, i, start = 0, m.end() - 1, m.end()
    while i < len(body):
        if body[i] == "{": depth += 1
        elif body[i] == "}":
            depth -= 1
            if depth == 0: break
        i += 1
    blk = body[start:i]
```

### e. `is_file()` + `Path` vs string

```python
yang salah di kode Dart (mis.
yang salah di kode Dart (mis.
```

### f. Deteksi kode mati yang salah hitung (paling sering menjebak)

Dua versi salah:

```python
yang salah di kode Dart (mis.
total = sum(... for f in owners)
# -> `AppColors.primary` dilaporkan mati padahal dipakai di 20 file
yang salah di kode Dart (mis.
outside = sum(... for f in files if f not in owners)
```

Dan **70-an false positive** muncul kalau ikut menghitung `class` privat
(`_Widget`), `State`, `extension` — semuanya memang dipakai di file-nya sendiri.
L Reporter hanya yang `outside == 0 AND inside <= 1`.

---

## 4. Wajib: fault-injection test

Cek yang selalu balas "0 masalah" tidak berarti apa-apa. Buktikan bisa menangkap:

```bash
cp -r project /tmp/faulttest && cd /tmp/faulttest
# kembalikan bug secara sengaja, lalu:
python3 tool/check_dart.py; echo "EXIT = $?"
```

Harus keluar beberapa masalah + `EXIT = 1`. Contoh hasil yang benar:

```
[MISSING-IMPORT] lib/features/auth/presentation/otp_screen.dart
    pakai `sessionProvider` yang dideklarasikan di core/auth/session.dart,
    tapi file itu tidak di-import -> `undefined name` saat kompilasi
[ROUTE-UNKNOWN] lib/features/splash/presentation/splash_screen.dart
    navigasi ke '/auth' tapi rute itu tidak terdaftar
    (terdaftar: /, /absen, /home, /onboarding) -> GoException saat runtime
EXIT = 1
```

---

## 5. Bug runtime yang paling sering luput di Flutter

**1. Rute yang dipakai tapi tidak terdaftar.** go_router melempar
`GoException: no routes for location: /x`. Cek: semua `context.go|push|replace`
vs semua `path:` di router. Go yang cepat: `grep -rn "context\.\(go\|push\)(" lib/`
lalu bandingkan dengan `grep -n "path: '" lib/core/router.dart`.

**2. State async = race saat aplikasi dibuka.** `StateNotifier` yang baca
SharedPreferences di constructor punya `state` kosong selama beberapa milidetik.
Guard yang memanggil `session.sudahLogin` akan **salah menilai** dan menampilkan
tolak akses. Fix: flag `siap` di state, UI menunggu `siap == true`.

**3. Persistensi setengah jadi.** Menyimpan role tapi tidak menyimpan user →
selalu logout. Cek: setiap `masuk()` harus punya pasangan `get` di method muat.
Simpan user sebagai **JSON**, bukan field terpisah, supaya tidak ada key yang
tertinggal.

**4. Navigasi dari `SharedPreferences` terpisah.** Kalau splash punya salinan
kunci sendiri ("kubar_role" ditulis 2x), pasti akan berbeda diam-diam.
Solusi: `abstract final class SessionKeys { static const String user = ...; }`
dipakai bersama.

**5. `ref`/`context` di field initializer = COMPILE ERROR (15 Okt 2026,
ketahuan dari CI yang gagal, bukan dari baca kode).**

```dart
class _XState extends ConsumerState<X> {
  late final TextEditingController _a =      // LOLOS kompilasi
      TextEditingController(text: ref.read(p).user?.name ?? '');
  final TextEditingController _nik =         // GAGAL: Undefined name 'ref'
      TextEditingController(text: ref.read(p).user?.nik ?? '');
}
```

Dart **tidak mengizinkan akses member instance** (`ref`, `context`, `widget`)
di initializer field. Gejalanya paling menyesatkan: `check_dart.py` hijau tapi
CI merah dengan `edit_profil_screen.dart:37:13: Error: Undefined name 'ref'`.
`late final` lolos karena initializer-nya ditunda - tapi runtime-nya baru
jalan saat controller dibaca pertama kali, jadi bugnya muncul jauh dari
tempat ditulisnya.

Cek yang ditambahkan (`REF-FIELD-AWAL` di `check_dart.py`) harus dari **bentuk
kode**, bukan symbol table - `ref` memang sah sebagai member, jadi tabel
simbol tidak akan pernah menangkapnya. Aturan yang bekerja:

- hanya field di body class (indent 2 spasi, `class` mulai kolom 0)
- SKIP `late` (legal, initializer ditunda) dan SKIP `static` (tanpa instance)
- SKIP getter (`=>`) dan initializer yang cuma literal/const
- initializer boleh multiline: kumpulkan sampai kurung seimbang DAN ada `;`
- regex: `r"^  (?!late\b)(?!static\b)(?:covariant\b\s+)?final\b[^=;]*?\s(\w+)\s*=\s*(.*)$"`
- loop sampai `buf.count("(") == buf.count(")") and ";" in buf`, maks 8 baris

**Jebakan saat menulis ceknya:** versi pertama hanya memotong SATU baris
(`(.*)$` tanpa melanjutkan ke baris berikutnya) - `final X = Foo(` di baris
pertama terdeteksi, tapi `final X =` di baris 38 dengan initializer di baris 39
LOLOS. Fault-injection wajib memakai bentuk yang justru tidak terdeteksi.
Bug yang gw temukan di codebase sendiri persis bentuk yang kedua itu.

**Bonus (paling berguna di proyek tanpa laptop):** jangan cuma andalkan
`flutter analyze` di CI. Tambah input `release: yes|no` di `build.yml` supaya
`gh workflow run build.yml --ref <branch> -f release=no` bisa memverifikasi
kompilasi **tanpa** membuat draft release + AAB (AAB build melambat ~2 menit
dan Bardakan tag release yang tidak dipakai).

---

## 5b. `Hasil`-style wrapper: konstruktor yang tipped (15 Okt 2026)

`Hasil.gagal('teks')` gagal kompilasi karena parameter bertipe `GalatData?`,
BUKAN String - padahal `constrainternya` sudah terlihat benar di mata
(`const GalatData` vs `galat`). Cek UNDEF-MEMBER tidak menangkapnya karena
method-nya MEMANG ADA; yang salah hanya tipe argumennya.

Cek yang bekerja (regex, cukup andal karena `Hasil` itu nama sendiri):
`\bHasil\s*(?:<[^()<>]*>)?\s*\.\s*(?:gagal|galat)\s*\(\s*(['\"])`
-> kalau argumen pertama literal kutip, itu compile error.

Sebut juga alias `galat`: alias Constructor yang meniru nama ARTIFACT
(`Hasil.galat` untuk `GalatData`) membuat pemanggilannya terlihat benar
padahal tipe parameternya berbeda. Kalau sebuah kelas punya alias constructor,
cek tipe parameter setiap alias-nya - jangan hanya memastikan alias-nya ADA.

## 5c. Tombol back perangkat = `push()` vs `go()` (15 Okt 2026)

Gejala: dari halaman mana pun tombol back langsung **menutup aplikasi**.

Akar hampir selalu satu: navigasi drill-down memakai `context.go()`, yang
MENGGANTIKAN riwayat navigasi -> tidak ada yang bisa di-pop. `go()` hanya
benar untuk perpindahan root.

| Kebutuhan | Method |
|---|---|
| Masuk halaman lain (punya "sebelumnya") | `push()` |
| Ganti akar halaman (login, logout, selesai onboarding, ganti tab) | `go()` |

**Jebakan 1 - bottom nav bukan rute.** Pola bottom nav yang umum
(`IndexedStack` + `navigationIndexProvider` = 1 rute `/home`) tidak punya
"halaman sebelumnya" per tab, jadi back = tutup app. Solusinya:
```dart
PopScope(
  canPop: aman == 0,                    // tab 0 -> memang boleh keluar
  onPopInvokedWithResult: (bool didPop, Object? _) {
    if (didPop) return;
    if (aman != 0) ref.read(navigationIndexProvider.notifier).state = 0;
  },
  child: Scaffold(/* ... */),
)
```

**Jebakan 2 - satu layar dipakai 2 cara.** Galeri dipakai sebagai tab (tamu) DAN rute
hasil push (aksi cepat). Kalau tidak punya AppBar, saat di-push tidak ada
tombol back terlihat. Solusi: tombol back kondisional
`if (context.canPop()) IconButton(onPressed: () => context.pop(), ...)`.

**Jebakan 3 - `context.push/pop/canPop` itu EXTENSION go_router**, bukan
method bawaan `BuildContext`. File yang sebelumnya tidak pernah memanggil
navigasi sama sekali tidak punya import itu ->
`The method 'pop' isn't defined for the type 'BuildContext'`.
Cek yang menangkapnya: cari `context.(go|push|pop|canPop|replace)\s*\(`,
lalu pastikan ada `import 'package:go_router/go_router.dart';`.

**Cek cepat sebelum bilang "sudah":** `grep -rn "context\.go(" lib/`
-> hasilnya harus hanya file auth + logout + ganti tab + router guard.
Kalau masih ada di layar fitur, navigasinya masih salah.

## 6. Kalau tidak ada kode mati — katakan begitu

Tidak semua permintaan "buang yang tak guna" berakhir dengan penghapusan.
Jadi laporkan jujur: jumlah file hidup, jumlah simbol, berapa yang benar-benar mati
(umumnya 0 di codebase yang bersih), dan apa yang sengaja **tidak** gw sentuh
mis. aset desain yang ditunda. Menghapus widget yang sebenarnya terpakai
justru merusak aplikasi.