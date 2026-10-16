---
name: import-project-zip-update
description: Import a project update delivered as a ZIP (e.g. katarnolima-2.3.4.zip in /storage/emulated/0/Fonts/) into the existing GitHub repo, verify, commit, push, and watch the cloud build to a signed APK download link. Use when the user says "ada file/folder untuk update APK ... belum saya ekstrak dan commit ke GitHub", hands over a version-named ZIP instead of git commits, or asks to release a new version from a packaged folder.
---

# Import project update from a ZIP → GitHub → signed APK

The user sometimes delivers project work as a **ZIP of the whole project**
rather than git commits. The ZIP root is a folder named after the version
(`katarnolima-2.3.4/`), sitting in `/storage/emulated/0/Fonts/` next to the
other projects. This skill merges it into the live GitHub repo and releases.

## 0. Locate and inspect BEFORE touching anything

```bash
ls -la /storage/emulated/0/Fonts/
unzip -l /storage/emulated/0/Fonts/katarnolima-2.3.4.zip | tail -20
```

Read the CHANGELOG from inside the ZIP — it is the real spec of what changed and
usually contains the version bump plus the reason. Also read `<project>/AGENTS.md`
(sacred, never overwrite).

## 1. Check what version is actually on GitHub

```bash
gh api repos/<user>/<repo>/contents/package.json --jq .content | base64 -d | grep version
```

Never assume. The ZIP version and the repo version must be compared first.

## 2. Clone to $HOME — NEVER merge inside /storage

`/storage/emulated/0` is FUSE: `git` refuses to discover a repo past the mount
boundary ("Stopping at filesystem boundary"), and `npm install` fails with
`EACCES` because shared storage has no symlink support.

```bash
cd ~ && rm -rf <project>-update
git clone https://github.com/<user>/<repo>.git <project>-update
cd <project>-update
```

## 3. Unzip, then merge — the two traps that eat this step

```bash
unzip -o /storage/emulated/0/Fonts/<project>-<version>.zip
cp -r <project>-<version>/* .        # NOT mv
cp -r <project>-<version>/.[^.]* . 2>/dev/null
rm -rf <project>-<version>
```

- **`mv` FAILS.** Every directory in the ZIP (`www`, `native`, `tests`,
  `scripts`, `docs`, `assets-source`) already exists in the clone and is
  non-empty, so `mv` aborts with `cannot overwrite: Directory not empty` and
  leaves a half-merged tree. Use `cp -r` to merge file-by-file.
- **`rsync` does not exist in Termux.** Do not try it.
- The dotfiles that matter: `.github/workflows/build-apk.yml`, `.gitignore`,
  `.editorconfig`. Without copying `.github`, the release never builds.

## 4. Verify with the project's OWN command

Read `<project>/AGENTS.md` for the verify command; do not guess a framework.

```bash
npm run check    # katarnolima = validate.py + node --test  (26 tests)
```

Untested work is not done. Report real output, including failures.

## 5. Secret scan the diff (non-negotiable before push)

```bash
git diff | grep -nEi "^\+.*(private[_-]?key|BEGIN RSA|api[_-]?key|secret|password|Bearer |ghp_|gsk_|AIza[0-9A-Za-z_-]{30,})"
grep -rniE "(private_key|client_email|BEGIN [A-Z ]*PRIVATE KEY|service_account)" . --exclude-dir=.git
```

Expect noise: Firebase Auth code (`sendPasswordResetEmail`, `type="password"`)
is *code*, not a credential. A real leak is a `service_account` JSON, a
`BEGIN PRIVATE KEY` block, or a `ghp_`/`gsk_` token.

## 6. Commit in the user's language — Latin script only

Never put native-script glyphs (Chinese/Japanese/Arabic/Bangla) in a commit
message; check with `git log -1 --format=%B | grep -nP "[^\x00-\x7F]"`.
Amend rather than leave a second "fix typo" commit.

Do not `git commit` unless the user asked — here they explicitly said they had
not committed yet, which is the ask.

## 7. Push, then WAIT for the cloud build

```bash
git push origin main
sleep 15 && gh run list --limit 3
gh run watch <run-id> --exit-status
gh run view <run-id> --json status,conclusion,jobs
```

The release tag and download links are created by the workflow itself — do not
hand-create tags. Fetch links with:

```bash
gh release view <tag> --json assets --jq '.assets[]|{name,size:.size,url:.url}'
```

Always hand the user the **direct download URLs**, never vague instructions.

## Pitfalls that cost real time

- Deprecation warnings from `ubuntu-latest`, `setup-java@v4`, `checkout@v4`
  are noise, not failures. Check `conclusion`, not the warning text.
- `gh run watch` prints the log tail and then returns; confirm the real result
  with `gh run view --json conclusion`.
- `.gitignore` in these projects excludes generated files — after copying, run
  `git status` and confirm the untracked list contains only intended new files
  (e.g. a new privacy-policy page), not build junk.
- Real-ad configs (`isTesting: false`) ship real ads. Flag it when the user
  tests on their own phone: set `true` temporarily in the native config.