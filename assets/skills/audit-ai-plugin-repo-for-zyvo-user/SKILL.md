---
name: audit-ai-plugin-repo-for-zyvo-user
description: Cara mengaudit dan menilai repo plugin/ekstensi AI pihak ketiga (Claude Code plugins, MCP registries, agent-skill bundles) dari Termux — cek apakah formatnya bisa dipakai zyvo/OpenCode, apakah gratis, dan mana yang aman. Gunakan saat user mengirim link repo plugin/MCP/skill lalu tanya "bagus, gratis, aman buat gue?" atau "ini bisa dipakai di zyvo?". Mencakup: bedakan format plugin vs SKILL.md, buktikan klaim "gratis" dari dokumentasi resmi (bukan README), inventaris MCP/hooks yang menjalankan perintah, dan ekstrak skill yang sidecar-free.
---

# Audit Repo Plugin/Agent-Ekosystem untuk User zyvo

Pakai skill ini setiap user mengirim URL repo "plugin", "MCP server",
"agent skills", atau "Claude Code plugins" lalu bertanya apakah itu
bagus/gratis/aman. Empat pertanyaan yang harus dijawab dengan BUKTI,
bukan READING README saja.

## 1. Clone dulu, jangan cuma baca halaman web

Repo skill saintifik bisa **500 MB** (gambar + data) padahal isinya cuma 35 MB.
Jangan clone penuh — pakai sparse:

```bash
cd /data/data/com.termux/files/usr/tmp/zyvo && rm -rf <nama>
# repo kecil: clone biasa
git clone --depth 1 --quiet https://github.com/<owner>/<repo>.git <nama>
# repo besar: clone sparse (hemat download)
git clone --depth 1 --filter=blob:none --sparse --quiet <url> <nama>
cd <nama> && git sparse-checkout set skills scripts --skip-checks
```

⛔ `--skip-checks` WAJIB: tanpa itu `git sparse-checkout set` gagal kalau ada
nama file (bukan direktori) di daftar path
(`fatal: 'AGENTS.md' is not a directory`).

Metadata cepat tanpa clone sama sekali:
```bash
curl -s -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<owner>/<repo>" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['stargazers_count'],d['forks_count'],d['size'],d['license'])"
```
`size` di API = KB repo penuh → itu yang menentukan perlu sparse atau tidak.
Daftar file tanpa clone: `https://api.github.com/repos/<owner>/<repo>/git/trees/main?recursive=1`
(perhatikan `truncated: false` — kalau `true`, hitungannya tidak valid).

`webfetch` ke halaman GitHub hanya memberi README + chrome UI yang
mengganggu. Clone/sparse memberi daftar file asli, `.mcp.json`, `hooks.json`,
dan `SKILL.md` yang bisa dihitung.

## 1b. Audit repo "Agent Skills standard" (bukan Claude Code plugin)

Repo seperti `K-Dense-AI/scientific-agent-skills` (51k star) memakai **open
Agent Skills standard** — `plugin.json` (skema agent-plugins.org) +
`skills/<nama>/SKILL.md`. Ini **BERBEDA** dari repo Claude Code plugin dan
justru **100% kompatibel dengan zyvo**:

- ✅ `SKILL.md` per skill, frontmatter hanya `name:` + `description:`
- ✅ nol `.mcp.json`, nol `hooks.json`, nol hook yang jalan otomatis
- ⛔ YANG MEMBUAT TIDAK GUNA: isi domain-nya. 177 skill bioinformatics /
  farmasi = 0 nilai untuk user yang bangun app. **Jangan** pasang semua:
  tiap skill di daftar zyvo = noise trigger + token context.
- Skor dependensi wajib dihitung per skill, bukan dibaca dari README:

```bash
python3 - <<'EOF'
import os,re
rows=[]
for d in sorted(os.listdir('skills')):
    p=os.path.join('skills',d,'SKILL.md')
    if not os.path.exists(p): continue
    t=open(p,encoding='utf-8',errors='replace').read()
    code=[f for dp,_,fn in os.walk(os.path.join('skills',d))
          for f in fn if f.endswith(('.py','.sh','.js','.ts'))]
    rows.append((d,len(code),
        bool(re.search(r'pip install|uv pip|conda install',t)),
        sorted(set(re.findall(r'\b[A-Z][A-Z0-9_]{3,}_(?:API_KEY|TOKEN)\b',t)))))
clean=[r for r in rows if r[1]==0 and not r[2] and not r[3]]
print("total",len(rows),"| BERSIH (cuma yang layak dipasang)",len(clean))
for r in clean: print(" ",r[0])
EOF
```
Pada repo 177 skill: 106 butuh `pip install` (multi-GB, gagal di Termux ARM),
30 butuh API key, **hanya 12 yang bersih** → itu angka yang determination,
bukan "51k star".

