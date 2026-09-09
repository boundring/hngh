# Unsloth recovery note + local-lane resilience (9B admission rule)

Status: RESEARCH RECORD — 2026-09-03 staging plan step 4 (executed
2026-09-09). **No service was started, stopped, or restarted; no
systemd unit was edited; no package or credential state was touched.**
All evidence is read-only (`systemctl status/cat/show`, `curl` probes
of loopback ports, file reads), gathered 2026-09-09. Supersedes-nothing;
extends docs/research/2026-09-04-unsloth-launch-config-lane.md and the
2026-09-04 automation corrective slice (:8888 is the front door; the
:8080/llama-server recovery branch is already removed there).

## 1. What returns 127.0.0.1:8080? — nothing

- `curl http://127.0.0.1:8080/health` → connection refused
  (`curl: (7) Failed to connect ... Could not connect to server`), both
  bare and `/health`. `ss -ltn` shows no listener on :8080; listeners
  found on :8888 and :11434 only (plus the studio's inner llama-server
  on :33261, §2).
- Nothing in the automation chain consumes :8080 — confirmed by the
  2026-09-04 corrective slice (hngh-automation CHANGELOG 2026-09-04:
  ":8080 has been down in every probe and nothing consumes it"; the
  chain speaks `UNSLOTH_URL=http://127.0.0.1:8888`). :8080 is
  llama-server's default port and remains purely informational
  (jobs/service-state.py PORTS `8888,8080,11434`).
- Verdict: :8080 down is the steady state, not an outage. There is no
  recovery requirement for :8080 itself; the fleet's serving surface
  is :8888 (§2).

## 2. Observed unit states (2026-09-09, read-only)

All three units are **user units** (`systemctl --user`), not system
units — the plan's "active" observation resolves there:

- `"unsloth-studio.service"` — user unit, **enabled, active (running)**
  since 2026-09-08 18:08:35 EDT. ExecStart
  `~/.local/bin/unsloth studio`; `Wants=` unsloth-warm.service. It
  serves the OpenAI-shaped fleet front door on **:8888** (auth-gated:
  `/v1/models` without a Bearer key → 404 "Not authenticated"; key
  material in `~/.hermes/.env` per unsloth-warm.sh) plus a cloudflared
  tunnel. Unlike 2026-09-04, the unit NOW tracks the server (the
  out-of-unit relaunch noted then is gone).
- Inner model server (child of unsloth-studio): llama-server
  `~/.unsloth/llama.cpp/llama-server` hosting
  `Ornith-1.0-35B-UD-Q2_K_XL.gguf` (HF snapshot
  models--unsloth--Ornith-1.0-35B-GGUF) on **:33261** — `/health` 200,
  `/v1/models` lists `unsloth/Ornith-1.0-35B-GGUF`. Live arg line
  (captured from the process, read-only): `--port 33261 --parallel 4
  --flash-attn on --no-context-shift -c 221440 --alias
  unsloth/Ornith-1.0-35B-GGUF -ngl -1 --fit off --metrics
  --slot-save-path .../llama-slots --kv-unified --jinja --spec-default
  --chat-template-kwargs '{"enable_thinking": true,
  "preserve_thinking": false}' --mmproj <mmproj blob> --load-mode none`.
  This answers 2026-09-04's "not established" on studio launch
  internals: the 35B is served with `-ngl -1`, `-c 221440`,
  `--parallel 4`, `--kv-unified`, jinja chat template.
- `"unsloth-warm.service"` — user unit, **disabled, inactive** (last
  ran 2026-09-08 18:09:05, exit 0). Oneshot `~/.local/bin/unsloth-warm.sh`:
  waits for :8888 `/v1/models` (Bearer key from `~/.hermes/.env`,
  never printed), then warm-pins `unsloth/gemma-4-12b-it-qat-GGUF`
  with a 1-token completion. `Requires=`/`After=` unsloth-studio.
- `"llama-server.service"` — user unit
  (`/usr/lib/systemd/user/llama-server.service`), **disabled,
  inactive**; `ExecStart=/usr/bin/llama-server` with **no model
  arguments**; declares optional EnvironmentFile
  `~/.config/llama/server/environment.conf`, which **is absent**
  (`ls: cannot access ... No such file or directory`). A distinct
  system unit of the same name (`/usr/lib/systemd/system/`) is also
  disabled/inactive with `--models-dir "%D/llama/models"` pointing at
  a nonexistent `/var/lib/llama/models`. Neither instance can host
  anything as installed. Journal: no entries.
- `"ollama.service"` — **system** unit, enabled, **active (running)**
  since 2026-09-08 18:08:38 EDT, listening :11434 (`*:11434`). Models
  via `/api/tags`: `hf.co/unsloth/Ornith-1.0-9B-GGUF:latest` (6.6 GB)
  and `hf.co/unsloth/gemma-4-12B-it-qat-GGUF:UD-Q4_K_XL` (6.9 GB).

## 3. Operator start path for the 35B fleet

