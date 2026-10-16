# Tambah fitur baru ke app Flutter offline-first (KUNBAR Connect)

Pola yang dipakai untuk FASE 9 + 11 (FISH warga + Panel Pengurus, v0.10.0).
Berlaku untuk app apa pun yang: satu codebase Android+iOS, data lokal dulu
nanti Supabase, dan tidak boleh menampilkan data karangan sebagai data asli.

## 1. Potong fitur jadi satu VERTICAL SLICE, bukan Horizontal

Satu fitur = `domain` + `data` + `presentation` + **satu jalur penuh**:
kirim (warga) -> lihat (pengurus) -> ubah status (pengurus).

Alasan: kalau layar "//belum" masih ada (`_soon(context, 'Aspirasi')`),
belum ada fitur - hanya ada kerangka. Cari dulu tempat yang masih
melempar "segera hadir", dan jadikan itu target.

## 2. Domain: enum di domain, nama DB di DUA fungsi saja

```dart
enum StatusAspirasi { baru, diproses, selesai, ditolak }

extension StatusAspirasiX on StatusAspirasi {
  String get label => switch (this) { ... };      // Dart 3 switch expr
  List<StatusAspirasi> get berikutnya => ...;      // aturan alur, bukan UI
  static StatusAspirasi fromDb(String? v) => StatusAspirasi.values.firstWhere(
        (s) => s.name == v, orElse: () => StatusAspirasi.baru);
}
```

**Aturan alur (mis. "menolak hanya boleh dari status `baru`") taruh di
domain**, bukan di layar. Layar cuma memanggil `status.berikutnya`.

## 3. Data: repository interface + lokal (BENAR-BENAR MENYIMPAN) + Supabase

```dart
abstract class XRepository {
  String get namaSumber;
  Future<Hasil<List<T>>> daftar();
  Future<Hasil<T>> kirim(T x);
  Future<Hasil<T>> ubahStatus(String id, Status s, {String? catatan});
}
```

- Semua kegagalan jadi `Hasil<T>` (`core/data/hasil.dart`), JANGAN `throw`.
- Implementasi lokal memakai `SharedPreferences` + `jsonEncode`.
- `namaSumber` ditampilkan di layar ("Tersimpan di perangkat") - wajib,
  supaya pengguna tahu data belum sinkron ke server.

### ⛔ Data contoh harus DIBEDAKAN dan TIDAK ikut tersimpan

```dart
static List<Aspirasi> contoh() => <Aspirasi>[ Aspirasi(..., contoh: true) ];
// di daftar(): contoh() + tersimpan.data
// di kirim(): hanya tulis a ke _tulis(), contoh TIDAK ikut
```

Field `bool contoh` + label "data contoh" di kartu. Kalau baris contoh ikut
ikut ditulis ke penyimpanan, begitu warga mengirim laporan asli layarnya
bercampur karangan dan administrator - itu persis "mock yang menyamar jadi asli".

### Supabase: setelah `ubah`, baca ulang barisnya

```dart
if (!r.berhasil) return Hasil<Aspirasi>.galat(r.galat!);
final lagi = await _rest.baca('aspirasi', filter: {'id': id});
return Hasil<Aspirasi>.berhasil(Aspirasi.dariBaris(lagi.data!.first));
```

Jangan balikkan objek tiruan dengan `judul: ''` - kartu di layar jadi kosong.

## 4. State: AsyncNotifier yang SELALU muat ulang setelah mutasi

```dart
Future<Hasil<T>> kirim(...) async {
  final h = await ref.read(repo).kirim(a);
  await muatUlang();          // <- wajib, JANGAN andalkan state lokal
  return h;                    // kembalikan Hasil apa adanya untuk snackbar
}
```

Kalau tidak muat ulang, layar bisa menampilkan "berhasil dikirim" padahal
penyimpanan gagal - dan snackbar akan berbohong.

## 5. Presentation

- `RefreshIndicator` untuk muat ulang, bukan cuma tombol refresh di AppBar.
- Form di `showModalBottomSheet(isScrollControlled: true)` + `Form` +
  `TextFormField.validator` (validasi di layar DAN di domain).
- Kartu FISH dipakai di DUA layar (warga & pengurus) - aksi teks
  disuntikkan lewat parameter `void Function(Status baru)? onUbahStatus`,
  default null = mode baca. Satu kartu, dua peran.
- Dialog catatan: `showDialog<String>` + `.whenComplete(controller.dispose)`.

