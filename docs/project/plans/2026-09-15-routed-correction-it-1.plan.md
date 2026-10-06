<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=correction-it-1 -->
# 2026-09-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `correction-it-1`
at 2026-09-15T18:00:13Z. Alert text: correction it-1: no named check found (clicking mark read appears to do nothing) ×2

## Steps

- [x] Delve: open research subject fail-20260915-correction-it-1 for correction-it-1; record disposition; then fix or park
      Verification: research subject fail-20260915-correction-it-1 present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-15 x2 occurrences aggregated under report-queue identity
  correction-it-1 (the alert text carries the x2 marker; the
  2026-09-16 digest carries the row)
- 2026-10-06T08:38Z wake executed the step (subject row + killed-dup
  disposition + terminal reviewed line recorded)

## Resolution

Killed as a duplicate identity, 2026-10-06: the alert identity
correction-it-1 is the sixth occurrence of the same operator prose
("clicking mark read appears to do nothing") already dispositioned
killed at research-dispositions.tsv:107 — the live dashboard process
predated the mark-read endpoint (9b0876c, 2026-09-11T20:09Z;
unrestarted until 2026-09-14T00:13Z), so every POST
/report-queue/mark-read 404ed and the UI .catch swallowed it. The
acute case was resolved by that restart; the durable inline
error-surface fix (dashboard/app.js) is landed and pinned in
tests/test-dashboard-p1.py + tests/test-dashboard-p1-ui.py MarkRead
classes. Same-prose identities 5dfa8329, df606ea1,
fail-20260915-correction-3146c023, and
fail-20260915-correction-correction-3146c023 were already killed
citing :107 (:429, :435, :450, :454). Following that precedent, the
plan's subject id fail-20260915-correction-it-1 now carries its
subject row (research-subjects.txt), its killed-dup disposition
(research-dispositions.tsv), and a terminal reviewed line row
(research-lines.tsv) so ensure_lines does not mint a fresh research
cycle over a resolved incident. This identity pre-dates the
correction convergence fold (correction-linkage.py, commit 7735068e,
2026-09-15T18:06:25Z — six minutes after this plan's 18:00:13Z
route), so its pre-fold x2 re-route alert is the known class; a
post-fold same-identity recurrence converges into a pending check
(state/pending-checks.tsv) instead of re-alerting. No code change
owed; the alert is quiet: 0 open report-queue rows and no
correction-it-1 row in docs/project/reports.md (checked
2026-10-06T08:38Z).

Lane SLA / halt (escalation-sla rule, 2026-09-23 tune; mirrors the
2026-10-06T00:42Z resolution of
2026-09-15-routed-correction-correction-3146c023): this lane is
closed as killed-as-duplicate, NOT resolved — the fix claim belongs
to the survivor chain (research-dispositions.tsv:107) and rests on
the 2026-10-05 wake's test evidence, not on a live-surface
verification this session. SLA: the killed-dup verdict is valid only
while the prose family stays quiet — the first new occurrence after
2026-10-06T08:38Z (this identity, sibling it-2, or any new
same-prose identity) stales it, and the router's dedup-expiry
re-route is the enforcement — the re-routed plan supersedes this
disposition and must NOT be killed-as-duplicate again. Halt: on that
re-route, stop dispositioning duplicates; verify the live mark-read
POST path against the running dashboard process first (process
start time vs 9b0876c — the family's contradictory verdicts
:107/:450 vs :432, plus synth-2026-10-04-2, leave
stale-process-vs-over-breadth unresolved). A failed live POST files
an operator alert carrying this same SLA/halt pair.