## 2. Empat pertanyaan wajib

### (a) Format — bisa dipakai zyvo/OpenCode?

| Format | Pembaca | Status untuk zyvo |
|---|---|---|
| `.claude-plugin/plugin.json` + `.mcp.json` + `hooks.json` | Claude Code | ❌ TIDAK bisa |
| `SKILL.md` dengan frontmatter `name:` + `description:` | zyvo **dan** Claude Code | ✅ BISA di-copy |
| `opencode.json` / `.opencode/` | OpenCode | ✅ BACA |
| `AGENTS.md` | zyvo | ✅ BACA |

Hitung skill yang kompatibel:

```bash
python3 - <<'EOF'
import os,re
for dp,dn,fn in os.walk('.'):
    if 'SKILL.md' in fn:
        p=os.path.join(dp,'SKILL.md')
        t=open(p,encoding='utf-8',errors='replace').read()
        m=re.match(r'---\n(.*?)\n---\n',t,re.S)
        if m and 'name:' in m.group(1) and 'description:' in m.group(1):
            sidecar=[f for f in os.listdir(dp) if f.endswith(('.py','.js','.ts','.sh'))]
            print(p, len(t)//1024, 'KB', sidecar or 'sidecar-free')
EOF
```

**`sidecar-free` = aman untuk disalin mentah ke `~/.config/zyvo/skills/`.**
Skill yang punya `.py`/`.sh` di sampingnya hampir selalu memanggil
`${CLAUDE_PLUGIN_ROOT}` atau `~/.claude/...` → tidak akan jalan di zyvo.

### (b) Gratis — buktikan dari dokumentasi resmi, bukan README

Untuk Claude Code, kutip verbatim dari
`https://docs.claude.com/en/docs/claude-code/setup` bagian "Authenticate":

> "Claude Code requires a Pro, Max, Team, Enterprise, or Console account.
> The free claude.ai plan does not include Claude Code access."

Perhatikan: **CLI-nya sendiri gratis diunduh, tapi aksesnya berbayar.**
Jangan sampai user mengira "gratis" karena repo-nya Apache-2.0.

### (c) Akses/ranah — 4 pertanyaan

1. Apakah user punya produk yang_plugins-nya tuju? (User zyvo tidak punya
   Claude Code; user punya APK Claude mod, itu produk berbeda.)
2. Apakah formatnya cocok dengan host-nya? (lihat tabel)
3. Apakah ada versi gratis? (buktikan dari docs, bukan tagline)
4. Kalau tidak cocok: **bisakah diekstrak bagiannya?** (mis. hanya SKILL.md)

### (d) Aman — inventaris SEMUA yang bisa mengeksekusi perintah

```bash
find . -name ".mcp.json" | while read f; do echo "### $f"; cat "$f"; done
find . -name "hooks.json" -o -name "hooks.jsonc" | while read f; do
  echo "### $f"; grep -oE '"(command|cmd)": *"[^"]+"' "$f"; done
grep -rnE "pip install|npm install|npx |uvx |curl |wget |docker run" --include="*.sh" --include="*.py" --include="*.json" .
```

Cari 4 hal spesifik:
1. **`npx -y` / `bun run`** → mengunduh & menjalankan kode pihak ketiga saat
   tool dipanggil. Ini bukan "install sekali", ini eksekusi runtime.
