# Credentials posture — 1Password as the operator-directed store

Status: DESIGN — operator-directed 2026-09-03 (directive 2: local
1Password is available for credential storage with an SDK and CLI
(`op`); Hngh should manage software like 1Password too, and use it for
credentials. Security is paramount). Nothing here is landed; this
contract names the seam, the migration order, and the redaction duty.

Cross-links: [service-management.md](service-management.md) (the
services whose configs must never carry secrets),
[ledger-and-records-spec.md](ledger-and-records-spec.md) (redaction at
write time).

## 1. Current inventory (paths and modes only — never contents)

Grounded by read-only `stat`/`ls` 2026-09-04:

| Path | Mode | Role |
|---|---|---|
| `~/.hngh-automation/unsloth.token` | 600 | Unsloth API bearer token (single-use pair member) |
| `~/.hngh-automation/unsloth.refresh` | 600 | refresh half of the pair; auto-refresh fires on 401, refresh is single-use |
| `~/.hngh-automation/reviewer-local.conf` | 644 | operator reviewer transport file (endpoint config) — mode 644 noted; whether it carries a secret value is **not established** (contents not read) |
| `~/.hngh-automation/notify-email.conf` | — | **absent at check time** — SMTP credentials not yet configured; the email channel is dormant by design (lib/notify-email.sh: config absent → one breadcrumb per UTC day, never an alert). When created it must be 600. |

Also referenced by design (not read): the kernel-side
`verify-candidate.py` credential-redaction pattern, inherited by the
telemetry store per ledger-and-records-spec §2.

## 2. The `op` CLI seam (`lib/credentials.sh` — spec)

A new hngh-automation library (implementation staged in the
capabilities plan) with exactly one consumer-visible function:

```
cred_get REF   # -> secret on stdout; "" (nonzero) on any failure
```

- **Lookup**: `op read "op://<vault>/<item>/<field>"` — the REF is the
  full `op://` URI, so the vault/item layout is data, not code.
- **Never echo**: values go to stdout for command substitution only;
  the library itself never logs, never `set -x`s, never writes values
  to temp files with broad modes (mktemp 600 or a pipe).
- **Session auth check**: before first use, `op whoami` (fallback
  `op account list`) — cheap, non-mutating. A locked or signed-out
  1Password must be detectable BEFORE a caller commits to a path.
- **Fail-closed to file fallback with a breadcrumb**: if `op` is
  unavailable, locked, or the item is missing, `cred_get` falls back
  to the existing file path (e.g. `~/.hngh-automation/unsloth.token`)
  and emits one breadcrumb per UTC day max
  (`credentials: 1password unavailable for <REF>; file fallback`) —
  the same dormancy pattern lib/notify-email.sh already uses.
  **The model chain must NEVER break because 1Password is locked**:
  lib/model.sh's unsloth → ollama → archive-only chain keeps working
  through the file pair until migration is complete and proven.
- **No new dependencies**: `op` is already installed
  (`~/.linuxbrew/bin/op`, version 2.32.1 — verified
  2026-09-04).

## 3. Migration order (blast radius ascending)

1. **notify-email password first** — lowest blast radius: the channel
   is currently dormant (config absent), so a failed fetch degrades to
   the existing dormant-breadcrumb behavior. Migrating it also
   exercises the seam against a credential whose loss costs nothing.
2. **reviewer-local.conf inspection** — read (operator-supervised or
   with the operator), determine whether it carries a secret value;
   if yes, migrate; if no, record that it is config-only.
3. **unsloth token pair LAST** — and only after the refresh path is
   proven against 1Password: the single-use refresh token has real
   failure modes (a wasted refresh attempt on a locked vault breaks
   the primary model lane until the next manual refresh). The file
   pair stays the fail-closed fallback even after migration, per §2.

Each migration step: `op item create` (operator-run or
operator-supervised — creating items writes to the operator's
vault), switch the consumer to `cred_get`, verify the consumer
end-to-end, THEN remove the plaintext file (the only deletion in the
whole posture, and it happens last per item).

## 4. Security rules (standing)

1. **No plaintext secrets in any repo** — hngh or hngh-automation;
   tracked files never carry secret values.
2. **No secret values in logs, breadcrumbs, report rows, or digests**
   — redaction duty on EVERY consumer: anything that might print a
   credential-bearing string (notify-email.py, breadcrumbs, digests,
   telemetry) redacts before write. A breadcrumb says a credential was
   fetched or missing, never what it is.
3. **Allowlisted unit files never carry secrets** —
   [service-management.md](service-management.md) §5's config lane is
   env-referencing (`EnvironmentFile=`), never inline values; a unit
   with a secret argument is refused at design review.
4. **Secrets never enter governance artifacts** — verdicts,
   certificates, evidence bundles redact paths-to-values to paths.
5. Modes: secret files 600; anything created by the seam is 600 or a
   pipe; world-readable secret-bearing files are an alert-class
   finding (reviewer-local.conf's 644 is flagged pending §3.2).

## 5. Operator setup remaining (the one human step)

Everything after this step is procedural: **the 1Password desktop app
signed in and unlockable (biometric or passphrase), and the `op` CLI
signed in to the same account.** `op --version` already succeeds
(2.32.1); whether the CLI session is live is checked at execution
time via `op whoami` — locked-vault behavior is exactly what §2's
fail-closed path absorbs. When the plan's migration step cannot
proceed because the CLI is signed out, it parks with the exact
operator step quoted ("run `op signin` / unlock the desktop app"),
never retries in a loop.

1Password the SOFTWARE joins the service-management posture like any
other installed software: kept updated, its availability recognized —
but it is never started by Hngh (it is operator-unlocked by
definition; an unlockable-by-machine password manager would defeat
itself).

## 6. SDK notes (CLI first, SDK later)

The 1Password **SDK** (in-process libraries per language) trades
setup for latency and a new language runtime dependency; the **CLI**
is a stable subprocess seam with zero new dependencies (already
installed). Decision: **CLI first** — `cred_get` is called a handful
of times per session (digest, model lane refresh), so subprocess
latency is irrelevant. SDK revisited only if in-process speed
measurably matters (a consumer on a hot loop). This follows the
ladder: already-installed dependency over a new runtime.

## 7. Sources and "not established" framing

- Operator direction 2026-09-03 (directive 2), recorded in
  [../records/2026-09-03-capabilities-direction.md](../records/2026-09-03-capabilities-direction.md).
- Verified 2026-09-04: `command -v op` →
  `~/.linuxbrew/bin/op` (linuxbrew prefix); `op --version` → 2.32.1;
  file paths + modes in §1; notify-email.conf absence; lib/notify-email.sh
  dormancy pattern (read).
- Not established: whether an `op` CLI session is currently signed in
  (checked at execution time, not at authoring); whether
  reviewer-local.conf carries a secret value; 1Password desktop app
  install/lock state; the SDK's exact language-runtime requirements
  (deliberately not researched — CLI first).
