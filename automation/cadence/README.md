# cadence — mounted work per tier

Each cadence tier (1m / 5m / 10m / 30m / hour / day / week / month) runs
`jobs/cadence-tick.sh`, which executes every `*.sh` drop-in under its own
directory here in lexical order. Drop-ins are plain bash scripts sourced
with the standard `jobs/` environment (`lib/common.sh`). An empty or
absent tier directory does nothing (breadcrumb only, exit 0).

To mount work at a cadence: `mkdir -p cadence/<tier>` and drop a `*.sh`.

Tier schedules (systemd, see the unit `OnCalendar=`):
- 1m  `*:*:00`   · 5m  `*-*-* *:0/5:00` · 10m `*-*-* *:0/10:00`
- 30m `*-*-* *:00/30:00` · hour `*-*-* *:00:10` (10s offset dodges the :00:00
  autonomy/ping storm; the `hngh-automation`/`hngh-autonomy` timers stay
  separate units)
- week `Mon *-*-* 06:00:00` · month `*-*-01 06:00:00`

## Mounted drop-ins (2026-09-07)

Self-gating drop-ins run more often than their effective beat: the gate
inside each script skips runs until the Inventory interval elapses.

- hour: `31-heartbeat` (heartbeat-minutes, default 60, was hardcoded 3h),
  `16-remote-push` (push-cadence-hours stamp rate-limit, moved from the
  day tier so a due push can no longer wait up to a full day for the
  next 05:00 tick),
  `33-research-beat` (research-beat-hours, default 1, was 2, moved from
  the day tier, was daily; 1h-stamped with the idle-governor load guard,
  acceleration wave 2: loadavg1 >= research-load-ceiling * nproc no
  longer defers when the deck leg is armed -- the run is pinned to the
  deck (deck-pin-on-busy); only an unarmed deck defers without
  consuming the stamp. Every research-review-interleave-th run
  (default 4, 0 = never) reviews the oldest crystallized line instead
  of advancing a planned line; an empty pool below
  research-demand-floor (default 2) triggers the demand synthesizer --
  one local-model call per UTC day reading dispositions, lessons,
  backlog sections, and alert identities, appending only subjects that
  name a specific source item; both the research prompt and the
  synthesizer carry a bounded prior-art excerpt grepped from the two
  llm-wiki vault indexes (read-only pointers, 6 lines / 600 bytes,
  silent when the vaults are absent -- wiki surface, hngh
  docs/design/wiki-surface.md))
- 30m: `50-research-overflow` (acceleration wave 2: same beat body as
  `33-research-beat`, pinned to a quota leg -- odd runs kimi, even runs
  lobehub, never the local server; gated on research-overflow-hours
  (default 2) since its own stamp AND >= 30 minutes since the hour
  beat's stamp, so research can transition up to every 30 minutes at
  peak with zero local contention)
- day: `17-torch-audit` (moved from week), `18-mimic-drill` (moved from
  week), `25-wiki-health` (moved from week; model-free two-vault probe:
  pages-on-disk vs registry count + meta staleness per llm-wiki vault,
  one identity-deduped alert per unhealthy vault), plus the pre-existing
  day drop-ins
- week: `01-roadmap-review`

Day-tier drop-ins (one beat per script, lexical order):
`01-activity-tick` · `01-lesson-harvest` · `02-ledger-prune` ·
`03-gate-check` · `04-review-prep` · `06-remote-posture` ·
`06-review-disposition` (sinks digest findings to the report queue) ·
`07-budget-digest` · `08-doc-suite-check` · `09-email-digest` ·
`10-bench-fresh` · `11-service-recovery` · `13-email-qa` ·
`14-plan-ledger-sync` · `15-resume-pass` ·
`17-torch-audit` · `18-mimic-drill` ·
`19-ux-review` (daily rotating antagonistic UX-review cycle -- one
operator surface per run via UTC-day rotation, model fresh-eyes pass
under the house registers, findings to the report queue) ·
`20-model-saturation` (Tier 3 saturation instrument, model-free: per-UTC-
hour utilization of the desktop unsloth from telemetry kind=model over
24h -- wall-s sums when present, else call counts times the measured
research-call mean -- one identity-deduped report row per day with a
headroom verdict; deck leg is overflow-only and not counted) ·
`22-ttsr-fit` (ttsr alignment record screen, model-free: VERIFY leg
probes the operator's omp stream rules + ttsr.enabled for drift, DETECT
leg counts ttsr injection markers and runs the mirrored rule regexes
post-hoc over assistant transcript text — the thinking-scope backstop —
one identity-deduped alert per session past ttsr-fit-threshold or any
post-hoc match; design: hngh docs/design/ttsr-alignment.md)

`25-wiki-health` (daily wiki-vault health + need-triggered automated
rebuild, design: hngh docs/design/wiki-surface.md): the daily probe is
model-free (pages-on-disk vs registry count + meta staleness per vault,
7d identity window). When a vault is UNHEALTHY and wiki-auto-rebuild is
1, the script spawns ONE bounded omp one-shot session (cwd = the vault's
parent) whose prompt asks the loaded llm-wiki extension to run
wiki_rebuild_meta -- the rebuild happens inside that session; Hngh never
writes meta/ or raw/ itself. Anti-thrash: at most one attempt per vault
per UTC day (stamp file). Each attempt is timed and emits one telemetry
row (kind=wiki-rebuild: identity=vault, wall_s, outcome
unfrozen|still-unhealthy|attempt-failed, before/after page-vs-registry
counts); the vault is then re-probed inline -- healthy replaces the
alert with an unfrozen ok row, still-unhealthy keeps the alert with
'rebuild attempted <ts> -- insufficient' appended. Alert and ok rows
carry the vault's 7d rebuild efficacy (attempts / unfrozen from
telemetry) so a repeatedly failing vault is a visible pattern, not a
repeated surprise. Two consecutive daily non-unfrozen attempts file a
research subject (ctx-wiki-rebuild-<vault>) -- the cycle's own failures
become research demand. The weekly lessons seed stays inside this
script but runs Mondays only (the probe went daily; the vault file
churn stays weekly). Tunables: wiki-auto-rebuild, wiki-rebuild-timeout
(Inventory); Torch's weekly audit reads the same wiki-rebuild
telemetry.

## 5m oversight tick — loop recognition (2026-08-26)

`cadence/5m/01-oversight.sh` → `jobs/oversight-tick.sh` now watches the
repeated-expensive-identical-work class. `probe_test_loops` alerts on 3+
byte-identical breadcrumbs from the same oversight/credential/ceremony job
within 30 min (consecutive for that job), and on 3+ `hngh-fasttest-*` verify
markers for one repo within 5 min. The agentic `steer_leg` prompt carries the
loop rubric (interrupt-and-redirect as the repeat starts). See hngh
`docs/records/2026-08-26-loop-recognition.md`.