2. **`docker run`** → butuh Docker; di Termux tidak ada.
3. **`pip install` di dalam hook** → hook jalan otomatis tiap tool call.
4. **Skrip telemetri** → cari `TELEMETRY`, `DISABLE_TELEMETRY`,
   `DISABLE_TELEMETRY_DURING_BUILD`, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`,
   lalu `exit 0` saat ada env var itu = ada switch matinya.

Also read the repo's OWN warning — repo resmi sering jujur:
> "Anthropic does not control what MCP servers, files, or other software
> are included in plugins and cannot verify that they will work as intended
> or that they won't change."

**Hitung rasio first-party vs third-party dari `marketplace.json`:**
sebagian besar plugin enterprise (Salesforce, Airtable, Canva, BlackRock,
Carta) = 0 manfaat untuk user pribadi. Sebutkan angkanya, jangan hanya
"repo bagus".

## Jebakan

- ⛔ **"Repo resmi = aman untuk gue"** adalah non-sequitur. Resmi berarti
  ter-review untuk submitter-nya, bukan berarti cocok untuk device dan
  anggaran user.
- ⛔ **Apache-2.0 tidak sama dengan gratis dipakai.** Lisensi itu soal hak
  copier; biaya akses adalah hal yang sepenuhnya terpisah.
- ⛔ **Jangan rekomendasikan `npx -y <paket>@latest` dari HP** hanya
  karena "dipakai banyak orang". Cek dulu apakah paketnya jalan di ARM
  Android Termux.
- ⛔ **Skill yang_READM-nya masuk akal belum tentu jalan.** Selalu cek
  path yang_called-nya (`~/.claude/`, `${CLAUDE_PLUGIN_ROOT}`, `~/.codex/`)
  sebelum menawarkan install.

## Template jawaban

1. **Repo ini** — siapaMaintainer, lisensi, skala (star/entri), siapa
   sebenarnya di balik (first-party vs third-party).
2. **Untuk lu**: 3 alasan singkat berbasis bukti — format, harga, akses.
3. **Yang benar-benar bisa dipakai**: daftar file persis + alasan.
4. **Rekomendasi**: satu kalimat tegas. Kalau ada bagian yang bisa
   diselamatkan, sebutkan DAN tawarkan (**jangan langsung doing tanpa
   user bilang ya** untuk perubahan config).

## Setelah selesai

Simpan hasil ke vault `04 Sessions/` dengan tanggal, dan tambahkan satu
blok ringkas ke `AGENTS.md` (4-8 baris) supaya sesi berikutnya tidak
mengulang riset. alleged Hapus working copy di `$TMPDIR` kalau >50 MB.

## Kasus terverifikasi: `affaan-m/ECC` (17 Okt 2026)

Repo agent-harness (MIT, 282k star): 71 agents, 311 skills, 97 commands,
7 hooks, 68 scripts, 23 rules, AgentShield.

Perintah audit yang dipakai (semua dari Termux, `gh` sudah login):
```bash
gh api repos/OWNER/REPO/contents/skills --jq '.[]|select(.type=="dir")|.name'
gh api repos/OWNER/REPO/contents/skills/NAMA --jq '[.[]|.name]|join(",")'   # sidecar?
gh api repos/OWNER/REPO/contents/skills/NAMA/SKILL.md --jq '.content' | base64 -d | head -6
gh api repos/OWNER/REPO/contents/.mcp.json --jq '.content' | base64 -d
for d in hooks scripts agents commands rules; do gh api repos/OWNER/REPO/contents/$d --jq 'length'; done
gh api -X GET search/code -f q='repo:OWNER/REPO "ghp_"' --jq '.total_count'
```
Hasil: format `SKILL.md` **100% kompatibel** (frontmatter `name`/`description`/
`metadata`), skill terpilih single-file. Yang **tidak** bisa dipakai: hooks,
`.mcp.json`, AgentShield, `scripts/` (milik Claude Code). `npx <pkg> setup`
JANGAN dijalankan di HP - butuh Node 18+ dan menulis ke `~/.claude`/`~/.cursor`.

⚠️ Token palsu yang sering ketahuan: `ghp_` di dalam **regex** secret-scanner,
`sk-ant-...` di template docs. Selalu **buka barisnya** sebelum menyimpulkan
repo bocor rahasia (pelajaran yang sudah kejadian 2x di repo berbeda).

## Dua pertanyaan wajib sebelum menyarankan tool ke user

1. **"Gratis?"** - cek LICENSE via API, bukan README: `gh api repos/O/R/license`.
   Bedakan OSS gratis vs produk berbayar (mis. ECC MIT gratis, "ECC Pro"
   $19/seat/bulan hanya untuk private-repo hosted - opsional).
2. **"Bisa jalan di perangkat user?"** - cek `engines` (npm/PyPI), lalu cari
   masalah platform: `gh api -X GET search/code -f q='repo:O/R termux'`.
   Kalau repo punya seksi Termux/Android di TROUBLESHOOTING.md, **baca** - di
   situ biasanya ada gotcha nyata (di ECC: file hook gagal ter-copy di
   Android sehingga `plugins/lib/` kosong dan OpenCode gagal start).
   Dan cek ke mana installer menulis: kalau menulis ke `~/.opencode/` sedangkan
   tool user pakai `~/.config/<nama>/`, berarti installer itu untuk tool
   yang berbeda.