### ⛔ `ScaffoldMessenger` HARUS diambil sebelum `Navigator.pop()`

```dart
final snack = ScaffoldMessenger.of(context);   // sebelum pop
Navigator.of(context).pop();                   // sheet ditutup
snack.showSnackBar(...);                       // context sudah mati kalau erred
```

Setelah `pop()`, `context` milik sheet tidak terpasang -> exception tepat di
layar yang baru saja sukses. Bug yang kalau tidak diuji di perangkat terlihat
"kadang snackbar tidak muncul".

## 6. Navigasi: JANGAN pinoff indeks tab

Jumlah tab berbeda per role. `navigationIndexProvider = 3` mendarat di tab
yang SALAH untuk role lain (tamu punya 4 tab, anggota 5). Tambahkan:

```dart
int indeksTab(UserRole role, String label) {
  final tabs = tabsUntuk(role);
  for (int i = 0; i < tabs.length; i++) {
    if (tabs[i].label == label) return i;
  }
  return 0;
}
```

Angka statistik juga jangan ditulis mati di widget (`value: '128'`).
Ambil dari repository; kalau gagal, tampil `-`.

## 7. Gate sebelum commit

```bash
python3 tool/check_dart.py       # blocking
python3 tool/check_nonlatin.py   # blocking
```

`check_dart.py` menangkap apa yang lolos `flutter analyze`: DEAD-FILE
(reachability dari main.dart), MISSING-IMPORT, ROUTE-UNKNOWN, UNUSED-IMPORT,
UNDEF-MEMBER, BRACE, NON-LATIN, ASSET.

### ⛔ Wajib fault injection untuk tiap cek yang baru/diubah

Rename method yang dipakai, hapus import yang dipakai, tulis rute palsu.
Kalau cek tetap bilang "0 masalah", berarti ceknya kosong, bukan kodenya
bersih. Dua bug nyata yang ketahuan dengan cara ini:

1. **Regex method generic**: `\b(\w+)\s*\([^)]*\)\s*\{` tidak cocok dengan
   `Hasil<R> peta<R>(R Function(T nilai) ubah) {` (ada kurung bersarang +
   `<...>` di tengah). Gejalanya: pesan error menunjuk file yang BENAR tapi
   bohong -> mudah disalahkan. Perbaikannya dua lapis: izinkan satu tingkat
   kurung bersarang DAN `<[^()<>]*>` (bukan `[^()]*` - itu rakus sampai
   menelan `peta` jadi bagian generic).
2. **State bocor antar-loop di cek UNUSED-IMPORT**: himpunan member extension
   dikumpulkan SEBELUM loop import, jadi `.text` dari `app_theme.dart`
   membuat SEMUA import berikutnya lolos padahal tidak dipakai.
   Perbaikan: reset per-target, DAN hanya terima member extension yang
   namanya DIMILIKI satu target saja (`label` ada di 4 extension, jadi tidak
   boleh jadi bukti pakai).

## 8. Cek `FIELD-HILANG` — bug yang HANYA ketahuan saat CI compile

```dart
const _Chip({required this.selected});   // <-- dipanggil
final String label;                      // field `selected` TIDAK ditulis
... color: selected ? warna : card        // <-- dipakai
```

Hasil CI: 4 baris `The getter 'selected' isn't defined`. Semua cek lama lolos
karena file-nya terjangkau, import-nya benar, dan identifier-nya ada.
`tool/check_dart.py` sekarang punya cek `FIELD-HILANG`: setiap `this.X` di
constructor harus punya deklarasi field/getter `X`.

Dua jebakan implementasi (langsung ketahuan saat fault injection):
- `: this.gagal(e)` di constructor **pENGALIHAN** bukan field. Hitung hanya
  `this.X` yang diakhiri `,` atau `)`.
- Tipe field boleh berisi kurung:
  `final void Function(Status baru)? onUbahStatus;` — pola deklarasi jangan
  menyaring kurung, kalau tidak field ini dilaporkan hilang (false positive).

## 9. Jebakan yang hampir kejadian

- IME menyisipkan huruf Mandarin/hangul ke komentar saat menulis cepat.
  `check_nonlatin.py` menangkapnya - jalankan setiap kali, bukan hanya
  sebelum commit besar.
- `replace()` massal menyisakan sisa bila tidak `assert old in s` DULU.
- Nama enum dari enum lain ikut ketik ulang (`KategoriAspirasi.Activity`).
  Perhatikan huruf besar-kecilnya.
