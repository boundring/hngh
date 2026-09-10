# hngh-automation

Recurring, **local-model** research pings, security checks, and morning digests.
Dogfoods Hngh: every job records activity through the Hngh CLI. Zero API cost —
all summarization runs on local models (Unsloth → Ollama → archive-only).

## What runs where

| Unit | Trigger | Job |
|------|---------|-----|
| `hngh-cadence-{1m,5m,10m,30m,hour,day,week,month}` | per-tier `OnCalendar` (see `systemd/`) | `jobs/cadence-tick.sh` → every `cadence/<tier>/*.sh` drop-in |
| `hngh-dashboard`   | always (`Restart=on-failure`)  | `python3 -m http.server 8890`        |
| `hngh-automation`  | every hour (`*:00`)            | `jobs/ping-hourly.sh`                |
| `hngh-security`    | every 4h (`00,04,08,12,16,20`) | `jobs/security-check.sh`             |
| `hngh-morning`     | 06:00 07:00 08:00 09:00        | `jobs/morning-digest.sh`             |
| `hngh-night-agent` / `hngh-night-research` / `hngh-morning-report` / `hngh-model-bench` / `hngh-autonomy` / `hngh-credential-health` | nightly / 23:40 / 07:30 / 01:10 / hourly / hourly | see `systemd/*.service` |

## Model chain (`lib/model.sh`)

1. **Unsloth** `MODEL` (default `unsloth/Qwen3.8-27B-GGUF`) — auto-refreshes the
   single-use token pair on HTTP 401 via `POST /api/auth/refresh`. When the model
   answers HTTP 200 but returns empty `content` (the reasoning stage ate the budget),
   `model.sh` retries once with `max_tokens*8` and `enable_thinking:false`, then falls
   back to `reasoning_content` extraction. Verified 2026-08-24: the retry path lands a
   real tiered summary on the full multi-source prompt in ~45s.
2. **Unsloth fallback** `UNSLOTH_FALLBACK_MODEL` (default `unsloth/Qwen-AgentWorld-35B-A3B-GGUF`).
3. **Ollama** `OLLAMA_MODEL` (default `hf.co/unsloth/gemma-4-12B-it-QAT-GGUF:UD-Q4_K_XL`) —
   `stream:false`, `$MODEL_TIMEOUT` for cold 12B load.
4. **Archive-only**: no model reachable → raw prompt saved to `archive/`, job still
   exits 0 and breadcrumbs. Fail-closed.

`MODEL_MAX_TOKENS` default 1024; the empty-content retry multiplies by 8 (floor 512).

## Layout

```
config.env        all knobs, overridable per-run via env
lib/              common.sh (prompt builder, dashboard), model.sh, sources.sh,
                  breadcrumbs.sh, hngh-record.sh
jobs/             ping-hourly.sh, security-check.sh, morning-digest.sh
dashboard/        index.html + data.json (generated — the ONLY dynamic file)
snapshots/        raw source captures (gitignored)
digest/           <date>.md (hourly) + MORNING-<date>.md (compiled)
archive/          raw prompts captured only when the model chain is down
STATE.md          breadcrumbs: ISO ts | job | event | detail
systemd/          hngh-{automation,security,morning}.{service,timer} + hngh-dashboard.service
Makefile          smoke / enable / disable / status
```

## Operations

- **Enable** (after smoke review): `make enable` → user timers + dashboard.
- **Disable**: `make disable`. Status: `make status`.
- **Dashboard**: `0.0.0.0:8890` (phone on LAN: `http://192.168.0.186:8890`).
  To change port: edit `DASHBOARD_PORT` in `config.env` AND the unit.
- **Breadcrumbs**: `STATE.md`, one row per event.
- **Secrets**: never in this repo — `~/.hngh-automation/unsloth.token` +
  `unsloth.refresh`, mode 600. Refresh is automatic; if it fails the operator
  must drop a fresh pair (tokens are single-use).
- **Dogfooding**: each job creates a run via `scripts/hngh create-run <mission> operator
  loadout-route-label=automation …` then `close-run <run> cancelled` in a FRESH store
  subdir under `~/.hngh-automation/store/` (hngh identifiers are per-process and start
  at `run-1`, so a shared store would collide). Hngh refusals (exit 1) are breadcrumbed
  as data, never failures. The Hngh repo is never modified by this harness (only `git fetch`).

## Run it live (the honest stranger path)

```
git clone <this repo> && cd hngh/automation
bash bootstrap.sh          # validates prerequisites; stages config/machine.env
make test                  # hermetic automation suite (no network, no secrets)
cd .. && make test         # kernel suite (2855 checks; sbcl — bootstrap checks for it)
```

`bootstrap.sh --check` validates only; `bootstrap.sh --install` installs missing
prerequisites via the system package manager only (never `curl | bash` of a
third-party script). The full environment contract — every variable name, its
consumer, required-vs-optional, and where to obtain it — is `env.example`.

What still needs a human (the machine tier, not the kernel):

