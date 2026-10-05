# Meta-cyclical learning

> First you build the mirror; then you teach it to look back.

Status: design, 2026-10-05. Machinery named here rides what already exists;
none of it is built yet except where marked.

## 1. Purpose

Hngh already watches itself. "The machine now watches itself: a time
ledger measures every level, a self-review inspects its own dashboard
hourly, and the oversight path flags drift before a human would"
(docs/project/roadmap.md:11-13); rung 1, Self-watch, is done
(roadmap.md:28). Watching is not learning. Meta-cyclical learning is the
next turn of the screw: the loop observes its own state changes, extracts
knowledge from them, feeds that knowledge back into its own behavior, and
then audits whether the feeding worked - closure of the loop on itself.

The Descent already frames the machine as a cycle through six stations,
Observe/Lookout through Audit/Torch (docs/design/descent.md), and it
already states the accounting rule the audit must honor: "a failure
classified at one station becomes a research demand at another, and the
final station measures what the loop consumed - not what it produced"
(descent.md:16-19). This document does not add a station. It wires the
stations to each other and gives the loop a mirror it cannot lie to.

## 2. Five hops

One traversal of the cycle. EXISTS = machinery live in the automation
tree; PARTIAL = machinery covers only one class of input; MISSING = no
machinery, only intent.

| hop | state | file evidence |
|-----|-------|---------------|
| 1. observe own state changes | EXISTS | automation/agent-handoffs.md rows carry `cause=<class>`; automation/.lesson-harvest-handoffs is a line counter of what the harvester has consumed (01-lesson-harvest.sh:52-56); report-queue rows, plan lifecycle ticks, and git commits are all ledgered |
| 2. extract knowledge / judge signal | PARTIAL | lib/causes.sh classify_cause (causes.sh:27) classes failure logs and lesson_for_cause (causes.sh:72) emits one sentence per class, but only for failures; bulk judgment of commits and handoffs exists as a session method (judge_batch job jdgb-1599d5f56e1586bd, docs/agent-notes/jevify-2026-10-05-state-changes.md) - no cadence beat runs it |
| 3. route the signal | PARTIAL | failures route: append_research_subject (causes.sh:143) plus the six shell appenders; knowledge signals stop at the docs/project/lessons-<date>.md digest and never reach a ledger |
| 4. feed back into behavior | PARTIAL | lesson-harvest ends each daily pass in a guardrail cross-check ("Fold it into agent-guardrails.md"); research-lessons.tsv rows have six live consumers (33-research-beat.sh, jobs/research-routes.py, jobs/patrol.py, lib/context-pack.sh, lib/research-harvest.py, scripts/research-tsv-path-sweep.py); but nothing requires any of it to change behavior |
| 5. audit the feeding | MISSING | no cause-recurrence or lesson-effect measurement exists; the five falsifiable weekly checks (descent.md:177-184) are specified and unwired |

## 3. The jevify method

Judgment is periodic, bulk, and over a delta: agent-handoffs.md rows since
the last counter, report-queue rows, plan lifecycle transitions, and the
commits the loop itself landed. The rubric is frozen before the data is
read - signal class, routing target, meta_value 0-4 - so the judgment
cannot be shaped by what it finds. The first run (2026-10-01..2026-10-05,
107 commits after a deterministic 58-commit mechanical prefilter,
0 failures, 0 truncations) is recorded in
docs/agent-notes/jevify-2026-10-05-state-changes.md.

Two rules make the method honest:

- Verdicts land as agent-notes evidence. A judgment that stays in a
  transcript is chatter; a judgment written to docs/agent-notes/ is a
  citable claim with a date and a job id.
- Evidence overrides model verdicts on conflict. The first run needed two
  overrides (d28e0ab1: bookkeeping read as failure; af2c08dc: trajectory
  refactor read as design pressure) - the diff is the fact, the score is
  an opinion about the fact.

## 4. Integration points

Minimal new machinery; every seam below already exists with its own
tests and budgets.

(a) Lesson-harvest delta. automation/cadence/calendar/daily/01-lesson-harvest.sh
already consumes automation/agent-handoffs.md as a delta against the
automation/.lesson-harvest-handoffs counter line (01-lesson-harvest.sh:52-56),
with 266 rows pending at audit time. The rows already carry `cause=<class>`.
The hop-2 judgment rides this delta; nothing else needs to notice it.

(b) The demand choke-point. automation/lib/causes.sh append_research_subject
(causes.sh:143) is the single append path to automation/research-subjects.txt -
all six shell appenders route through it (18-mimic-drill.sh:70,73;
25-wiki-health.sh:239; jobs/agent-respawn.sh:194;
scripts/overnight-cycle.sh:1100,1103). A bulk classifier that emits
(slug, question) pairs inherits, at zero schema change: fail-closed home
redaction, question-not-beat full-line dedup, date-blind id-prefix dedup
(strips 20xxxxxx on both sides), the filing-about-filing demotion, and the
one-new-fail-subject-per-cause-per-UTC-day budget (causes.sh:213).
CAVEAT: automation/scripts/accept-plans.py:232 holds a Python mirror of
this function; any change to the shell one must land in the mirror too.

