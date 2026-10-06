<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=correction-it-2 -->
# 2026-09-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `correction-it-2`
at 2026-09-15T18:00:13Z. Alert text: correction it-2: no named check found (clicking mark read appears to do nothing) ×2

## Steps

- [x] Delve: open research subject fail-20260915-correction-it-2 for correction-it-2; record disposition; then fix or park
      Verification: research subject fail-20260915-correction-it-2 present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-15T19:00:13Z re-occurred (dedup window expired)
- 2026-10-06T13:26Z wake executed the step (subject row + killed
  disposition grounded in the live mark-read POST verification the
  it-1 halt demanded + terminal reviewed line recorded)

## Resolution

Closed under the it-1 plan's Lane SLA/halt, not as a bare duplicate:
the SLA (2026-09-15-routed-correction-it-1.plan.md) names sibling
it-2 as the re-route trigger and forbids another kill-as-duplicate
until the live mark-read POST path is verified against the running
dashboard process. That verification ran 2026-10-06T13:26Z and
PASSED end to end: hngh-dashboard.service PID 1065 started
2026-10-05T03:16:24Z, post-dating the mark-read endpoint landing
fd86d43b (2026-09-11T20:09:46Z; the 9b0876c hash cited in prior
disposition rows does not resolve in git — fd86d43b carries that
timestamp), so the stale-process root cause of :107 is history; a
token-guarded POST of an unknown id returned HTTP 400
{"ok":false,"error":"report-queue refused (rc=2)"} (route dispatched,
subprocess to scripts/report-queue wired, fail-closed refusal — not
the stale 404); a POST of the oldest unread row 9c9db6ff returned
HTTP 201 {"ok":true}; the reading cursor (docs/project/report-cursor)
advanced 94c48a14 -> 9c9db6ff and unread rows fell exactly 4 -> 3 —
one click advanced one report, refuting the over-breadth hypothesis
(:432, synth-2026-10-04-2) on the live surface; the handoffs row
(mark-read | 2026-10-06T13:26:21Z | automation|9c9db6ff) recorded the
action. The incident class stays closed by :107's stale-process
disposition, now re-grounded in fresh live evidence rather than the
citation chain (:429, :435, :450, :454, :455). No code change owed:
the durable inline error-surface fix (1702e710) is landed and pinned
by tests/test-dashboard-p1.py + tests/test-dashboard-p1-ui.py
MarkRead classes (green 2026-10-05T15:14Z wake). No operator alert
owed: the live POST succeeded. Subject row, killed disposition row,
and terminal reviewed line recorded for
fail-20260915-correction-it-2 so ensure_lines does not mint a fresh
research cycle over a resolved incident.

Lane SLA (carry-forward, supersedes the it-1 halt pair for this
family): the 2026-10-06T13:26Z live verification is the closure
evidence; if the same prose re-alerts AGAIN post-verification despite
the green live path, treat it as a NEW defect investigation (server
drift or over-breadth variant) with a fresh process/live-POST check —
not another duplicate kill.
