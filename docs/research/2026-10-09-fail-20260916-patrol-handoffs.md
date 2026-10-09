# fail-20260916-patrol-handoffs — patrol:handoffs delve (routed plan 2026-09-16-routed-patrol-handoffs-2)

Alert: `patrol handoffs: bad-execution on agent-handoffs.md -- 10 dead/cancelled in last 10 rows` (filed 2026-09-16T21:00:14Z by scripts/router-tick.py). Routed plan auto-accepted 2026-09-18T01:41:57Z; delve executed 2026-10-09T00Z.

## Mechanism

`check_handoff_deaths` (automation/jobs/patrol.py:261-286): takes the last
HANDOFFS_LAST_N=10 `overnight-lead |` rows of automation/agent-handoffs.md,
counts rows containing `" dead "` or `"cancelled"`, files the bad-execution
alert when the count >= HANDOFFS_THRESHOLD=3. Route row: config/patrol-routes.tsv
`handoffs -> handoffs-accumulation -> handoff-deaths (30m)`.

## Condition at disposition time (2026-10-09T00:19Z) — LIVE, not self-healed

4 of the last 10 overnight-lead rows are genuine rc=124 timeout-kill deaths:

- 2026-10-07T18:37:26Z 2026-09-15-routed-repeat-crumbs
- 2026-10-08T04:37:30Z 2026-09-16-routed-overnight-plan-accept-blocked (dev-fail twin)
- 2026-10-08T09:31:38Z 2026-09-16-routed-overnight-plan-accept-gate-automation-2
- 2026-10-08T14:47:23Z same slug

4 >= 3, so the identity would re-fire on the next patrol tick. Unlike the
plan-accept-gate-kernel/automation delves closed 2026-10-08, no
killed-before-research verdict is available here.

## Why parked, not fixed

- The dead rows are the documented rc=124 timeout-kill class
  (docs/records/2026-09-11-beat-stall-diagnosis.md): routed delves outliving
  their launch TIMEOUT_S are classified bad-execution by design, and the
  respawn guard treats them as transient and relaunches — run-level
  self-correction already exists.
- The original 2026-09-16 filing (10/10 in window) sat at the tail of the
  2026-09-13/14 model-burn stall era; the accumulation counter echoes
  whatever the launch plane is doing, it is not a defect signal of its own.
- What a real "fix" means — status-token matching instead of substring,
  freshness window, per-cause weighting, or session-length pacing — is a
  design decision owned by the class research line, not a mid-wake code
  change.

## Class state

Ten sibling occurrences (patrol-20260912..24-handoffs-bad-execution) were
killed as dupes of the kept carrier patrol-20260925-handoffs-bad-execution
(research-dispositions.tsv rows 303-367, reorientation 2026-09-25); the
carrier itself remains live with no disposition. This row parks and joins
that carrier rather than minting an eleventh dupe-kill.
