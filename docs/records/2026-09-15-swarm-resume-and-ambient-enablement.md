# 2026-09-15 - Swarm-resume mission and ambient enablement

## Scope

Two operator-directed efforts completed 2026-09-15: (1) recovery and
batch-driven completion of the interrupted 2026-09-14 bug-session swarm
graph (the "hngh development" session lost to provider outages and a
suspend/resume), and (2) enabling jcode Ambient mode under a scoped,
operator-approved configuration. Records the outcome, the evidence
artifacts, and the parked residue.

## Swarm-resume mission (operator option A: "resume with smaller batches")

- Recovered the interrupted graph from
  `~/.jcode/state/swarm/session_session_bug_1789409372212_*.json`:
  271 nodes (138 completed, 71 queued, 62 failed); 257 spawned worker
  sessions; failures were zai-outage wreckage, not active bleeding.
- Re-drove the live leaves in 15 gentle waves (max 3 concurrent, worker
  DM-on-completion contract, artifact-per-node) into
  `.agent-scratch/swarm-resume/` (56 artifacts). Routing: zai primary,
  opencode-go secondary, Kimi reserved (7-day window at 82.81%,
  operator: "it runs out easily").
- Both parent syntheses landed: `viz-design.md` (5-rung megastructure
  ladder; first increment = history/1 producer + /history.json + spine
  stream view, est. 2-3 sessions) and `viz-history-work-parent.md`
  (history + upcoming-work views, reuse guidance, producer
  prerequisite). Per-source spec set complete: git/report/records/
  journal windows, caps (HIST_CAP_* proposal), schema/1 envelope,
  dedup keys, transport/format inventories with file:line evidence.
- Remainder parked for the operator: ceremony-bound implement nodes
  (`sg-*`, `retry-render-pipeline`, `retry-viz-schema` - kernel/
  jcode edit surface) and superseded mechanical gates.

## Findings elevated out of the exploration

- CI-only patch-id drift root-caused (see
  docs/records/2026-09-15-ci-patch-id-drift.md, corrected by commit
  `8899934c`): `core.abbrev=auto` length leaks into patch-id for
  binary-file sections. Cure is ceremony-bound (hermetic
  `--no-binary`/`--full-index` recipe + one-pass re-registration).
- Live data bug: automation MCP `read_tsv` keeps the OLDEST 200 rows
  on cap; research-dispositions.tsv (161 rows, 20-50/day) crosses the
  cap within days, silently hiding newest reviews. Fix dispatched on
  the automation free-commit lane (test-first).
- Reload ghost gap confirmed with code evidence and filed upstream
  (jcode maintainer): `spawned`/`queued` member statuses pass through
  reload recovery verbatim (`swarm_persistence.rs:341-391`); issue
  #1249 covers the symptom class; our reload-passthrough mechanism +
  suspend/resume repro + MAX_SWARM_MEMBERS capacity angle were added
  as maintainer feedback. The 2026-09-14 zombie-session wreckage is
  the field repro.
- reports.md hazards catalogued (rp-ledger.md): 49 pipe-ghost rows, a
  duplicate id, zero test coverage on the `--evidence` suppression
  branch; queue.md has 5-column rows invisible to 4-column consumers.

## Ambient enablement (operator-approved)

- Enabled garden-only: `[ambient] enabled=true, proactive_work=false,
  allow_api_keys=true, api_daily_budget=75000, min_interval_minutes=30,
  provider="opencode-go", model="glm-5.3"` (backup:
  `~/.jcode/config.toml.bak-pre-ambient-on`). Z.AI stays dedicated to
  swarm batches; Kimi untouched.
- Activated via `jcode server reload --force` (graceful re-exec;
  sessions survived). First cycle verified good behavior: verified
  stale claims by re-running the suite before pruning, extracted the
  operator's claude/codex-authorization policy into a linked memory,
  scout pass read-only. Next wake self-scheduled 4h out. Zero
  x-ratelimit headers on ocgo, so ambient's adaptive scheduler runs on
  conservative defaults; our `~/.hngh/tools/quota-check.py` remains
  the authoritative budget instrument.

## Tooling added

- `~/.hngh/tools/quota-check.py` (`--json`): live Z.AI
  (`api.z.ai/api/monitor/usage/quota/limit`) and opencode-go
  (`opencode.ai/zen/go/v1/usage`) probes, payload-derived window
  labels, local + relative reset times; triple-verified against
  coreutils date(1) and the provider dashboards. Kimi documented as
  dashboard-only (no coding-API usage endpoint; verified by probing).

## Disposition

Mission complete; no further waves queued. Follow-ups: MCP read_tsv
fix (in flight), consolidation of viz-design next steps into the queue
is an operator decision (all work is proposal-grade artifacts, never
auto-executed).