(c) Cadence drop-in. A new automation/cadence/<tier>/NN-<name>.sh gets
timing, ordering, and dropin-fail breadcrumbs free from cadence-tick.sh
(cadence-tick.sh:106, :108 feeds the time ledger's dropin:<name> row).
The mirrors are 03-gate-check.sh (daily, both gates, fail-closed exit 0)
and 17-torch-audit.sh (weekly Audit station, report-queue rows).

(d) Report-queue identity. Findings collapse instead of spamming under an
identity prefix with an 86400 window: the precedent is
`dash-selfreview:<check> --window 86400` (dashboard-self-review.py:22-23).
A classifier's own health reports use `classify:<source>` the same way;
lib/report_queue.py gives xN bumping, evidence-token re-fire, and the
seven-day expiry ladder for free.

(e) Research row seams. Dispositions and lessons are written through
automation/lib/research-harvest.py (DISP_SCHEMA research-harvest.py:39;
one condensed lesson row per adopted verdict, keyed by line_id;
re-adoption refreshes, later non-adopted retires). Whatever the classifier
routes, it never writes these rows itself and never bypasses the
two-sided review gate (33-research-beat.sh:19-27): supportive pass,
adversarial pass, verdict, sidecar transcript. Judgment proposes;
review disposes.

## 5. First slice

Cause-stamp the unclassified agent-handoffs rows. Rows already carry
`cause=<class>`, but unknowns pile up; classify_cause (causes.sh:27) and
lesson_for_cause (causes.sh:72) already know the vocabulary. From the
lesson-harvest beat, route the rows whose class is a knowledge signal -
missing-knowledge, missing-design - through append_research_subject with a
(slug, question) pair, so a session failure becomes a research demand at
the next station instead of a digest line. The whole slice is a change to
01-lesson-harvest.sh plus one failing test first (automation/tests/),
asserting that a handoff row with cause=missing-knowledge leaves a
research-subjects.txt entry. No new ledgers. If the slice does not move
at least one row from handoff to demand, it is not a slice, it is a
rehearsal.

## 6. Meta-check

The loop's weekly audit of its own feeding - a drop-in alongside
17-torch-audit.sh, answering three questions:

(i) Did each routed lesson change outcomes? Measure cause recurrence rate
per cause class: the same class stamped twice in one week after a lesson
was routed is a lesson that did not land. This is the number the loop owes
itself; the jevify dist already claims the harvest seam matters more than
any new ledger (40 of 107 commits operational-lesson), and this is where
that claim gets tested or pays for it.

(ii) Retire the stale. research-lessons.tsv has a live status already
(109 active, 1 retired); rows whose line has since moved to a non-adopted
disposition go to retired through research-harvest.py, not by hand.

(iii) Report the five unwired descent weekly checks (descent.md:177-184)
that this machinery can cheaply cover: terminal disposition within 7 days
(plan/queue timestamps), one failure classified per week (this slice's
counter), one research line consumed (research-lessons.tsv churn), zero
write-only artifact classes (torch-ledger.tsv verdicts from 17-torch-audit),
one disposition landed as a change (disposition to commit cross-reference).
The meta-check reports; it does not enforce.

Stated honestly: NOTHING enforces the adoption gate today
(descent.md:137-138: "Today nothing enforces this; the gate is specified
here for the first time"). The meta-check can count adoptions that never
happened; it cannot make one happen. Until the gate lands, every number
in (i) is a number about a loop that is free to ignore itself.

## 7. Worked example

The loop in miniature, from the first jevify run. Commit e306830d
(2026-10-03) `git rm`'d automation/--model - a file literally named for a
flag, debris from the fake-omp test stubs whose
`printf "session output\n" > "$2"` wrote to whatever the second argument
was, including the string `--model`. The verdict said delete the artifact;
the deletion was incomplete because its generators
(automation/tests/test-agent-respawn.py stubs(), automation/tests/test-bctx-launch.py
OMP_STUB) were untouched - so the file regenerated. hygiene.py check 3
already reports such stray root-level files report-only
("e.g. a file literally named '--model'"), so the loop noticed its own
regeneration through a channel that existed before the lesson. The
generator line is now being removed from both stubs (uncommitted, in the
working tree as of 2026-10-05). The general lesson, which is what hop 2
should have extracted: artifact deletion is incomplete until its
generators are gone; delete the source of a class, not one instance.

## 8. Boundaries

- No daemon, watcher, or scheduler is added. AGENTS.md:28-29 is
  unambiguous: "Hngh is a side-effect-free local kernel. Do not start a
  daemon, service, provider, watcher, scheduler, agent, or process." The
  loop rides the existing cadence beats and choke points; every hop is a
  script another script already calls.
- Kernel src/ stays untouched. All of this lives in automation/ and docs/.
- Everything is ASCII, all paths repo-relative, and every new behavior
  arrives with its failing test first.

## Stale-doc finding

docs/design/descent.md:73-80 and docs/design/bestiary.md:76 both claim the
demand wire is "Designed, not built" - "Nothing auto-appends a
missing-knowledge or missing-design cause to the subject list". That is
stale. The wire is live: append_research_subject (causes.sh:143) is called
by six appenders including agent-respawn's missing-design path
(test-agent-respawn.py:92-99 asserts the fail- entry appears); patrol
findings queue "a research-subjects entry (house convention)"
(patrol.py:26, :1195, :1956); the demand synthesizer backstops an empty
pool below RESEARCH_DEMAND_FLOOR (33-research-beat.sh:424); and 33-research-beat
runs the two-sided review gate over what arrives. Station 3 is not broken.
Those two passages should be corrected to point at the live wire and leave
the adoption gate as the actual gap.
