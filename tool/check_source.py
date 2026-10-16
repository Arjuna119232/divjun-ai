#!/usr/bin/env python3
"""Cek statis Dart untuk proyek Flutter yang TIDAK bisa dianalyze di HP.

Kenapa perlu: `flutter analyze` hanya jalan di CI, satu putaran 2-6 menit.
Skrip ini menangkap kelas bug yang paling mahal (file mati, import hilang,
kurung tidak berpasangan, karakter non-Latin dari IME) dalam <1 detik.

Exit 0 = aman, exit 1 = ada masalah (dipakai sebagai gerbang blocking di CI).
"""

from __future__ import annotations

import os
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

MASALAH: list[str] = []


def lapis(titel: str, isi: str) -> None:
    MASALAH.append(f"[{titel}] {isi}")


# ---------------------------------------------------------------- util

STRING_RE = re.compile(
    r"'''.*?'''|\"\"\".*?\"\"\"|r'[^']*'|r\"[^\"]*\"|'[^'\\\n]*'|\"[^\"\\\n]*\"",
    re.S,
)
COMMENT_RE = re.compile(r"//[^\n]*")


def bersihkan(kode: str, buang_komentar: bool = True) -> str:
    """Buang string & komentar supaya kurung di dalam teks tidak dihitung."""
    s = STRING_RE.sub("''", kode)
    if buang_komentar:
        s = COMMENT_RE.sub("", s)
    return s


