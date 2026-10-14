# 06 — Observability: feeds, ledgers, watchers

Doc suite v1.3, 2026-08-30 (revised after adversarial audit) · part of [README.md](../core/README-architecture.md). What the machine
records about itself, where it lands, how alerts behave, and what the
33h unattended window proved (including the 2026-08-30 fix set).

## 1. The state surfaces

| Surface | Path | Semantics |
|---|---|---|
| Breadcrumbs (append-only tick log) | `hngh-automation/STATE.md` — 4.1MB / 37,915 lines as of 2026-08-30, grows unboundedly, **(R3)** | every tick appends `{ts}|{job}|{event}|{detail}`; `¦` escapes pipes; attribution anchor |
| Report ledger (alerts + progress) | kernel `docs/project/reports.md` (+ `report-bodies/`) | append-only table, newest read first; 48h body prune; identity+window dedup with ×N occurrence markers |
| Alert bodies | `docs/project/report-bodies/` | 48h retention, archive, honest tracked-deletion alert |
| Day digests | `hngh-automation/digest/` | day narrative, REVIEW (fresh-eyes, findings + reviewed range, no prompt echo since 08-29), RESEARCH-BEAT per line, MORNING, BENCH |
| Dashboard feeds | `hngh-automation/dashboard/*.json` | readout (spine), schedule, research, sessions (observatory), operator-items, system, plans, time-ledger; all atomic-writer as of 2026-08-30 |
| Telemetry store | `dashboard/telemetry.db` (SQLite WAL) | capture-first events (`jobs/telemetry.py`); readers `jobs/telemetry-report.py` + session-cost capture landed 08-29 |
| Session transcripts | `~/.omp/agent/sessions/**.jsonl` | read-only inputs for sessions-feed + supervision |
| Plan records | kernel `docs/project/plans/*.plan.md` | front-matter status + step checkboxes are the execution record |

## 2. Feed topology

```mermaid
flowchart LR
  subgraph producers["producers (jobs/)"]
    OF["operator-items-feed.py"] --> OIJ[(operator-items.json)]
    SF[sessions-feed.py] --> SJ[(sessions.json)]
    RF[research-feed.py] --> RJ[(research.json)]
    PF[plan-feed.py] --> PLJ[(plans.json)]
    RD[cadence/30m/05-readout.sh + refresh-dashboard.sh readout section] --> ROJ[(readout.json)]
    RD2[refresh-dashboard.sh via update_dashboard (lib/common.sh)] --> DJ[(data.json)]
    SUP[agent-supervision.py] --> SUPJ[(agent-supervision-state.json)]
    TL[cadence/5m/00-time-ledger.sh] --> TLJ[(time-ledger.json)]
    TEL[telemetry.py] --> DB[(telemetry.db)]
  end
  DASH[dashboard-server :8890 + vanilla-JS views] --> OIJ & SJ & ROJ & DJ
  DSR[dash self-review + ui-audit] -.checks.-> OIJ & ROJ & DB
  OS[oversight-tick 5m] -->|tree-skew · loop · stale-store| RQ[report-queue → reports.md]
  AS[agent-supervision] --> RQ
```

Writer discipline (fixed 2026-08-30, commit `760adb5`): every JSON writer is
atomic — write `.tmp`, `mv` into place. Before the fix, `readout.json` was
flagged "unparsable" 27+ times across two days by the hourly self-review
because readers caught non-atomic mid-rewrite states; the file itself was
never corrupt (verified parse on 2026-08-30).

## 3. Alert semantics

`scripts/report-queue` (kernel) appends rows to
`docs/project/reports.md`: `{timestamp | kind | id | first line | body}`.
Semantics (`jobs/oversight-tick.sh` `alert()` + report-queue):
- **Identity + window dedup**: `--identity X --window 86400` bumps one row
  (×N) per day instead of appending per tick — the 2026-08-27 flap fix
  (duplicate stale-store rows before it; exact pre-fix count unrecorded —
  the evidence rows were consumed by the 48h prune).
- **Flap suppression**: same (kind, detail) suppressed for SUPPRESS_MIN
  (60s default) so a 5m tick never spams an unresolved condition; new
  distinct details still alert.