- **Machine profile**: edit `config/machine.env` (deck tailnet IP, tailnet
  name, dashboard bind) — host identity is deliberately gitignored.
- **Secrets**: the documented path is the 1Password service account interface
  (`docs/records/2026-09-09-1password-service-account-interface.md`); or place
  token/key files by hand per `env.example` (`~/.hngh-automation/`,
  `~/.config/hngh/`). Declare `ONEPASSWORD_SERVICE_KEY` outside the repo and
  `systemctl --user import-environment ONEPASSWORD_SERVICE_KEY` at login.
- **systemd units**: review a `make smoke` run, then `make enable` (user
  timers + dashboard). The units still carry absolute paths (see below).
- **Dashboard bind / deck endpoints**: defaults in `config.env` +
  `cadence-params.tsv`; override via `config/machine.env` or the env vars in
  `env.example`.

Without the human steps the tier stays dormant by design: jobs fail closed,
quota legs skip themselves, notifications never fire, and `make test` still
proves the code.

## Known remaining hardcoded paths (follow-up sweep)

Peer-review finding 1 counted ~18 user-home-style paths baked into job code.
`06-remote-posture.sh`'s deck IP now resolves from `config/machine.env`; the
rest, for a later slice (env twins already exist where noted):

- `jobs/agent-supervision.py:53`, `jobs/dashboard-self-review.py:44`,
  `jobs/research-feed.py:34`, `jobs/system-feed.py:32`,
  `jobs/agent-watchdog.sh:27`, `jobs/oversight-tick.sh:24`,
  `jobs/system-awareness.sh:22`, `cadence/day/01-lesson-harvest.sh:27` —
  `HNGH_REPO`/kernel default `/home/bricker/Projects/etc/hngh`.
- `scripts/hngh-omp-update.sh:7,11` — `OMP` binary and `cd /home/bricker`.
- `scripts/night-session.sh:40` — `OMP_BIN` default `~/.bun/bin/omp`.
- `systemd/*.service` — absolute `ExecStart`/`WorkingDirectory` paths.
- `cadence-params.tsv` `deck-model-endpoint` row — the deck IP again (env
  `DECK_URL` overrides it today).

## Fail-closed contract

Every job exits 0 on any expected condition (model down, fetch failed, nothing
new, upstream unchanged) and writes breadcrumbs. Nonzero exit = real bug. The
dashboard always shows the last known state rather than nothing.

## Operator notifications

Email is the primary notification channel (procedural, no browser needed).
To enable, place an INI at `~/.hngh-automation/notify-email.conf` (chmod 600 —
the scripts refuse anything looser; they never create or edit it):

```
[smtp]
host = smtp.gmail.com
port = 587
user = you@example.com
pass = app-password          ; only needed for the non-1Password fallback
from = you@example.com
to = you@example.com
[1password]                  ; optional — preferred credential source
item = op://<vault>/<item>/<field>
[flags]
subject-prefix = [hngh]      ; optional
```

With a `[1password]` item, the password is read from 1Password at send
time (`op read`, requires a live `op` session) and never touches disk;
the conf `pass` is the fallback if the vault is locked. One command
stands the channel up from the vault:
`bash scripts/setup-notify-email.sh --from-1password "op://vault/item/password"`.

What gets emailed: **immediate-class alerts** (same text as the report-queue
row, best-effort — the row is the record) and the **daily digest**
(`cadence/day/09-email-digest.sh`). The importance rubric
(`classify_alert` in `scripts/notify-email.py`; first match wins, default
digest-only so noise never spams the inbox; `HNGH_NOTIFY_IMMEDIATE=0`
forces everything to digest-only):

| IMMEDIATE (emails right away) | DEFER-TO-DIGEST (daily email) |
|---|---|
| park/critical-class | routine gate flaps |
| service-ctl actions | ui-audit nits |
| unsloth serving down/recovered | repeat-crumbs |
| agent-stall | feed-validity one-steppers |
| git-push failures | anything unrecognized |
| credential/config touches | |
| ceremony/verdict failures | |
| kernel tree-skew | |
| budget cap exceeded | |

Alert rows ALWAYS land in the report-queue and the digest regardless of
class. The digest opens with a 3-line TL;DR (status / what changed /
spend + action needed), then operator items, progress, research, commits,
alerts, budget, footer — every long section carries a one-line summary,
every line is wrapped at 78 columns, and the composer redacts anything
matching the conf password (credentials-posture §4). A daily QA beat
(`cadence/day/13-email-qa.sh`) adversarially scores yesterday's digest
against a fixed rubric and files findings as one optimization row per
day (trend log: `logs/email-qa.log`). Without a config the
channel is dormant: the digest still lands in `logs/email-digest-<date>.md`.
Google-Messages browser relay remains a manual fallback channel.
## Restart resilience

Behavioral state (the fail-first speed ladders and the model demotion
counters) lives in `state/` — `state/failfirst/` and
`state/model-demote.tsv` — so it survives reboots: the system keeps
remembering its own degradations. `/tmp` is used only for true
short-lived serialization lockfiles (flock), never for state.
