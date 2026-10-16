---
name: flutter-prefer-const-in-ci
description: Cara menyelesaikan hundreds warning prefer_const/unnecessary_const tanpa bolak-balik analyze dari HP - pakai `dart fix --apply` di GitHub Actions, lalu commit hasilnya. Termasuk jebakan IconData vs int dan const yang saling bertabrakan.
---

# Habiskan warning `prefer_const` tanpa bolak-balik analyze

Masalah nyata di KUNBAR Mitra (16 Okt 2026): satu layar baru menghasilkan 7 warning
`prefer_const_constructors` / `unnecessary_const`. Menghematnya manual butuh 3 putaran
analyze (tiap ±3 menit) karena dua aturan saling bertabrakan:
- `prefer_const_constructors` -> minta tambah `const`
- `unnecessary_const` -> minta buang `const` yang sudah otomatis dari induk

## Solusi: `dart fix --apply` di CI

Tambahkan job/satu langkah di workflow **sebelum** `flutter analyze`:

```yaml
      - run: dart fix --apply --code=prefer_const_constructors
      - run: dart fix --apply --code=prefer_const_literals_to_create_immutables
      - run: dart fix --apply --code=unnecessary_const
      - name: Commit hasil dart fix
        run: |
          if ! git diff --quiet; then
            git config user.name  "zyvo-ci[bot]"
            git config user.email "zyvo-ci@users.noreply.github.com"
            git add -A
            git commit -m "style: dart fix"
            git push
          fi
      - run: flutter analyze
```

`dart fix` menerapkan semuanya sekaligus, jadi tidak ada ping-pong manual.
Jangan lupa `git pull --rebase` dulu di awal job kalau branch dipakai bareng.

## Kalau tetap perlu manual
- `prefer_const_constructors` -> pakai `const` pada subtree yang **seluruhnya** konstan.
  Jangan pakai `const` kalau satu saja isinya runtime (mis. `Text(s.nama)`).
- `unnecessary_const` -> anak dari subtree yang sudah `const` tidak perlu `const` lagi.
  Hapus `const` di anak, biarkan induk yang mengaktifkan.
- `const_eval_property_access` (`Colors.grey.shade600` di dalam `const TextStyle`)
  -> ganti dengan literal `Color(0xFF757575)` atau buang `const`.

## Jebakan tipe yang bikin 10 error sekaligus
`Icons.xxx` bertipe **`IconData`**, bukan `int`. Kalau field model ditulis
`final int ikon;` lalu diisi `Icons.star_rounded`, analyzer melaporkan
`argument_type_not_assignable` di **semua** baris pemakaian. Fix di model, bukan
di tiap pemakaian. Import `package:flutter/material.dart` di file model itu.