- **Escalation caps**: identity+window dedup currently lets a permanently
  deduped alert stop being information (×N grows unbounded) — backlog row
  `report-queue escalation caps`.
- **Retention**: alerts 48h retention with archive + honest tracked-deletion
  alert rows (`cadence/day/02-ledger-prune.sh`).

## 3.1 The watchers

- **oversight-tick (5m)** — cheap probes every tick (tree-skew on both
  repos with per-repo whitelists, stale stores, loop recognition: 3+
  byte-identical breadcrumbs from one job in 30m, fasttest loops), plus a
  beat-gated agentic steer leg; escalates unread gate-red rows (armed
  2026-08-29, plan step 7) and files ui-audit regression breadcrumbs
  (step 8).
- **agent-supervision.py (5m)** — classifies transcript sessions into
  discovering/writing/verifying/stalled/terminal from tool-call + size
  patterns; bridge-store runs get roguelike replacement (hngh close-run
  dead → rotate record → omp-bridge --run-start re-provision; stage-3
  criterion 2 witnessed 2026-08-27). **2026-08-30 (`5b79b86`)**: transcript
  sessions idle >6h (tool-age) are *evicted* — one journal row, then
  silence — instead of stall/recover flap noise (the 33h ghost session
  class). Bridge runs keep the replace path at any age.
- **dashboard-self-review.py (hour)** — two-tier findings per feed:
  unacceptable-now (stale/parsable/missing keys) vs acceptable-for-now.
- **ui-audit.mjs (hour)** — axe-core + register rules (clip, squash,
  font-floor, name-completeness, default-theme-winamp) over the served
  page; findings feed oversight.
- **gate-check (day)** — `make test` in *both* repos (kernel 2,855 checks
  + automation bash-n/lint), fail-closed rows since 08-29 09:01Z
  (`f92dc864`, `ad39f093`); a red gate cannot sit unnoticed overnight
  anymore.
- **loop recognition (5m)** — repeated-expensive-identical-work detection
  (3+ identical crumbs / fasttest markers) with an interrupt-and-redirect
  steer rubric (`docs/records/2026-08-26-loop-recognition.md`).

## 4. The 2026-08-30 fix set (evidence-cited)

| Commit | Fix | Alert that motivated it |
|---|---|---|
| `be84690` | untrack SQLite `-shm`/`-wal` (only `telemetry.db` tracked) | P1 `17aeb398` |
| `760adb5` | atomic readout writes (both writers) | `e5f68caa` ×27 over 2 days |
| `5b79b86` | supervision evicts >6h-idle transcript sessions (hermetic proof: 1 eviction row across 2 ticks) | `acd0de86`/`e51e5788` ghost flap |
| `1113810` | tree-skew whitelist + machine-maintained `CHANGELOG.md` | `96bd99de` ×11 |
| `dcb6221` | ui-audit name-completeness re-reads corpus before filing | `8f95be31` (18 false violations; live audit 0) |

Plus the review digest slimming (118.9KB → 865B, evening plan step 4) and
the dual-repo gate (step 2) — both from the executed 08-28 evening plan.

## 5. What the 33h window proved about observability

- The machine **verifies relentlessly** — 27+ honest unparsable alerts, an
  agent-stall pair, gate rows every day — and **cannot route a repair**
  (readout.json needed a human director; → R6).
- Findings are hypotheses: one of two fresh-eyes P1s (2026-08-29) was false
  at HEAD (`logs-page-spec.md` was complete) — re-verify against HEAD
  before parking.
- Watchlists need eviction, not just flagging — absence of a staleness rule
  grows noise, not signal.
- Honest zeros are recorded like any other fact (budget digest row
  `f5929eaa`: 0 remote sessions, $0 — the ledger states it, nothing hides).

Cross-links: [04-automation-machine.md](04-automation-machine.md) ·
[08-refactor-investigation.md](../project/08-refactor-investigation.md) R1/R3/R6 ·
`docs/design/ledger-and-records-spec.md` §2 (retention tiers: raw 7d,
rollups 90d, curated permanent).
