---
name: termux-cleanup-without-losing-projects
description: Reset zyvo/OpenCode usage limit to 0% and free gigabytes in Termux while provably NOT touching the user's APK and website projects. Covers the plan-mode permission trap, the exact files that hold the limit counter, and the delete-then-verify manifest. Use when the user says "hapus biar limit 0%", "bersihin Termux", "reset limit zyvo", "chat zyvo kepenuhan", or asks to free storage on their phone.
---

# Reset limit zyvo + bersihkan Termux tanpa merusak proyek

## ⚠️ Jebakan #1 (paling penting): PLAN MODE

Sesi zyvo bisa dibuka dalam **plan mode** — read-only. Sistem lalu **menolak
semua operasi tulis/hapus**, termasuk `rm`. Gejalanya: eksekusi berhenti dengan
pesan "mode has changed to plan / read-only" padahal rencana sudah disetujui.

**Aturan:** sebelumHENAP eksekusi apa pun, cek baris bawah TUI zyvo.
- `plan` → JANGAN eksekusi. Jelaskan ke user: tekan `Tab` (atau `shift+tab`)
  sampai mode berubah `build`, lalu balas "lanjut". Jangan bilang "sudah".
- `build` → boleh eksekusi.

Hapus dalam plan mode = bukan hanya gagal, tapi mengbohaykan user
("kenapa belum dihapus??"). Satu kalimat soal tombol sudah cukup.

## ⚠️ Jebakan #2: `unlink` aman walau proses jalan

Tidak perlu `kill` zyvo sebelum menghapus DB-nya — POSIX `unlink` langsung
memfreedomkan inode meski proses masih memegang file descriptor.
Ruang disk benar-benar baru terlihat setelah user menutup & membuka zyvo lagi.
`kill` zyvo dari dalam sesi = bunuh diri sendiri, dan `pkill -f zyvo`
juga bisa kena shell eksekusinya sendiri.

## File yang benar-benar menyimpan limit

Counter limit/context OpenCode ada di **database sesi**, bukan di config:

| File | Isi | Hapus? |
|---|---|---|
| `~/.local/share/zyvo/opencode.db` | session, message, part, token | **YA** — ini sumbernya |
| `~/.local/share/zyvo/opencode.db-shm` | shared memory | **YA** |
| `~/.local/share/zyvo/opencode.db-wal` | write-ahead log (besar!) | **YA** |
| `~/.local/share/zyvo/log/` | `opencode.log` | YA |
| `~/.local/share/zyvo/tool-output/` | output tool besar | YA |
| `~/.cache/zyvo/` | cache daftar model, unduh ulang sendiri | YA |
| `~/.config/zyvo/zyvo.json` | **model + limit tiap model** | **JANGAN** |
| `~/.config/zyvo/auth.json` | kredensial API | **JANGAN** |

Penting: `limit` yang ada di `zyvo.json` itu **limit token per model**
(context/output), BUKAN kuota pemakaian. Menghapus config justru mematikan
model premium user dan tidak akan reset limit.

`~/.local/share/zyvo/repos/` = tempat clone zyvo untuk update — jangan dihapus.

## Manifest: apa yang TIDAK boleh dihapus

Sebelum menghapus, **verifikasi eksistensi** lalu tampilkan ke user:

```bash
for d in /storage/emulated/0/Fonts/* ~/katarnolima* ~/divjun* ~/intelegen*; do
  printf "%-45s %s\n" "$d" "$(du -sh "$d" 2>/dev/null | cut -f1)"
done
ls ~/.config/zyvo/
```

Yang wajib selamat di Termux:
- `~/.config/zyvo/` seluruhnya (config model, kredensial, `AGENTS.md`, `skills/`, vault)
- `/storage/emulated/0/Fonts/<nama-project>` — proyek website/app user
- `~/<project>-update`, `~/<project>-backup/` — **terutama keystore/ke**
  (kehilangan = app tidak bisa di-update selamanya)
- `~/.cache/gh`, `~/.cache/pip` — cache tool, bukan data

⚠️ Folder besar hasil **decompile APKTool** sering ada di `$HOME` (`~/<app>_app`),
BUKAN di `$TMPDIR` — jadi tidak ikut terhapus. Jangan diam-diam menghapusnya;
tanyakan dulu kalau memang diminta.

## Urutan eksekusi

```bash
# 1. reset limit (tidak perlu stop proses)
rm -f ~/.local/share/zyvo/opencode.db ~/.local/share/zyvo/opencode.db-shm ~/.local/share/zyvo/opencode.db-wal
rm -rf ~/.local/share/zyvo/log ~/.local/share/zyvo/tool-output ~/.cache/zyvo

# 2. bersihkan tmp — hanya file kerja/probe, bukan folder zyvo
cd "$TMPDIR"
rm -rf <folder-probe> <file-probe>...

# 3. verifikasi: proyek masih ada?
ls ~/.config/zyvo/
du -sh <project>...
ls -la ~/keystore

# 4. laporan
df -h /data | tail -2   ; du -sh "$TMPDIR"
```

⚠️ `cd "$TMPDIR"` lalu `rm -rf` tanpa nama = menghapus SELURUH temp Termux.
Selalu sebutkan target secara eksplisit satu per satu.

## Setelah selesai

1. Laporkan angka nyata: berapa yang dihapus, `df -h`, `du -sh $TMPDIR`.
2. Ingatkan user **restart zyvo** — itulah yang membuat limit tampil 0% dan
   inode benar-benar dilepas.
3. Jujur soal konsekuensi: riwayat chat lama hilang permanen, tidak ada undo.
   Kalau user mungkin butuh, tawarkan backup **sebelum** menghapus.
4. Tulis satu note bertanggal ke vault `04 Sessions/` + tambah baris di
   `00 Home/Memory Index.md`, dan tambahkan catatan jebakan plan-mode ke
   `~/.config/zyvo/AGENTS.md` supaya sesi berikutnya tidak mengulang kesalahan.