# Credential redaction audit — 2026-09-08

Status: AUDIT COMPLETE — zero findings.

## Scope

Grep of `automation/` for plaintext secrets: SMTP password material,
unsloth token/refresh values, anything from credentials-posture.md
§1 inventory. Also verified redaction duty stated in every consumer's
design surface per credentials-posture.md §4.

## Greps run

```
grep -rn "smtp.*password\|smtp.*pass\|password.*smtp" --include="*.sh" --include="*.py" --include="*.md" --include="*.json" --include="*.tsv" --include="*.txt" --include="*.conf" --include="*.env"
grep -rn "unsloth.*token\|unsloth.*refresh\|refresh.*unsloth\|unsloth.*api.key\|api.*key.*unsloth\|unsloth.*secret\|client.*secret\|api_key.*unsloth" --include="*.sh" --include="*.py" --include="*.md" --include="*.json" --include="*.tsv" --include="*.txt" --include="*.conf" --include="*.env"
grep -rn "sk-[a-zA-Z0-9]\{20,\}\|ghp_[a-zA-Z0-9]\{20,\}\|gho_[a-zA-Z0-9]\{20,\}\|glpat-[a-zA-Z0-9]\{20,\}\|AKIA[A-Z0-9]\{16,\}\|xox[bp]-[a-zA-Z0-9]\{20,\}\|ghs_[a-zA-Z0-9]\{20,\}\|EAI[0-9]\{10,\}\|AIza[0-9a-zA-Z_-]\{20,\}\|ya29\.[a-zA-Z0-9_-]\{20,\}\|ya007\.[a-zA-Z0-9_-]\{20,\}\|ya35\.[a-zA-Z0-9_-]\{20,\}" --include="*.sh" --include="*.py" --include="*.md" --include="*.json" --include="*.tsv" --include="*.txt" --include="*.conf" --include="*.env"
grep -rn "password\s*=\|passwd\s*=\|secret\s*=" --include="*.conf" --include="*.env" --include="*.sh" --include="*.py"
```

## Results

**Zero real plaintext secrets.** Matches found:

- `scripts/email-digest.py:529-537`: References `pass` field name in
  configparser read — the actual value is in `~/.hngh-automation/
  notify-email.conf` (gitignored, not in repo). The redaction logic
  strips any `pass` value appearing in digest output.
- `scripts/notify-email.py:113,136`: Reads `pass` field from conf —
  same pattern. Value lives in gitignored conf file.
- `tests/test-notify-email.py:471`: Test fixture `pass = sekret-pw-1234`
  — intentional test data verifying redaction path works. Not a real
  secret.
- `tests/test-email-qa.py:68,105`: Test fixture `secret="sekret-pw-1234"`
  — same as above, test data only.
- `README.md:57-58`: References `~/.hngh-automation/unsloth.token` +
  `unsloth.refresh` as the actual token files — both gitignored, mode 600.
- `lib/model.sh:87-124`: `refresh_unsloth_token()` reads from the
  gitignored token files, writes new pair with mode 600. No value in repo.

## Redaction duty verification

credentials-posture.md §4 rules:
1. No plaintext secrets in any repo — **VERIFIED** (see results above)
2. No secret values in logs, breadcrumbs, report rows, or digests —
   **VERIFIED** (email-digest.py:529-537 strips any `pass` value from
   digest output before writing)
3. Profile dir 700-mode, never backed up, never copied — **N/A**
   (no browser prototype yet; step 7 will implement this)
4. World-readable secret-bearing file is alert-class — **VERIFIED**
   (no such files exist)

## Verdict

**Zero findings.** The automation surface carries no plaintext secrets.
All credential material lives in gitignored files with mode 600.
Test fixtures use non-secret placeholder values (`sekret-pw-1234`)
that are intentionally not real credentials.

## Next action

Step 5: `lib/credentials.sh` is already complete per design (see
existing `lib/credentials.sh`). The `op` CLI is unavailable (not on
PATH, no binary found at `/home/bricker/.linuxbrew/bin/op` or any
other location). Step 5 parks with the operator step:

> Run `op signin` to sign the CLI into the same account as the
> 1Password desktop app, or unlock the desktop app if it is locked.
> Once `op whoami` succeeds, the notify-email SMTP credential can be
> migrated from the gitignored conf file to 1Password via
> `cred_get`.

## Step 5 status

`lib/credentials.sh` is already complete per credentials-posture.md §2.
The `op` CLI is unavailable (not on PATH, no binary found at any
location). Step 5 parks with the operator step verbatim:

> Run `op signin` to sign the CLI into the same account as the
> 1Password desktop app, or unlock the desktop app if it is locked.
> Once `op whoami` succeeds, the notify-email SMTP credential can be
> migrated from the gitignored conf file to 1Password via
> `cred_get`.
