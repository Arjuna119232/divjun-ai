---
name: verify-flutter-code-without-building
description: Cara memverifikasi kode Flutter dari HP tanpa Flutter lokal - workflow CI analyze-only, dan jebakan `dart fix --apply` yang MERUSAK sumber jadi tidak bisa di-parse (dibuktikan 16 Okt 2026).
---

# Verifikasi kode Flutter tanpa build (dari Termux)

Flutter tidak ada di Termux. Satu-satunya oracle kompilasi nyata = GitHub Actions.

## 1. Workflow analyze-only (2 menit, tanpa APK)

```
gh workflow run build.yml --ref <branch> -f analyze-only=yes
gh run view <id> --json status,conclusion
gh run view <id> --log-failed | grep -E "error •|warning •"
```

- `analyze-only=yes` = `flutter analyze` blocking + checker statis, tanpa build.
- Push ke branch = build penuh. Setelah push, `gh run cancel <id>` yang
  `in_progress`, baru dispatch analyze-only.
- Rekomendasi lokal (`analyze-only=yes`, `release=no`) hanya_when perlu bukti
  kompilasi setelah batch perubahan besar, bukan tiap file.

## 2. ⛔⛔ JANGAN `dart fix --apply` DI CI (bukti, bukan teori)

16 Okt 2026, KUNBAR Connect. Step lama `dart fix --apply || true` di
`build.yml` **mengubah sumber jadi tidak bisa di-parse**:

```dart
// SEBELUM (benar)
const _FieldOjek({ ..., this.validator, this.onChanged, ... });

// SESUDAH dart fix --apply (rusak, tidak bisa di-compile)
}) : validator = null : onChanged;
```

Lint `avoid_init_to_null` menimpa parameter constructor optional dengan
initializer list. Gejalanya di analyze:

```
error • A function body must be provided
error • Const constructors can't have a body
error • The name 'onChanged' is already defined
```

Tiga hal yang membuatnya berbahaya:
1. `|| true` **menyembunyikan** step itu gagal.
2. `dart format` di step berikutnya juga gagal diam-diam (`|| true` lagi).
3. File di repo **tidak pernah berubah** — jadi kalau kamu Inspect lokal, file
   terlihat benar dan kamu tidak percaya kalau CI edit berkasnya.

**Aturan:** kalau analyze memakai `--no-fatal-infos`, `dart fix` sama sekali
tidak diperlukan (info tidak memblokir). Ganti dengan:

```yaml
- name: Dart fix (dry run, tidak mengubah berkas)
  run: dart fix --dry-run || true
- name: Dart format
  run: dart format lib/ tool/ || true
```

Kalau project memang butuh `dart fix`, jalankan **manual di satu commit**,
`git diff` periksa hasilnya, baru commit — jangan di pipeline.

## 3. Urutan error yang paling sering muncul di analyze saja

`const_eval_method_invocation` = daftar `const` yang memanggil method
(`Kelurahan.dari(...)`). Solusi: `final List<X> ...` (bukan `const`).

`undefined_operator` = daftar yang digabung dengan `+` untuk enum
(`Kategori.agenGas + Kategori.galonAir`). Enum tidak punya operator `+`.
Solusi: pisahkan dengan koma di dalam literal list.

`missing_required_argument` = widget layar punya parameter `required` yang
dipanggil dari router tanpa argumen.

`unused_element_parameter` = parameter opsional widget yang tidak pernah
diberikan pemanggil. Setelah refactor, **hapus parameternya** jangan
disembunyikan.

## 4. Periksa error di file yang tidak kamu sentuh

Analyze bisa melaporkan error di file yang tidak kamu ubah karena
`dart fix`/version bump mengubahnya. Selalu baca **nama file + nomor baris**
dari log, bukan intuisi.
