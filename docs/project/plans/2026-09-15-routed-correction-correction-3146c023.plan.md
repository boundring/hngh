<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=correction-correction-3146c023 -->
# 2026-09-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `correction-correction-3146c023`
at 2026-09-15T18:00:13Z. Alert text: correction correction-3146c023: no named check found (clicking mark read appears to do nothing)

## Steps

- [x] Delve: open research subject fail-20260915-correction-correction-3146c023 for correction-correction-3146c023; record disposition; then fix or park
      Verification: research subject fail-20260915-correction-correction-3146c023 present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-15T19:00:13Z re-occurred (dedup window expired)
- 2026-09-15T20:00:13Z re-occurred (dedup window expired)
- 2026-10-06T00:42Z wake executed the step (subject row + killed-dup disposition + terminal reviewed line recorded)

## Resolution

Killed as a duplicate identity, 2026-10-06: the alert identity
correction-correction-3146c023 is the fifth occurrence of the same
operator prose ("clicking mark read appears to do nothing") already
dispositioned killed at research-dispositions.tsv:107 — the live
dashboard process predated the mark-read endpoint (9b0876c,
2026-09-11T20:09Z; unrestarted until 2026-09-14T00:13Z), so every
POST /report-queue/mark-read 404ed and the UI .catch swallowed it.
The acute case was resolved by that restart; the durable inline
error-surface fix (dashboard/app.js) is landed and pinned in
tests/test-dashboard-p1.py + tests/test-dashboard-p1-ui.py MarkRead
classes. Same-prose identities 5dfa8329, df606ea1, and the re-routed
fail-20260915-correction-3146c023 were already killed citing :107
(:429, :435, :450). Following that precedent, the plan's subject id
fail-20260915-correction-correction-3146c023 now carries its subject
row (research-subjects.txt), its killed-dup disposition
(research-dispositions.tsv), and a terminal reviewed line row
(research-lines.tsv) so ensure_lines does not mint a fresh research
cycle over a resolved incident. No code change owed; the alert is
quiet: 0 open report-queue rows, no occurrence since
2026-09-15T20:00:13Z (checked 2026-10-06T00:42Z).

Lane SLA / halt (escalation-sla rule, 2026-09-23 tune): this lane is
closed as killed-as-duplicate, NOT resolved — the fix claim belongs to
the survivor chain (research-dispositions.tsv:107) and rests on the
2026-10-05 wake's test evidence, not on a live-surface verification
this session. SLA: the killed-dup verdict is valid only while the
identity stays quiet; the first new occurrence after 2026-10-06T00:42Z
(this identity or any new same-prose identity) stales it, and the
router's dedup-expiry re-route is the enforcement — the re-routed plan
supersedes this disposition and must NOT be killed-as-duplicate again.
Halt: on that re-route, stop dispositioning duplicates; verify the
live mark-read POST path against the running dashboard process first
(process start time vs 9b0876c — the family's contradictory verdicts
:107/:450 vs :432, plus synth-2026-10-04-2, leave
stale-process-vs-over-breadth unresolved). A failed live POST files
an operator alert carrying this same SLA/halt pair (stale at 48h ->
auto re-route; halt = dashboard restart + mark-read gate re-check, no
further research cycles on the prose family).
