---
category: secrets
persona: The Keyholder
status: seed
---

# Secrets — what hngh runs today

hngh separates secrets from data at the filesystem level: `~/.hngh/` is userspace data, `~/.hngh-automation/` holds secrets and kernel run stores — "two homes, never mixed" (README.md:52-53; GOVERNANCE.md:92-95). The single secret source is a **1Password service account**: headless auth via `OP_SERVICE_ACCOUNT_TOKEN` (mapped from the operator-declared `ONEPASSWORD_SERVICE_KEY` at one shared seam, `automation/lib/credentials.sh`), and the probe rule is `op account list`, never `op whoami` (whoami misreports under app integration) (AGENTS.md:50-56). Agent `op` usage goes ONLY through the service account; an absent token fails soft (breadcrumb + report), never an interactive prompt (.omp/agents/hngh-executor.md:10-13). `lib/credentials.sh` exposes `cred_get REF` (`op read`, 45s cap) with fail-closed nonzero and at most one breadcrumb per UTC day (automation/CHANGELOG.md:1885-1900).

A documented cutover purged 26 remaining plaintext API keys (`env_vars.sh`, `unsloth.env`, systemd user environment, 14 vestigial `EnvironmentFile` drop-ins) into vault `Hngh Secrets`, read on demand through `automation/lib/opv`/`automation/lib/secrets.py` — 27/27 reads verified — and fixed an 11-char `ZHIPU_API_KEY` prefix that a journal-harvest leak had embedded in `docs/project/reports.md` (automation/CHANGELOG.md:682-689). The notify-email lane stores an `op://` item reference instead of the raw SMTP password (password read at send time, never touches disk; automation/CHANGELOG.md:1345-1354).

**Redaction is single-sourced**: `automation/lib/scrub.py` is the ONE token family (home/Users/root/tmp bare or segmented, scheme-relative `//host/home/`, tilde rendering, credential-URL userinfo), with `scrub.sh` as shell wrapper and parity tests on both sides (automation/CHANGELOG.md:1045-1055,912-916). Fix-at-writer beats fix-at-reader everywhere: research-beat disposition columns, digest copies, and notify-email subjects scrub before write/send (automation/CHANGELOG.md:727-731,762-766). The kernel side has its own boundary backstop: `scripts/report-queue` rewrites machine-local paths and URL userinfo at the argument boundary BEFORE the dedup lookup, so the ledger's git-tracked public rows never carry raw paths (scripts/report-queue:98-121,154-169,366-379). Rotation is vault-as-ledger: `jobs/credential-health.sh:258-261` treats each vault item's `updated_at` as the rotate date (titles + timestamps only, never values).

## Open questions for web research

1. Service-account token scoping and rotation for headless automation — least-privilege patterns for secret-manager machine identities.
2. Writer-side vs reader-side redaction: what do secret-scanning systems say about the fix-at-writer doctrine and residual leak classes?
3. Vault-timestamp-as-rotation-ledger staleness detection — precedent for freshness rungs over secret managers.
4. Data/secret home-directory splits in single-user automation boxes — prior art for classification-by-path.
5. Sudoers exact-command delegation review tooling (validating grants inside root-owned scripts rather than in sudoers).

## Candidate external systems to survey

- 1Password service accounts + `op` CLI
- HashiCorp Vault
- SOPS (Mozilla)
- Infisical
- pass / age (file-based baseline)