**Established and already live**: `systemctl --user start
unsloth-studio.service` (enabled; `Restart=on-failure`). It is running
now and serving the fleet: :8888 front door + the :33261 inner
llama-server with the full Ornith-1.0-35B arg line quoted in §2. The
operator-side warm-pin companion is `systemctl --user start
unsloth-warm.service` (disabled by choice — it is a oneshot that only
pins gemma-4-12b into the studio slots). Recovery of the fleet from a
cold host is therefore: boot → user units at `default.target`
(unsloth-studio is enabled and self-starts) → :8888 up. The
automation self-heal (cadence/day/11-service-recovery.sh +
scripts/service-ctl.sh) already covers the degraded case by starting
`"unsloth-studio.service"` when :8888 is down while the unit is
inactive.

**Plain llama-server on :8080 — NOT ESTABLISHED as a unit path.** Both
llama-server.service instances lack model arguments and their config
slots are absent/empty. The 2026-09-04 record (§4 there) already
inventories the env-var route (`LLAMA_ARG_MODEL`, `LLAMA_ARG_PORT`,
... into `~/.config/llama/server/environment.conf`, zero unit edits);
what remains open is the VRAM-sized `LLAMA_ARG_CTX_SIZE` and the
consumer migration off the :8888 token-pair API — both explicitly out
of scope here. If the operator wants :8080, that lane is the
config-manager backlog row, not a recovery action. Any systemd unit
edit stays critical-class and parked (staging plan boundary).

## 4. Delegated-lane admission rule for the Ornith-1.0-9B (:11434)

Ollama already holds `hf.co/unsloth/Ornith-1.0-9B-GGUF:latest` and can
host it on demand (`/api/chat`, no new unit, no new service). Whether
the bench probe recalibration (step 2) admits it as a delegated-lane
gate is a separate question — the single-day evidence is weak:

- 2026-09-01: 5/5, 2026-09-02: 5/5, 2026-09-03: **3/5** (stats/
  model-bench-2026-09-0{1,2,3}.jsonl as quoted by docs/research/
  2026-09-03-bench-probe-calibration.md §"per-day"; the raw 09-01..03
  jsonl files have since rotated out of automation/stats/ (only
  model-bench-2026-09-08/09.jsonl remain on disk), so the surviving
  evidence is the step-2 doc plus docs/records/2026-09-03-
  capabilities-direction.md). Later rows corroborate: 5/5 on 09-08
  and 09-09 (calibration doc §"bench history"). The 09-03 drop
  coincides with the p1_reader judge-signature question (step 2 doc).

**Proposed multi-day admission rule (design, not executed):** admit
the 9B lane only on a **3-day rolling window where every day scores ≥
4/5 and the window total ≥ 13/15** — i.e. no single day below 4/5 and
at most two dropped points across the window. A window containing any
day < 4/5 (as today: 3/5 on 09-03) fails admission; the model may be
re-probed on a fresh 3-day window after the p1_reader recalibration
verdict lands, since a judge fix can flip 09-03-class days without
any model change. Rationale: Ornith-1.0-9B is the weakest candidate
model on the bench, so its bar is "demonstrated stability across
days", not "one good day"; this mirrors the existing weak-gate
caution in the quarterly re-bench backlog row (over-fitting to
single-run scores). The rule is stated here for the operator/deck to
apply at probe-recalibration time; this step runs no probe.

## 5. Explicit no-action statement

**No service was started, stopped, or restarted by this step.** No
systemd unit (user or system) was edited, created, enabled, or
disabled. No provider/credential configuration or secret file was
modified (`~/.hermes/.env` was never read beyond existence being
implied by unsloth-warm.sh's source, which was read instead). The
only probes issued were read-only HTTP GETs to loopback ports
(:8080, :8888, :33261, :11434 — the latter two's `/v1/models`) and
`systemctl status/cat/show`. The :8080 re-host lane and any systemd
edit remain critical-class and parked for the operator.

## 6. Sources

- `systemctl status/cat/show` for `llama-server.service` (system +
  user instances), `unsloth-studio.service`, `unsloth-warm.service`
  (user units), `ollama.service` (system unit) — 2026-09-09.
- `~/.config/systemd/user/unsloth-studio.service`,
  `~/.config/systemd/user/unsloth-warm.service`,
  `~/.local/bin/unsloth-warm.sh`, `/usr/lib/systemd/user/llama-server.service`,
  `/usr/lib/systemd/system/llama-server.service` (file reads).
- Loopback probes 2026-09-09: :8080 refused; :8888 `/health` 404,
  `/v1/models` 401-auth; :33261 `/health` 200, `/v1/models` lists the
  35B; :11434 `/api/tags` lists Ornith-1.0-9B + gemma-4-12B.
- docs/research/2026-09-04-unsloth-launch-config-lane.md (prior
  record: env-var launch inventory, API-shape mismatch, :8888 front
  door).
- hngh-automation CHANGELOG 2026-09-04 + jobs/service-state.py +
  cadence/day/11-service-recovery.sh (corrective slice; :8080 branch
  removed).
- Bench history: docs/research/2026-09-03-bench-probe-calibration.md
  (per-day Ornith-1.0-9B totals quoted in §4; raw 09-01..03 jsonl
  rotated out, 09-08/09 files on disk in automation/stats/).
