# 2026-10-01 Governed Fleet stage 3 exit -- ten invariants verified, roadmap flip

Filed by the governed-fleet-consolidation plan's final step (the roadmap
stage 3 row flips to done). Evidence citations only; the design surface
is docs/design/governed-fleet.md section 4 (the ten invariants). The
per-invariant evidence was swept read-only across the kernel tree and
automation/ on 2026-10-01.

## The ten invariants

| # | Invariant | Verdict | Standing guard | Evidence |
|---|-----------|---------|----------------|----------|
| 1 | Declared chain legs (no undeclared pair admits) | holds | automation/tests/test-leg-budgets.py wired automation/Makefile:63 | config/leg-budgets.tsv:3-5 rule "no declared pair, no chain admission"; all model-chain legs :30-38, image legs :42-45, audited values with source citations :7-27, ghost rows forbidden :26-27; budget ledger current through 2026-10-01T01:32:16Z (logs/budget.md:296) |
| 2 | Patrolled services | holds (guards green; patrol recency was broken by the calendar-pick bug below, revived this session) | test-hngh-services.py Makefile:65, test-service-ctl.py :101 | routes config/patrol-routes.tsv services->service-health, service-children->services; fresh day patrol 2026-10-01 quoted below |
| 3 | Token-only, stat-mode-only credential seams | holds | test-credentials.py :58, test-doc-secrets.py :60, per-leg seam tests :153-154,203-204,220-222 (incl. 27-check slice-E seam surface) | security-check.sh:51-52 emits breadcrumb bili=$b_ok; slice E landed 2026-09-30 commit afe632e7, both gates rc=0 |
| 4 | Matrixed spawn paths in the compression/telemetry surface | holds | test-bctx-launch.py :140, test-session-launch.py :139, test-ocgo-launch.py :142, test-context-pack.sh :168, test-session-cost-cache.py :223 | slice A commit 6764d00b tokens_cached capture; slice B five-row spawn-path matrix promoted into governed-fleet.md section 2 + backfill emitters; live attribution rows logs/budget.md:261-262 (source=ocgo) and :295-296 (source=env) |
| 5 | Package ghost rule | holds (day route revived with the calendar-pick fix) | test-hngh-packages.py automation/Makefile:64 | ghost-row rule enforced in jobs/patrol.py; fresh patrol: "PASS packages/package-ghosts 5 in-use row(s) resolve" |
| 6 | Quota windows consumed by pacing | holds (budget day route revived with the calendar-pick fix) | test-quota-routing.sh :190, test-model-demote.sh :188 | caps declared cadence-params.tsv (kimi-daily-cap 40, gemini-burst 20/3600s, zai-cap-5h 300 / zai-cap-week 1500, opencode 60/150/300, sessions-day-max 200, xiaomi-cap-day 40, model-tier-refresh-ola 7776000); fresh patrol: "PASS budget/session-budget sessions=2 cap=200"; queue report shows no patrol:budget alerts |
| 7 | One witnessed cycle with a seeded stall auto-replaced | holds | watchdog + supervision + respawn guards (lib/causes.sh, jobs/agent-supervision.py) | slice C1 witnessed clean cycle 2026-09-28 (spawn rc=0, disposition=complete, budget row 03:17:55Z); slice C2 seeded stall auto-replace 2026-09-29 (misses->2, die_session, close-run, rotation, exactly one --run-start auto-replace); slice C3 residue sweep clean; witness rows agent-handoffs.md |
| 8 | One governed package upgrade through the certificate loop | holds | kernel ceremony loop + test-candidate-hash-reconciliation.py automation/Makefile:107 | candidate commit 90fae191 2026-09-30 "hngh: candidate fb8a3a06..."; record docs/records/2026-09-30-governed-package-upgrade-bili.md (create-run -> admit-transport -> propose -> prepare-candidate -> commit -> gated push) |
| 9 | Config lanes on the 30m cadence | holds (standing since the 30m tier) | config-lanes.tsv + lane checks | cadence/subhour/20-config-backup.sh launches every subhour tick (STATE.md tick row 2026-10-01T06:33:01Z) |
| 10 | One lattice peer admitted (federation exit) | holds | peer pins + verified attestation; wake-mutation certificate lane | slice F executed 2026-09-30: deck peer steamdeck admitted (fingerprint pinned, staleness bound 86400s; store rows creation + transport:federation + admit-peer); wake status=issued via real bounded ssh transport; run-worker cross-host status=complete; kernel make test 2954 checks green |

## Calendar-tier pick regression (found and fixed this session)

What: the calendar tier was dormant since 2026-09-24 -- every calendar
tick logged "nothing-mounted" (STATE.md rows 2026-09-25..09-30);
cadence/calendar/daily/27-patrol.sh last ran 2026-09-24T09:08:01Z, so
31 daily + 2 monthly + 4 weekly drops (day patrols, gate check, ledger
prune, hygiene) never fired.

Root cause: jobs/cadence-tick.sh calendar_pick read the firing instant
with `date -u` (UTC) while the systemd OnCalendar rows (05:00 daily;
Mon/1st 06:00 weekly/monthly) are written in LOCAL time. At a 05:00
local (EDT) firing the UTC hour is 09, so the pick mounted no subdir
(introduced by the 2026-09-24 tier collapse, B3).

Fix (automation free commits): the pick now reads the local clock --
the same clock the OnCalendar rows are written in; hermetic seam
CADENCE_PICK_INSTANT added beside CADENCE_PICK_ECHO; stale manifest
comment config/patrol-routes.tsv corrected to the real drop-in paths
(cadence/subhour/58-patrol.sh, cadence/calendar/daily/27-patrol.sh).
tests/test-cadence-collapse.sh pins the local-time semantics (instant
seam 05/06/09 cases + a static no-`date -u` pick-path assertion) and
its firing-equivalence simulation was re-accounted for the seven
post-collapse drops (all 76 jobs firing-identical across the four
fixtures).

Fresh day patrol after the fix (python3 jobs/patrol.py --tier day,
2026-10-01), the four invariant routes:

```
PASS services/service-health:unsloth-llamaserver http://127.0.0.1:8888/health answered HTTP (error status)
PASS services/service-health:ollama http://127.0.0.1:11434/ responsive
PASS service-children/service-children:comfyui no transient child (pattern 'port 8188')
PASS packages/package-ghosts 5 in-use row(s) resolve
PASS budget/session-budget sessions=2 cap=200
```

Two FAILs filed alerts (legitimate findings, not guard failures):
recon/kernel label-content-divergence (3c28f6ba80e8 label drift) and
services/comfyui service-down (http://127.0.0.1:8188/ unreachable;
its service-children check correctly reports no transient child).

## Ceremony receipts residue note

~/.hngh-automation/cert-receipts.tsv holds prepare-candidate+commit
verb rows stamped 2026-10-01T06:02:10Z (hash 4ad0b80e...) with NO
candidate commit in git log (last candidate remains 90fae191,
2026-09-30): residue of a refused/faulted run, not an in-flight
ceremony (no live store, no ceremony process). This drive uses a
fresh /tmp store; the residue rows are ignored.

## Flip declaration

All ten invariants hold under standing guards and patrols. The roadmap
stage 3 row (State **landing** -> **done**), working-order item 3, the
kernel CHANGELOG entry, and the plan's final checkbox land together
through the certificate ceremony (kernel docs commit); the queue,
handoff-witness, and state ledger rows follow as the automation free
commit. Gates at the ceremony boundary: kernel `make test` and
automation `make test` both green.
