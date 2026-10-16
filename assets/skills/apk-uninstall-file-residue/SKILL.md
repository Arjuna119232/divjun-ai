# APK uninstall — file residue outside app-scoped storage

## The rule
Android uninstall deletes ONLY:
- `/data/data/<pkg>/` (internal app data)
- `/storage/Android/data/<pkg>/` (app-scoped external)
- `/sdcard/Android/media/<pkg>/`

It deletes **NOTHING** else. Anything the app wrote to an absolute path
outside those directories survives forever.

**So you cannot answer "is anything left?" from the manifest. You must read
the source.** `packageName` tells you nothing; `"/data/local/..."` and
`"/sdcard/Foo"` in code tell you everything.

## Method (10 min, phone-only, no root needed)
```bash
git clone --depth 1 https://github.com/OWNER/REPO
cd REPO
# 1. every absolute path the app hardcodes
grep -rhoE '"/(data|storage|sdcard|system|mnt|opt|usr/local)[^"]*"' \
  --include=*.java --include=*.sh --include=*.c --include=*.xml .
# 2. same but count/sort so you see the tree, not one-offs
grep -rhoE '"/(data|storage|sdcard|system)[^"]*"' --include=*.java . | sort -u
# 3. where the rootfs/engine actually lives (the big residue)
grep -rn 'mount\|chroot' --include=*.sh app/src/main/assets/ | head -30
```
Classify every hit into: app-private (dies) · shared-storage (survives, user
can delete) · system dir (survives, needs root to delete) · mount point
(survives in RAM until reboot).

## Case worked: StrykerOSS (`com.zalexdev.stryker`)
| Path | Fate on uninstall |
|---|---|
| `/data/data/com.zalexdev.stryker/` (chroot tarball, reports/, `rootless/`) | deleted |
| **`/data/local/stryker/release`** — the whole Debian arm64 chroot | **SURVIVES** |
| **`/sdcard/Stryker`** (`/storage/emulated/0/Stryker`) — exploits/, wordlists/, `saved_networks.csv` | **SURVIVES** |
| kernel bind mounts under the chroot | survive until reboot |

Read from source: `app/src/main/assets/bootroot` (`f_mount_sdcard`, mount lines)
and the `/data/local/stryker` literals across `app/src/main/java/...`.

**Safety finding worth relaying:** older Stryker bound the *entire* `/sdcard`
into the chroot; a stray `rm -rf` inside it could wipe the user's whole
internal storage. They scoped the bind to `/sdcard/Stryker` only
(`bootroot:36-41`). Real blast-radius lesson — always scope bind mounts.

## Cleanup after uninstall
```bash
# shared storage — no root needed
rm -rf /storage/emulated/0/Stryker
# system dir — root only (Magisk/KernelSU). No su on the device? It was never created.
su -c 'umount -R /data/local/stryker 2>/dev/null; rm -rf /data/local/stryker'
reboot   # clears leftover bind mounts
```

## Pitfalls
- **`Android/data` is different from plain `/sdcard/Foo`.** Only the former is
  app-scoped. `/sdcard/Stryker` is invisible to the uninstaller.
- **A mounted chroot outlives the app process.** Uninstall while mounted →
  bind mounts can linger in the kernel until reboot.
- **Without root the engine may never have run**, so a big `/data/local`
  residue may not exist at all — check before promising a cleanup problem.
- ⛔ **NEVER truncate an evidence scan.** `ls | grep | head -10` hides whatever
  sorts after the cut — a 90 MB installer was missed exactly this way. The
  final sweep must be `find <root> -iname "*<pattern>*"`, filtering with
  `grep -v` (exclude) and never with `head` (truncate). Re-scan with a
  *different command* before declaring a device clean.
- **Verify a file is what you think before `rm`.** With no `aapt`, `unzip -l
  <apk> | head` exposing asset names (`assets/bootroot`, `assets/bin/stryker-ch`)
  is proof enough.
- **`df` on Android `/storage` is FUSE and lags** seconds behind a delete —
  `sync; sleep 2` before quoting a delta, or it looks like nothing was freed.