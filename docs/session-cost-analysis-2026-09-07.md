# Session cost analysis — delegated overnight sessions, 2026-09-07

Source rows: `dashboard/telemetry.db` events kind=session-cost (captured
hourly by `cadence/hour/25-session-cost.sh` from `~/.omp/agent/sessions`
transcripts), `agent-handoffs.md` disposition rows, `logs/budget.md`
session-run rows. Wall times are transcript first→last timestamps; the
`logs/*.log` files carry only each session's final message (no token
telemetry there — the telemetry db is the only token source).

## Per-session numbers, last 7 days

### Paid delegated leads (zai/glm-5.3) — 12 sessions, $19.20 total

| end (UTC) | slug (trimmed) | tokens in | tokens out | in:out | cost | wall | disposition |
|---|---|---:|---:|---:|---:|---:|---|
| 08-31 19:11 | 08-30-evening-selfdev | 163,439 | 76,486 | 2.1x | $1.51 | 1690s | evacuated |
| 08-31 20:30 | 08-30-overnight-continuity | 80,648 | 35,117 | 2.3x | $0.96 | 655s | evacuated |
| 08-31 21:18 | 08-30-overnight-continuity | 269,746 | 51,212 | 5.3x | $2.18 | **1798s** | evacuated |
| 08-31 22:01 | 08-30-overnight-continuity | 99,673 | 49,804 | 2.0x | $0.94 | 1044s | evacuated |
| 09-01 01:00 | 09-01-overnight-continuity | 120,489 | 69,785 | 1.7x | $1.37 | 851s | evacuated |
| 09-01 02:14 | 09-01-overnight-continuity | 810,657 | 66,408 | 12x | $1.48 | **1798s** | evacuated |
| 09-01 03:00 | routed-slow-unit-dropin | 80,733 | 63,320 | 1.3x | $0.86 | 755s | evacuated |
| 09-01 03:00 | (continuity wrap) | 79,581 | 36,832 | 2.2x | $0.67 | 450s | evacuated |
| 09-06 00:46 | dash-selfreview-feed-fresh-sessions | 180,849 | 35,957 | 5.0x | $1.85 | 1429s | cancelled |
| 09-06 01:23 | dash-selfreview-feed-valid-readout | 1,104,592 | 27,408 | 40x | $3.17 | 912s | cancelled |
| 09-06 02:15 | dash-selfreview-summary | 344,545 | 67,544 | 5.1x | $3.34 | 1308s | cancelled |
| 09-06 03:00 | plan-accept-gate-kernel | 430,255 | 12,098 | 36x | $0.86 | 896s | cancelled |

3.77M in / 592k out. The 2026-09-06 night spent $9.23 in 4 sessions —
the night the old cap=4 hit while every plan sat gate-blocked (the
kernel `make test` was RED; see descent.md spend-cap row), so all four
sessions re-derived the same blocked state.

### Local bench model (unsloth/Ornith-1.0-35B) — 16 sessions, $0.00, 98–982s wall

tokens in 0.30M–3.63M, tokens out 3.5k–47.8k, in:out **65x–281x**.
Worst: 2026-09-07 03:03 — 3,632,224 in / 16,340 out, final log output
41 bytes, cause=unknown. The 09-02→09-04 rows produced real work
(e.g. 09-03 00:33: 1.1M in / 47.8k out); the 09-07 rows produced
nothing (causes bad-execution x2, unknown x2).

### Deaths and causes (agent-handoffs.md)

- **rc=124 dead (hard timeout kill at OVERNIGHT_TIMEOUT=1800s):** 6
  rows — 2026-08-28 x3, 08-28 20:30, 08-31 20:30, 09-01 01:01. A paid
  timeout forfeits $1.5–2.2 of input spend mid-work (the two measured
  timeout-wall rows above: $2.18 + $1.48).
- **rc=1 dead x4** on 2026-09-05 00:01–02:01 — the local bench model
  failing four consecutive wakes; each burned a session slot.
- **No-output sessions** on 2026-09-07: 4 sessions, rc=0 but log
  outputs of 41–664 bytes, nothing landed.
- Net: of ~32 delegated sessions since 08-28, 10 (rc=124/1 dead) plus
  4 no-output ≈ **44% produced nothing**; the other 18 landed work.

## Where tokens and time actually go

- **Fixed per-session overhead is negligible:** the brief skeleton
  (WAKE CONTEXT + plan file + autonomy rule + standing auth) is 2–4KB
  ≈ <1% of input tokens; bridge run-start/end, the budget.md row, and
  telemetry emit cost zero model tokens. Essentially all spend is
  variable.
- **Variable spend is orientation:** re-reading the plan, STATE.md,
  reports, dashboard JSON, and git history every wake. Measured
  in:out ratios: paid 1.3x–40x, local 65x–281x. The two 36–40x paid
  sessions were dashboard/feed self-reviews (1.9M combined input
  tokens for 95k output) — machine-greppable material the model read
  by hand. Plan drafting (model_call 4096, one/day) is cheap and is
  not the problem.
- **Time:** wall 98s–1798s. The 1790–1798s rows are hard timeout
  kills; every other session fits well under the cap, so time waste
  is concentrated in (a) the 6 timeout kills and (b) the 8 dead/
  no-output sessions that still consumed 4–16 min each.

## Recommendations

1. **Raise the session cap via the Inventory** (implemented
   2026-09-07): `scripts/overnight-cycle.sh` now reads env
   `OVERNIGHT_MAX_SESSIONS_DAY` > Inventory row `sessions-day-max` (8,
   operator-authorized; row owned by the cadence-tuning lane) > legacy
   constant 4. The old cap demonstrably bound supply, not demand: on
   09-06 all 4 paid slots were spent while every plan sat
   gate-blocked — capacity exists, gate-green supply is the limiter.
2. **Pre-digest the orientation** (implemented 2026-09-07):
   `lib/launch-session.sh` regenerates a bounded repo-context pointer
   (`prompts/overnight/<slug>.context.txt`: repo map, ledger paths,
   torch-sentinel frontier numbers) fresh at every launch and the
   brief carries its path; both briefs gained a ~15-line known-context
   block (Inventory, plans/queue/backlog paths, research index, ledgers
   — "cite these; do not re-derive"). Targets the measured 65x–281x
   orientation ratio; proven hermetic by `tests/test-session-launch.py`.
3. **Local-bench model quality gate** (not implemented — needs the
   model-selection lane): after 2 consecutive dead/no-output sessions
   on the same model source, force paid fallback for the rest of the
   UTC day. Evidence: 09-05 (4x rc=1) + 09-07 (4x no-output) = 8 wasted
   slots in 2 days = a full day's cap under the old 4; the 5/5-probe
   bench keeps re-selecting a model that fails real sessions.
4. **Pre-digest dashboards** (not implemented — cadence lane): the
   09-06 self-review sessions burned 1.9M input tokens hand-reading
   dashboard JSON; a cadence job could emit a bounded summary snapshot
   the brief can inline instead.
5. **Timeout checkpointing** (not implemented — watchdog lane): 6
   rc=124 kills forfeited full input spend; sessions should checkpoint
   progress to the plan file well before 1800s so a killed wake's
   successor does not re-derive the same ground.
6. **Token columns in the session-run ledger row** (not implemented —
   telemetry lane): `logs/budget.md` session-run rows carry no
   tokens/cost; the telemetry db does, but the operator-facing ledger
   should too so spend is visible without sqlite.
