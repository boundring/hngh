# 2026-09-12 - the patrol system: formalized rounds over hngh surfaces

Operator directive: "rounds and patrols" - the way subagent sessions make
the rounds of hngh checking for things needing attention should become
automated cadence machinery, with findings feeding the lessons pipeline.
This record documents what landed.

## The pattern it encodes

Until today, "making the rounds" was a director session's job: the
night-watch loop woke every 45 minutes and eyeballed the same surfaces by
hand (STATE.md crumbs, handoffs, the blocker ledger, gate rc, budget,
digest QA; see automation/logs/night-watch-20260912.log). Routine checks
needed a session to be awake to walk them. The patrol formalizes those
rounds: one runner (automation/jobs/patrol.py) walks a structured
checklist of surfaces (automation/config/patrol-routes.tsv), each check a
deterministic pure function over existing ledgers - no model calls, no
daemon - and files structured findings. Sessions making rounds become a
standing patrol; a director session is only needed for judgment, not for
routine checks.

## The surfaces and their checks

Manifest: automation/config/patrol-routes.tsv (one row per patrol:
patrol-id, surface, check, freq-tier, finding-class).

30m tier (cadence/30m/58-patrol.sh, the quick surfaces):
- feeds (dashboard-feeds, feed-freshness): mtime staleness of
  dashboard/plans.json (>3600s), operator-items.json (>600s),
  sessions.json (>600s) -> feed-stale / feed-missing.
- blockers (blocker-ledger): an ACTIVE row at/over blocker-escalate-n
  attempts that the watchdog failed to park -> blocker-escalated;
  parked rows are reported, not failed (that is the escalation path
  working).
- handoffs (handoffs-accumulation): dead/cancelled runs among the last
  10 overnight-lead rows, >= 3 -> bad-execution.
- automation-gate: newest gate-green/gate-red crumb from
  03-gate-check.sh decides; none in 26h -> gate-stale. Reads the make
  test tail the gate already filed; never re-runs the suite.
- stall (overnight-ledger): >= beat-stall-n (3) consecutive `failed`
  results tokens across overnight-done crumbs -> bad-execution (the
  2026-09-11 signature).

day tier (cadence/day/27-patrol.sh, the heavier surfaces):
- kernel-gate: the loop-history guard run fresh (rc + violation count,
  ~1.4s of git history - what the night-watch checked by hand).
- research-flow: research-lines.tsv rows stuck in one non-terminal state
  (planned/expanding/contracting) > 48h -> stalled-line.
- paper (paper-edition): today's digest/digest/<date>.md exists,
  non-empty, Deck A blocks present (hour headers with item lines);
  before 02:00 UTC the day is not yet due.
- services: one HTTP probe per in-use/operator-run row with a health-url
  in config/hngh-services.tsv (comfyui, unsloth-llamaserver, ollama);
  any HTTP answer is responsive, transport failure -> service-down.
- disk: df use% >= 90 on / -> disk-full.
- budget: today's session-run rows in logs/budget.md against
  sessions-day-max -> budget.

The artifact review keeps its own day slot (26-publication-review.sh) and
is deliberately not duplicated; the patrol checks the paper edition's
existence/shape, the review checks its content.

## How findings escalate

1. Every FAIL prints `FAIL <patrol>/<artifact> <cause> <detail>` (the
   machine contract, mirrors jobs/publication-review.py) and files a
   report-queue alert, identity patrol:<patrol-id>, window 86400 (same
   patrol failing all day folds into one row with an xN marker).
2. Findings append to automation/digest/PATROL-<date>.md, one run
   section per invocation in the publication-review two-pass format
   (supportive + adversarial), one evidence-first quip per run
   (quips.py patrol bank, register law).
3. The findings doc is the patrol's only state: the previous run's FAIL
   set is read back from it, and a patrol+cause repeating on TWO
   consecutive runs auto-queues a research-subjects.txt entry (house
   convention, rid patrol-<date>-<patrol>-<cause>): the patrol found the
   pattern, the research beat crystallizes the lesson.
4. The patrol itself is fail-first: a runner crash files one alert
   (identity patrol:runner) and exits 0 - a crumb, never tick damage;
   a single check crash fails open as a FAIL check-crash and the walk
   continues. Only usage errors (unknown patrol id, bad args) exit 2.

## Verification

- automation/tests/test-patrol.py: 9 hermetic tests (healthy ledger
  quiet; stale feed; 3 failed crumbs; missing digest; escalated blocker;
  unknown patrol id exit 2; check-crash fail-open; runner crash
  suppressed; repeat cause queues a research subject exactly once).
  Wired into automation/Makefile after test-beat-watchdog.py.
- `python3 jobs/patrol.py --tier 30m` / `--tier day` live: see the run
  sections in automation/digest/PATROL-2026-09-12.md.
- Full `make test`: green on every entry except tests/test-manga-draft.py,
  which carries a sibling session's in-flight assertions (144 uncommitted
  insertions for a wireframe renderer not yet landed) - pre-existing red,
  not the patrol's.
