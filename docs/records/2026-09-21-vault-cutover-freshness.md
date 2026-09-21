# 2026-09-21 — Vault cutover + key-freshness rung

Status: landed. Scope: automation/ (free-commit surface), docs/project/reports.md redaction, docs/records.

## What happened

The 2026-09-20 secret-scrub left 26 plaintext API keys in two homeside
stores: `~/.config/plasma-workspace/env/env_vars.sh` (plasma login env)
and `~/.hngh-automation/unsloth.env` (systemd EnvironmentFile), plus ~25
keys resident in the systemd user-manager environment. This slice
completed the cutover to the 1Password vault `Hngh Secrets`
(id `v67lhabrzqb2yhcchddjjmojfu`, service-account gated).

## Cutover actions (operator-approved "Go")

- `env_vars.sh` rewritten to a stub: 26 secret exports removed; retained
  the 1Password bootstrap (`import-environment ONEPASSWORD_SERVICE_KEY`),
  `OP_SERVICE_ACCOUNT_TOKEN`, `HOMEBREW_NO_ANALYTICS=1`,
  `UNSLOTH_BASE_URL`. chmod 600.
- `systemctl --user unset-environment` for all 26 secret vars; only the
  intentional 1Password bootstrap token remains in the user manager.
- 14 systemd drop-ins (10 cadence + overnight/automation + night-agent/
  morning-report/security/credential-health) lost their vestigial
  `EnvironmentFile=-...unsloth.env` lines; daemon-reload done.
- `~/.hngh-automation/unsloth.env` deleted.
- Vault verified end-to-end: 27/27 items readable through the
  `automation/lib/opv` -> `cred_get` seam after renaming 9 titles that
  carried `(`/`)`/`/` (invalid in `op://` refs);
  `automation/lib/secrets.py` SECRET_ITEMS updated to match.
- New finding + redaction: `docs/project/reports.md:3912` (alert
  7796e3e3) embedded an 11-char prefix of the live ZHIPU_API_KEY
  (journal-harvest redaction failure post-scrub). Redacted at HEAD;
  rotation of that key remains an operator step (provider-side).

## Key inventory (2026-09-21, evidence in
`.agent-scratch/consider/key-inventory-2026-09-21.md`)

- Git history: HEAD (1053 MiB objects) and both backup bundles — zero
  current secret values, zero key-shaped patterns; only the known dead
  `ghp_` survives inside the never-pushed 0600 bundles.
- Liveness: 13 live, 5 dead (ELEVENLABS, MOONSHOTAI, KIMI_AI,
  AGENT_MAIL, MINIMAX — all 401), 4 unresolved hosts (not verdicts),
  PYPI has no read endpoint. ZAI and Z_AI carry the same value
  (duplicate name, one real key).

## Freshness rung

`automation/lib/vault-freshness.py`: the vault is the rotation ledger —
operator rotates at the provider, updates the item, `updated_at` bumps.
The job reads titles + timestamps only (never values), flags items older
than the OLA (default 180d, `CREDENTIAL_VAULT_OLA_DAYS`), fail-closed on
op errors. Wired as section 8 of `automation/jobs/credential-health.sh`
(alert rows `vault-freshness`, identity-deduped, head-bounded).

## Follow-ups (operator)

1. Rotate the 5 dead keys + ZHIPU at the providers, then touch the vault
   items (updates `updated_at`).
2. `sudo journalctl --vacuum-size=128M` — user journal churns ~1.2GB/day;
   root cause is a `libredefender` crash-loop (missing clamav DB, 0s
   retry), not hngh; fix with `freshclam` or disable the unit.
3. hngh-n28 (OpenRouter key archaeology) still open.
