# 2026-10-10 — omp zai 401s: login key exports silently failed; omp now self-heals

## Symptom

oh-my-pi (`omp`) sessions started failing with
`401 token expired or incorrect` on `zai/glm-5.3-flash` (every agent turn,
`~/.omp/logs/omp.2026-10-10.*.log`). Secondary: omp's unsloth provider
model discovery also 401'd against `http://127.0.0.1:8888/v1/models`.
jcode (via bili) kept working, which made the failure look provider-side.

## Root cause chain

1. `~/.config/plasma-workspace/env/env_vars.sh` exports vault-backed API
   keys at Plasma login (`eval secrets.py --exports`). This boot the
   vault reads failed: the login ran at 15:37:13, when link-level DHCP
   had just completed (15:37:00, DHCP-provided DNS 127.0.0.1 ignored by
   NetworkManager, Wi-Fi never activated) but upstream/DNS to
   api.1password.com was not yet usable — the operator confirmed the
   network was down at boot and returned later. Fail-soft per item meant
   the eval imported ZERO keys (breadcrumb
   `.cred-fallback-2026-10-10` at 15:37:13 + crumbs.db
   `credentials|fallback` entries). Exporter verified healthy once the
   network returned.
2. With no `Z_AI_API_KEY` in env, omp resolved the zai provider from its
   credential store `~/.omp/agent/agent.db` (`auth_credentials`, id=4,
   `credential_type=oauth`): an access token with an **empty refresh
   token** and sentinel expiry (`8640000000000000`) — structurally unable
   to refresh. z.ai rejects it: `401 token expired or incorrect`.
3. jcode unaffected because bili resolves keys itself at runtime via the
   service token (`JCODE_DEFERRED_AUTH_BOOTSTRAP=1`,
   `JCODE_OPENROUTER_ENV_FILE=zai.env`).
4. unsloth 401 is unrelated to expiry: the vault `UNSLOTH_API_KEY` is
   sent as Bearer, but unsloth-studio only accepts an empty Bearer or a
   key it issued (`Bearer bogus` -> 401; no header -> 200). Same family
   (env key delivered where the server rejects it), different mechanism.

Vault key verified good against `https://api.z.ai/api/coding/paas/v4`
(200 with `Z_AI_API_KEY` from `secret('Z_AI_API_KEY')`).

## Fix (jcode-style deferred auth for omp)

- `~/.local/bin/omp-env-rearm` — pulls the 7 keys omp consumes
  (Z_AI/ZAI/UNSLOTH/OPENROUTER/ANTHROPIC/OPENAI/GEMINI) from the Hngh
  Secrets vault via the existing `automation/lib/secrets.py` seam and
  writes `~/.config/omp/agent.env` (0600, `export KEY=value` lines).
  Falls back to reading the service token from
  `~/.hngh-automation/secrets/op-service-token` when the session lacks
  `OP_SERVICE_ACCOUNT_TOKEN` (SSH/cron contexts), so self-heal works
  anywhere the operator's account can read that file.
- `~/.local/bin/omp` — now a wrapper; real binary moved to
  `~/.local/bin/omp.bin`. Sources `agent.env` before exec, regenerating
  it when older than 24h; skips entirely if `Z_AI_API_KEY` already in
  env; `OMP_NO_REARM=1` bypass. All fail-soft: stale env file or
  inherited env still beats no start.
- `env_vars.sh` — added fire-and-forget `omp-env-rearm write &` after
  the login exports so even the first omp launch skips the vault read.

Verified: `omp --print --model zai/glm-5.3-flash` returns `OK` with no
key in the shell env, both with fresh and stale (regenerated) env file.

## Follow-ups

- RESOLVED (login export failure): a race between Plasma login and
  upstream network readiness. Boot 15:36:44, wired lease 15:37:00,
  vault reads 15:37:13 -> all failed (api.1password.com unreachable),
  fail-soft produced zero exports. Same signature on the Oct 4 boot
  (crumb 2026-10-05T03:20:19Z) — masked then because the zai OAuth blob
  still served requests until it expired today. The wrapper makes this
  non-fatal: it re-reads the vault on first omp launch, minutes later,
  when the network is up.
- DONE (stale OAuth blob cleanup): `omp auth-broker logout zai`
  disabled the dead credential (agent.db id=4, now marked
  `disabled_cause="logged out by user"`, row retained by omp's own
  logout semantics). Verified post-cleanup: omp still answers via the
  env-key path (`omp --print` -> OK). agent.db backed up to
  `~/.hngh-automation/backups/agent.db.backup-20261010-omp-zai-oauth-removal`
  before the logout.
