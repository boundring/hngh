# Correction note: d4-principles artifact (dated 2026-09-15)

The d4-principles deliverable (26 principles, 5 families, keep/shrink/drop)
is a task-graph node artifact (swarm plan node `d4-principles`, completed
2026-09-15 ~21:32Z by session otter), not an on-disk file. This sidecar
records factual corrections from the plan::gate audit of that artifact and
the downstream spec (hnnghh-core-spec.md) against the working tree, per the
evidence-before-claim principle (B6). The corrected claims all entered via
refactor-assessment.md, which the artifact cites; the underlying principles
themselves are unaffected.

## C1. Gate-crumb mechanism (superseded state described as current)

- Claimed: "patrol.py newest-crumbs-wins, no TTL caused the false
  red-gate incident."
- Actual: true only before 2026-09-15 13:29 EDT. Commit d0bcb477 added the
  freshness TTL: automation/jobs/patrol.py:58 GATE_CRUMB_TTL_S=86400
  (PATROL_GATE_CRUMB_TTL_S env override), and check_gate_crumbs
  (automation/jobs/patrol.py:271-287) now degrades stale crumbs to one
  dedupable gate-stale fail (fail-closed on absent evidence) instead of
  letting a stale red decide. Stale crumbs degrade rather than decide.
- The incident's honest before-state: pre-d0bcb477 the newest gate crumb
  decided with only a 26h absence check (GATE_STALE_HOURS), so a stale
  gate-red crumb held the automation-gate label red for hours after
  recovery ("red gate all day" = stale crumbs, a hygiene defect, not a
  red gate). Still-open adjacent facts: router within-day dedup
  suppression (automation/scripts/router-tick.py:20-22, :442-468,
  escalation only at >=3 dedups, routed != resolved) and the cure/dedup
  meta-loop (check_gate_cure, patrol.py:636-696) remain to be retired by
  spec 3/R4.
- Check: `git show d0bcb477 -- automation/jobs/patrol.py`; `sed -n '58p;271,287p' automation/jobs/patrol.py`.

## C2. Cadence tier count (8, not 9)

- Claimed: 9 tiers (1m..month). Actual: 8 live tiers
  (1m/5m/10m/30m/hour/day/week/month), matching
  automation/cadence/README.md ("Each cadence tier (1m / 5m / 10m / 30m /
  hour / day / week / month)").
- Check: `ls -d automation/cadence/*/ | wc -l` = 8 (measured 2026-09-15).

## C3. Research lifecycle counts (drifted; re-measure, never hard-code)

- Claimed: 165 research lines, 169 disposition rows, 0 of 73 adopted
  verdicts feed any runtime decision; only consumer of dispositions.tsv
  is patrol.py as alert-history.
- Actual at measurement time (2026-09-15T23:36Z): 169 line rows;
  173 disposition data rows (verdict classes: 75 adopted across 72
  distinct lines, 32 killed, 65 parked, plus 1 blocker-ledger "fixed"
  row that research-routes.py skips as an unknown action); 69 seeded
  lesson rows. Counts moved during the audit itself (172 -> 174 raw
  lines), because the beat appends continuously.
- The "only consumer" claim is false as of the same-day landings:
  bc40ab6d (18:11 EDT, D1 harvest, research-harvest.py +
  research-lessons.tsv), 0bb09044 (18:51 EDT, D6 routes/1 map,
  automation/jobs/research-routes.py reads the dispositions ledger as
  the transition log), and the context-pack adopted-lessons block
  (automation/lib/context-pack.sh:90-96) all consume it; patrol.py also
  checks adopted-verdict follow-on promises (check_disposition_followons,
  patrol.py:852+; landed 94cd9693, 2026-09-12).
- Pin with (exact commands):
  - `awk 'END{print NR}' automation/research-lines.tsv` (headerless file)
  - `awk 'FNR>1' automation/research-dispositions.tsv | wc -l`
  - `awk 'FNR>1' automation/research-lessons.tsv | wc -l`
  - `awk -F'\t' 'FNR>1{split($3,a," ");print a[1]}' automation/research-dispositions.tsv | sort | uniq -c`

## Disposition

The 26 principles and their five-family structure stand as written; the
corrections bind the artifact's keep/shrink/drop evidence rows (cadence
count, patrol before-state, pipeline-terminus counts) to the audited
figures above, and the same corrections are folded into
hnnghh-core-spec.md (header note, sections 2.2/2.3, R1, R4, R6, H1-H7).
No kernel files, no code, nothing committed outside .agent-scratch.
