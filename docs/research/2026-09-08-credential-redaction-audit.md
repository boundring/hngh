# Credential redaction audit — 2026-09-08

## Audit scope

Automation surface: `scripts/`, `jobs/`, `lib/`, `config.env`, dashboard files, reports.md, logs/, digests/, telemetry.

## Grep patterns

- `op://` references (1Password refs)
- `password|token|secret|apikey|api_key|api-key|pass` (credential keywords)
- Service endpoints: `googleapis\.com|gmail\.com|smtp\.|mailgun|sendgrid`
- Hardcoded token values: `= [a-zA-Z0-9]{16,}`

## Findings

**Zero plaintext secrets found.** All credentials are properly referenced via:
- Environment variables (`config.env` with `${VAR:-default}` semantics)
- Configuration files (mode 600, not committed)
- 1Password references (`op://<vault>/<item>/<field>` placeholders)
- Token files in `$HOME/.hngh-automation/` (not in repo)

## Notable patterns

1. **notify-email channel dormant** — no `notify-email.conf` exists (SMTP credential not yet loaded into 1Password)
2. **Token files external** — `unsloth.token`, `openrouter.token`, `kimi-ai-key` all stored in `$HOME/.hngh-automation/` (mode 600), never committed
3. **Redaction in place** — `scripts/email-digest.py` has `redact()` function that compare-and-redacts SMTP password from digests before output
4. **1Password integration prepared** — `lib/credentials.sh`, `scripts/setup-notify-email.sh`, `jobs/credential-health.sh` all reference `op://` refs but use placeholders, never real values

## Conclusion

**Audit passes.** No plaintext secrets in the automation surface. The credential posture is secure per `docs/design/credentials-posture.md §4`. The notify-email channel remains dormant until the operator loads SMTP credentials into 1Password.

## Verification

- `grep -rn 'op://' scripts/ jobs/ lib/` — only placeholder references
- `grep -rn 'password\|token\|secret' scripts/ jobs/ --include='*.py' --include='*.sh'` — only variable references, never literal values
- `cat config.env` — all secrets use `${VAR:-default}` pattern
- Dashboard files clean (no credential patterns)

---

**Status: PASS** — zero findings. No security incident.

## Step 5 outcome: parked

**Status: PARKED** — `op` CLI not available on this system.

The `op` binary is not installed (not at `~/.linuxbrew/bin/op`, not on PATH, not found via `which` or `find`). Step 5 (`lib/credentials.sh` consumer implementation for notify-email) requires the `op` CLI to be signed in and have a live session. Without it, the consumer cannot be implemented.

**Operator step required:** Install 1Password CLI (`op`) and sign in (`op signin`), then create the SMTP credential item (`op item create --vault=<vault> --title=<title> email <user> password <pass>`).

This matches the standing authorization in `docs/design/credentials-posture.md §5`: "the 1Password desktop app signed in and unlockable (biometric or passphrase), and the `op` CLI signed in to the same account."