def kurung_seimbang(kode: str) -> list[str]:
    """Hitung kurung dengan scanner yang paham string + interpolasi ${...}.

    JEBRAKAN (sudah kejadian): regex sederhana `re.sub` untuk string akan
    salah parse `'Zona $x (UTC${a ? '+' : ''})'` karena kutip di dalam `${}`
    memutus string lebih awal -> laporan BRACE palsu. Karena itu di sini
    dipakai scanner karakter, bukan regex.
    """
    pasangan = {")": "(", "]": "[", "}": "{"}
    tumpukan: list[tuple[str, int]] = []
    i = 0
    n = len(kode)
    # mode: 'kode' | 'str' | 'komentar' | 'blok'
    mode = "kode"
    str_delim = ""
    while i < n:
        c = kode[i]
        nxt = kode[i + 1] if i + 1 < n else ""
        if mode == "kode":
            if c == "/" and nxt == "/":
                mode = "komentar"
                i += 2
                continue
            if c == "/" and nxt == "*":
                mode = "blok"
                i += 2
                continue
            if c in "'\"":
                mode = "str"
                str_delim = c * 3 if kode[i : i + 3] == c * 3 else c
                i += len(str_delim)
                continue
            if c in "([{":
                tumpukan.append((c, i))
            elif c in ")]}":
                if not tumpukan or tumpukan[-1][0] != pasangan[c]:
                    return [f"kurung '{c}' tidak cocok di posisi ~{i}"]
                tumpukan.pop()
            i += 1
            continue
        if mode == "komentar":
            if c == "\n":
                mode = "kode"
            i += 1
            continue
        if mode == "blok":
            if c == "*" and nxt == "/":
                mode = "kode"
                i += 2
                continue
            i += 1
            continue
        # mode == str
        if kode[i : i + len(str_delim)] == str_delim:
            mode = "kode"
            i += len(str_delim)
            continue
        if c == "\\":
            i += 2
            continue
        # interpolasi ${ ... } -> kembali ke mode kode sampai kurung nutup
        if c == "$" and nxt == "{":
            depth = 1
            j = i + 2
            while j < n and depth > 0:
                if kode[j] == "{":
                    depth += 1
                elif kode[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            if j >= n:
                return ["interpolasi ${ tidak ditutup"]
            i = j + 1
            continue
        i += 1
    if tumpukan:
        return [f"kurung '{tumpukan[-1][0]}' belum ditutup"]
    return []


def deklarasi_ekspor(path: Path, kode_mentah: str) -> tuple[set[str], set[str]]:
    """Kembalikan (nama yang dideklarasi, nama yang di-export).

    CATATAN JEBRAKAN: `import 'x.dart'` itu STRING. Kalau regex dijalankan di
    kode yang string-nya sudah dihapus, import jadi `import ''` dan SETIAP file
    dilaporkan DEAD-FILE. Jadi deklarasi & import SELALU dibaca dari kode mentah.
    """
    kode = kode_mentah
    bersih = bersihkan(kode_mentah, buang_komentar=False)
    nama: set[str] = set()
    for m in re.finditer(
        r"^\s*(?:abstract\s+|sealed\s+|base\s+|final\s+|interface\s+|mixin\s+)*"
        r"(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_$][\w$]*)",
        bersih,
        re.M,
    ):
        nama.add(m.group(1))
    # top-level variable/function/getter
    for m in re.finditer(
        r"^(?:const|final|late\s+final)\s+[\w<>,?\s\.]+?\s([a-z_$][\w$]*)\s*[=;]",
        bersih,
        re.M,
    ):
        nama.add(m.group(1))
    for m in re.finditer(
        r"^(?:const|final|late\s+final)?\s*(?:[\w<>,?\s\.]+\s+)?"
        r"([a-z_$][\w$]*)\s*(?:<[^>]*>)?\s*\([^;]*\)\s*(?:async\s*)?[{=]",
        bersih,
        re.M,
    ):
        nama.add(m.group(1))
    # variabel lokal (final/var/late) - dipakai sebagai callable pun sah
    for m in re.finditer(
        r"\b(?:const|final|var|late\s+final|late)\s+"
        r"[\w<>,?\s\.]*?([a-z_$][\w$]*)\s*=",
        bersih,
        re.M,
    ):
        nama.add(m.group(1))
    # method abstrak di dalam class (akhiri titik koma, bukan '{')
    for m in re.finditer(
        r"^\s{2,}(?:[\w<>,?\s\.]+\s+)?([a-z_$][\w$]*)\s*\([^;{}]*\)\s*;",
        bersih,
        re.M,
    ):
        nama.add(m.group(1))
    ekspor: set[str] = set()
    for m in re.finditer(r"^export\s+'([^']+)'", kode, re.M):
        ekspor.add(m.group(1))
    return nama, ekspor


def import_relatif(kode_mentah: str) -> list[str]:
    # WAJIB kode mentah - import adalah string literal (lihat catatan di atas).
    return re.findall(r"^import\s+'([^']+)'", kode_mentah, re.M)


def main() -> int:
    if not LIB.exists():
        print("GAGAL: folder lib/ tidak ditemukan")
        return 1

    files = sorted(LIB.rglob("*.dart"))
    if not files:
        print("GAGAL: tidak ada file .dart di lib/")
        return 1

    kode_cache: dict[Path, str] = {f: f.read_text(encoding="utf-8") for f in files}
    provides: dict[Path, set[str]] = {}
    imports_of: dict[Path, list[str]] = {}
    exports_of: dict[Path, list[str]] = {}

    for f, kode in kode_cache.items():
        nama_d, ekspor = deklarasi_ekspor(f, kode)
        provides[f] = set(nama_d)
        imports_of[f] = import_relatif(kode)
        exports_of[f] = list(ekspor)

    def rel_path(target: str, asal: Path) -> Path | None:
        if target.startswith("dart:") or target.startswith("package:"):
            return None
        return (asal.parent / target).resolve()

    # provides transitif lewat export saja (BUKAN lewat import - itu buta).
    def semua_provides(f: Path, seen: set[Path] | None = None) -> set[str]:
        seen = seen or set()
        if f in seen:
            return set()
        seen.add(f)
        hasil = set(provides.get(f, set()))
        for e in exports_of.get(f, []):
            t = rel_path(e, f)
            if t and t in kode_cache:
                hasil |= semua_provides(t, seen)
        return hasil

    semua_provides_cache = {f: semua_provides(f) for f in files}

    # ---------------------------------------------------------------- 1. DEAD-FILE
    entry = LIB / "main.dart"
    hidup: set[Path] = set()
    stack = [entry]
    while stack:
        cur = stack.pop()
        if cur in hidup or cur not in kode_cache:
            continue
        hidup.add(cur)
        for target in imports_of.get(cur, []) + exports_of.get(cur, []):
            t = rel_path(target, cur)
            if t and t in kode_cache:
                stack.append(t)
    for f in files:
        if f not in hidup:
            lapis("DEAD-FILE", f"{f.relative_to(ROOT)} tidak terjangkau dari main.dart")

    # ---------------------------------------------------------------- 2. IMPORT-EXISTS
    for f, targets in imports_of.items():
        for t in targets:
            rp = rel_path(t, f)
            if rp and not rp.exists():
                lapis("IMPORT-EXISTS", f"{f.relative_to(ROOT)} -> {t} tidak ada")

    # ---------------------------------------------------------------- 3. MISSING-IMPORT
    for f, kode in kode_cache.items():
        bersih = bersihkan(kode)
        bersih = re.sub(r"LucideIcons\.\w+", "", bersih)
        # Nama yang dideklarasi di file ini sendiri selalu tersedia.
        provide = semua_provides_cache.get(f, set()) | provides.get(f, set())
        provide_global: set[str] = set()
        for t in imports_of.get(f, []):
            rp = rel_path(t, f)
            if rp and rp in kode_cache:
                provide_global |= semua_provides_cache.get(rp, set())
        # nama yang dipakai
        dipakai: set[str] = set()
        for m in re.finditer(r"(?<![\w.$])([A-Z][A-Za-z0-9_]{2,})\b", bersih):
            dipakai.add(m.group(1))
        KW_DART = {
            "if", "for", "while", "switch", "case", "return", "await",
            "yield", "assert", "catch", "do", "else", "throw", "try",
            "new", "in", "is", "as", "break", "continue", "rethrow",
        }
        for m in re.finditer(r"(?<![\w.$\"'])([a-z_$][\w$]*)\s*\(", bersih):
            if m.group(1) in KW_DART:
                continue
            dipakai.add(m.group(1))
        # hanya nama yang benar-benar dideklarasi di proyek yang dicek
        semua_nama = set()
        for s in semua_provides_cache.values():
            semua_nama |= s
        hilang = sorted(
            n for n in dipakai
            if n in semua_nama and n not in provide and n not in provide_global
        )
        if hilang:
            lapis(
                "MISSING-IMPORT",
                f"{f.relative_to(ROOT)} memakai {', '.join(hilang[:6])} "
                "tanpa import yang menyediakannya",
            )

    # ---------------------------------------------------------------- 4. EXT-HILANG
    for f, kode in kode_cache.items():
        bersih = bersihkan(kode)
        getter = re.findall(
            r"context\s*\.\s*(gelap|cs|teks|tokens|colorScheme|textTheme)",
            bersih,
        )
        if getter:
            ada = any(
                t.endswith("app_theme.dart") for t in imports_of.get(f, [])
            )
            if not ada:
                lapis(
                    "EXT-HILANG",
                    f"{f.relative_to(ROOT)} memakai context.{getter[0]} "
                    "tanpa import app_theme.dart",
                )

    # ---------------------------------------------------------------- 5. ICON-IMPORT
    for f, kode in kode_cache.items():
        if "LucideIcons." in bersihkan(kode):
            ada = any(
                "lucide_icons_flutter" in t for t in imports_of.get(f, [])
            )
            if not ada:
                lapis(
                    "ICON-IMPORT",
                    f"{f.relative_to(ROOT)} memakai LucideIcons tanpa import "
                    "lucide_icons_flutter",
                )

    # ---------------------------------------------------------------- 6. BRACE
    for f, kode in kode_cache.items():
        for pesan in kurung_seimbang(kode):
            lapis("BRACE", f"{f.relative_to(ROOT)}: {pesan}")

    # ---------------------------------------------------------------- 7. NON-LATIN
    for f, kode in kode_cache.items():
        for i, baris in enumerate(kode.split("\n"), 1):
            for ch in baris:
                if ord(ch) <= 0x2100:
                    continue
                nama = unicodedata.name(ch, "?")
                if any(k in nama for k in ("CJK", "HIRAGANA", "KATAKANA",
                                           "HANGUL", "FULLWIDTH", "IDEOGRAPH")):
                    lapis(
                        "NON-LATIN",
                        f"{f.relative_to(ROOT)}:{i} karakter '{ch}' "
                        f"({nama}) - sisa ketikan IME",
                    )

    # ---------------------------------------------------------------- 8. ASSET
    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    for m in re.finditer(r"^\s*-\s+(assets/[^\s#]+)\s*$", pubspec, re.M):
        p = ROOT / m.group(1).rstrip("/")
        if not p.exists():
            lapis("ASSET", f"pubspec: {m.group(1)} tidak ada di repo")
    for m in re.finditer(r"asset:\s+(assets/[^\s#]+)", pubspec):
        p = ROOT / m.group(1)
        if not p.exists():
            lapis("ASSET", f"pubspec: font {m.group(1)} tidak ada")

    # ---------------------------------------------------------------- 9. TEST ADA
    if not (ROOT / "test").exists():
        pass  # tidak wajib

    # ---------------------------------------------------------------- lapur
    total_baris = sum(len(k.split("\n")) for k in kode_cache.values())
    if MASALAH:
        print(f"GAGAL: {len(MASALAH)} masalah pada {len(files)} file Dart\n")
        for m in MASALAH:
            print("  " + m)
        print(f"\n({total_baris} baris diperiksa)")
        return 1

    print(
        f"OK: {len(files)} file Dart, {len(hidup)} hidup, "
        f"{total_baris} baris, 0 masalah."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
