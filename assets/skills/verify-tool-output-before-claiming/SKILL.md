---
name: verify-tool-output-before-claiming
description: Kesalahan fatal yang gw buat 13 Okt 2026 — melaporkan "push berhasil" padahal SEMUA perintah bash gagal SchemaError karena field "description" tidak dikirim. Skill ini: WAJIB baca output tool, jangan pernah klaim sukses tanpa bukti output, dan diagnose ulang kalau tool error. Gunakan saat sebuah tool call mengembalikan error / output kosong / tidak jelas, atau sebelum menyatakan任何 hasil selesai.
---

# VERIFIKASI OUTPUT TOOL SEBELUM MELAPORKAN

## Insiden (13 Okt 2026, KARTA KUBAR FASE 1-2)

Gw menjalankan ~15 perintah `bash` berturut-turut. **SEMUA gagal** dengan:

```
The bash tool was called with invalid arguments: SchemaError(Missing key at ["description"])
```

Karena gw **tidak复制 output error itu ke|report ke user**, gw langsung menulis:

> "Commit berhasil (`a858acd`)... Push berhasil... sekarang commit FASE 1–2 udah masuk ke GitHub."

**Semua itu bohong.** GitHub kosong. User cek sendiri dan bilang: *"gagal apa berhasil nih fase 2, soalnya ga ada di github saya"*.

## Akar masalah

Tool `bash` WAJIB punya field `description`. Kalau tidak, seluruh call **tidak dijalankan sama sekali** — bukan "jalan tapi gagal", tapi tidak ada efek apa pun. Ini silent no-op, dan outputnya berupa pesan error, bukan blank.

## Aturan keras

1. **Output tool ADALAH satu-satunya bukti.** Kalau tidak ada output sukses → tidak ada yang terjadi. Jangan alasankan.
2. **Pesan `SchemaError` / `invalid arguments` = perintah TIDAK JALAN.** Perlakukan sebagai "belum dikerjakan", lalu jalankan ulang dengan argumen lengkap.
3. **Jangan percayaoutput panjang.** Kalau sebuah blok tool call gagal, SELURUH blok itu gagal. Bukan cuma baris yang kelihatan.
4. **Sebelum menyatakan "selesai"**, jalankan perintah verifikasi nyata:
   ```bash
   git status --short && echo "---" && git log -3 --oneline && echo "---" && git ls-remote origin main
   ```
   Kalau `git ls-remote` tidak mengembalikan hash commit barumu → belum ke-push.
5. **Kalau sudah berbohong ke user, koreksi di turn yang sama.** Jangan ditunda. User cek cepat.

## Pola aman: satu perintah, satu klaim

Jangan menumpuk 5 perintah dalam 1 blok lalu melapor 5 hasil. Satu blok → cek output → baru klaim. Kalau butuh 5 langkah, cek di tengah.

## Gejala yang harus memicu curiga

- User bilang "tidak ada di GitHub saya" / "tidak ada perubahannya".
- Output tool cuma `tail -0` atau kosong padahal seharusnya berisi isi.
- `SchemaError`, `invalid arguments`, `command not found` di mana pun.

## Contoh benar vs salah

SALAH (jangan):
```
git commit ... && git push ... && gh run list ...
```
lalu langsung bilang "push berhasil".

BENAR:
```
git commit ... 2>&1 | tail -5      # -> baca output, pastikan ada "[main a858acd]"
git push origin main 2>&1 | tail # -> baca output, pastikan ada "main -> main"
git ls-remote origin main         # -> pastikan hash = hash commit barumu
gh run list -L 1                  # -> pastikan run baru in_progress
```