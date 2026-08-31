# alert-to-work routing patterns: closing the self-observation loop

Status: crystallized 2026-08-30 from research line `alert-to-work-routing-patterns-closing-the-self-observation-loop`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-alert-to-work-routing-patterns-closing-the-self-observation-loop.md.
Grounded rewrite 2026-08-30: the original crystallization framed Hngh
as a Linux kernel module (Netlink families, sysfs exposure, ring
buffers, kernel/user daemons). None of that exists here — Hngh is a
Common Lisp kernel plus no-daemon shell automation, and its alert
surface is an append-only report ledger. That mechanics layer is the
named foldback anti-pattern and is discarded; the loop-closing
conclusion survives and is restated in Hngh's actual shape.

## Conclusion (kept, reframed to this repo)

The self-observation loop is open in exactly one place: alerts are
generated and deduplicated, but nothing records whether the work they
named was ever scheduled, done, or was noise. The loop closes not by
adding a transport but by giving every alert class a **parseable
plan-step candidate** — because in this system the only thing that
turns observation into work is an accepted plan (foldback lesson 2:
alerts close their own loop only through plans; every repair in the
33h window originated in a plan step or an operator session, never
from the alert itself).

The routing shape, using only what exists:

- **Alert emission** — jobs and ticks append `alert` rows to the
  report ledger (`scripts/report-queue add alert …`), each row
  carrying a kind, an id, and a first line naming the producer
  (oversight loop-signal, gate-check, tree-skew, agent-stall,
  ceremony-temp, review findings, slow-unit).
- **Candidate emission** — a routing table maps each alert class to a
  plan-step candidate: title, verification command, risk class
  (normal → plan step; critical-class → parked with operator-facing
  alert, per the plan contract). The candidate lands in
  `docs/project/plans/` as a proposed plan or an appended step on an
  open plan — the two authoring surfaces the machine already has.
- **Outcome tracking** — the plan lifecycle already records the
  outcome: a step's checkbox tick and the front-matter status
  transition (proposed → accepted → executing → executed/parked) plus
  the reports rows the execution writes. Alert → step → tick/rows =
  closed loop; no new state store is needed at check-in scale
  (`docs/project/plans/README.md` defines the machine-checkable
  states).

## Findings (grounded rewrite)

- **F1 — alerts are honest but terminal.** The 2026-08-28→30 window's
  alert classes (stale-store ceremony-temp, review P0/P1, tree-skew,
  agent-stall, unparsable readout.json, doc-suite checker rc=1,
  remote-posture degraded, budget digests) were accurate; every one of
  their fixes still originated in a plan step or an operator session.
  The ledger records the signal; nothing routes it into the plan
  queue.
- **F2 — the flap-suppression layer is already the dedup layer.**
  Oversight alerts arrive flap-suppressed (roadmap stage 1: alerts are
  "flap-suppressed") and report-queue already has identity+window
  dedup with escalation caps (backlog row). So the loop does not need
  new suppression machinery — a routed candidate only needs to exist
  once per alert identity, which the existing dedup already
  approximates.
- **F3 — candidate authoring is the missing edge, and it is the same
  gap as plan authoring itself.** The machine cannot author plans
  (foldback lesson 1 / suite doc 08 R2); a routing table that emits
  *draft plan steps* (title + verification + risk class as parseable
  text) feeds the night-agent plan-authoring row rather than replacing
  it: routing proposes, a plan-shaped surface accepts.

## Recommendation (the designed mapping, docs-only)

Map alert classes actually filed in `docs/project/reports.md` to
candidate step shapes:

| alert class (observed) | candidate step shape | risk |
|---|---|---|
| gate-red (kernel or automation) | re-run gate, capture failing check, fix-or-park step | normal |
| tree-skew dirty-tree | whitelist check + handoff/commit of stalled edit | normal |
| agent-stall / loop-signal | roguelike die+replace: end session, handoff brief, respawn step | normal |
| ceremony-temp / store alerts | re-run ceremony fresh-store step (known recovery) | normal |
| review P0/P1 findings | docs/automation fix step with named verification | normal |
| unparsable readout.json | feed-regen re-read step (fix already landed as precedent) | normal |
| remote-posture degraded / budget idle | operator-facing alert row; PARKS (operator-only legs) | critical |

Each candidate step carries its own verification, so a plan built from
the table is auto-acceptable per the plan contract when the gates are
green. Implementation of this table as automation-side routing (a
read-only tick that drafts the candidates) is follow-on work only if a
plan asks for it — it needs no kernel changes.

## Open threads

- Where draft candidates live: a section in `docs/project/plans/README.md`
  vs a queue-ledger column (design decision for the routing DESIGN beat).
- Escalation caps interplay: a routed alert must not re-fire while its
  plan step is open (dedup window vs plan lifecycle).

## Grounding

Verified paths read in this repo while rewriting (2026-08-30):

- `docs/project/reports.md` — the live alert ledger (gate-red,
  tree-skew, agent-stall, loop-signal, slow-unit, ceremony-temp,
  review, remote-posture, budget-digest rows all observable there)
- `docs/project/roadmap.md` — stage 1 self-watch (flap-suppressed
  oversight alerts), stage 3 self-supervision framing
- `docs/project/backlog.md` — "Alert → plan-candidate routing" and
  "Night-agent plan authoring" rows; report-queue escalation caps row
- `docs/records/2026-08-30-lessons-and-foldback.md` — lesson 2
  (alerts close their own loop only through plans) and §1's failure
  classes
- `docs/project/plans/README.md` — the plan contract the candidates
  must parse into (status lifecycle, risk classes, auto-acceptance)
- `hngh-automation/jobs/oversight-tick.sh` and
  `hngh-automation/scripts/report-queue` — the producers of the alert
  rows the table routes (verified present; identities observed in
  reports.md)

Discarded as ungrounded (the original crystallization's mechanics):
kernel modules, Netlink generic families, sysfs/tracepoint exposure,
userspace daemons. Hngh has no kernel module; its alert surface is the
report ledger.

## Open-thread resolutions (2026-08-31)

Both threads from `## Open threads` resolved with source evidence; authored 2026-08-31 against the plan-mandated 2026-08-30 filename. No code was written in this beat.

### Thread 1 — where draft plan-step candidates stage

**Resolution: the plan directory (`docs/project/plans/*.plan.md`), not a queue-ledger column.**

The decision is fixed by what the actual selector consumes:

- `hngh-automation/scripts/overnight-cycle.sh` (selector (a), lines
  186-199) iterates `$KERNEL/docs/project/plans/*.plan.md`, keeps files
  whose front-matter greps `status=accepted`, and takes the first
  `^\- \[ \]` line as the next step. Any staging surface the selector
  does not scan is dead storage for candidates — nothing else reads a
  queue-ledger column into plan execution.
- The plan contract (`docs/project/plans/README.md`)
  already defines the accepted authoring surface: a proposal is a
  `<date>-<slug>.plan.md` file with `status=proposed` written into the
  directory (its omp-plugin section describes exactly this path for
  non-automation authors). Auto-acceptance per the contract converts a
  gated normal-risk candidate into a `status=accepted` plan — the
  selector then picks it up with no further machinery.
- The queue ledger is the wrong shape for candidates:
  `docs/project/queue.md` is a fixed 4-field TSV (`id status title
  evidence`) and its own `## ETA` section records that even planned
  windows stay outside the TSV; `scripts/rotate-queue` rotates that
  ledger through full rotation sessions, a different instrument from
  per-alert step candidates.

So the routing recommendation's two authoring surfaces hold as stated:
a batch of candidates becomes one `status=proposed` plan file (the
append-an-step-to-an-open-plan variant appends a `- [ ]` line to an
existing accepted plan — the same selector line it is consumed by).
A queue-ledger column is rejected: no consumer exists for it.

### Thread 2 — escalation caps / dedup windows vs open plan steps

**Resolution (mechanism as it stands): the dedup window is wall-clock
only and cannot span a plan step's lifecycle today.**

From `scripts/report-queue` source (`add()`, lines 178-205; `row_identity`,
`within_window`, `bump_row`):

- Dedup matches on KIND + stored `identity:` in the row's body meta,
  newest rows first, within `--window` seconds (default 86400; 0 =
  unlimited lookback). A match folds the occurrence into the existing
  row (×N marker + `- <ts> occurrence` body line); no new row appears.
- The window compares the row's original timestamp against wall-clock
  time only. report-queue never reads `docs/project/plans/*.plan.md`;
  no parameter or command ties an identity to plan state. A plan step
  staying open past 86400 s therefore does NOT suppress its alert —
  the identity simply ages out of the window and the next occurrence
  files a fresh row.

**Minimal coupling that IS available in the current source: identity
naming the plan step.** The identity is an opaque stored string, so a
router can make it carry the candidate's target, e.g.
`<alert-class>:plan:<slug>` or `<alert-class>:plan:<slug>:<step-N>`,
and file with `--window 0` (unlimited lookback). With window 0 the
identity matches its one row forever, so the alert never re-fires as a
new row while (or after) the step is open — occurrences still fold in
and stay visible. That satisfies "must not re-fire while open" with
zero kernel or report-queue changes.

**Parked, needs: identity expiry or router-side plan-state check.**
Window 0 suppression is permanent for that identity — a new defect
instance of the same class after the plan step closes would fold into
the old row rather than draft a fresh candidate. Re-arming requires one
of two concrete mechanisms, neither present in source:

1. A per-identity expiry in report-queue (e.g. an `--expire IDENTITY`
   path that drops or re-dates the stored identity) — a report-queue
   change, out of scope for this beat; or
2. A router-side pre-check before `--add`: read the plan file named in
   the identity and skip emission while the named `- [ ]` step still
   exists (the same grep the selector already runs, so the pattern is
   proven). That is an automation-side change and the recommended
   instrument — it keeps the dedup semantics untouched and makes the
   suppression exactly the plan lifecycle.

Until the router tick exists, the standing statement is: the default
86400 s window is the flap-suppression layer and does not consult plan
state; the coupling above is the designed fix, parked behind the
routing-tick implementation beat.

## Outcome tracking without kernel changes (2026-08-31)

Third beat on this doc. The routing table specifies how a candidate is
authored; the resolutions above fix where it lives and how it dedups.
What nothing yet fixes is how the loop proves it closed: which fields
record routed → attempted → closed, and where each is captured. This
section is that field set, automation-side only, grounded in what
`hngh-automation` writes today. No router tick exists yet (a grep of
`scripts/`, `jobs/`, `cadence/` for routing/router matches nothing);
fields marked *today* already have their capture point in running code,
the rest are the contract that tick must meet.

### The fields

**1. `routed-from` — alert identity → plan-step linkage.**
For a whole-plan draft: a `routed-from=<identity>` attribute appended
inside the existing front-matter comment. Both machine parsers tolerate
a trailing attribute — `scripts/accept-plans.py:32-33` and
`jobs/plan-feed.py:21-22` compile their FRONT regex with `[^>]*-->` as
the tail — so adding the attribute breaks neither acceptance nor the
dashboard plans feed. For an appended `- [ ]` step on an open plan: a
`routed-from=<identity>` tail on that step's indented `Verification:`
line — `accept-plans.py:34` only checks that such a line exists
(`(?m)^[ \t]+Verification[ \t]*:`), its content is free, and the line
is not part of the step text the selector strips into the objective
(`scripts/overnight-cycle.sh:193` strips only the `- [ ]` line).
Example: `routed-from=gate-check:hngh-automation` on a gate-red
candidate. No new store: the linkage lives in the candidate itself.

**2. `routed-at` — when the candidate was authored.**
The routing tick files the same row shape the draft flow already uses
(`overnight-cycle.sh:180-183`: `--add progress "..." --identity
"overnight:plan-draft:$day" --window 86400`), with identity
`router:routed:<slug>[:<step-N>]`, plus a STATE.md breadcrumb in the
existing `lib/breadcrumbs.sh` pattern (`overnight-cycle.sh:179` files
`plan-drafted` the same way). Example: a reports.md progress row
`router:routed:2026-08-31-gate-red` at `2026-08-31T03:14:07Z`. This is
F1's repair: the routing moment becomes a ledger row, not a memory.

**3. `first-attempt-at` — the cycle picked the step up.**
Captured today, zero new code: the `WAKE CONTEXT` timestamp written
into `prompts/overnight/$slug.md` (`overnight-cycle.sh:205-210`), the
session-run row `overnight|<slug> | session-run` in
`logs/budget.md:310-311`, and the
`overnight-lead | <ts> | <slug>|<run_id> | rc=<N> <disposition> log=<path>`
row in `agent-handoffs.md:337-339`. Example:
`overnight-lead | 2026-08-31T03:20:11Z | 2026-08-31-foo|run-42 | rc=0
evacuated log=logs/overnight-2026-08-31-foo-032011.log`.

**4. `closed-at` — the step finished.**
Captured today: the step's `- [x]` tick in the plan file; when no
unchecked step remains, `overnight-cycle.sh:317-321` flips
`status=accepted` to `status=executed` in the plan front-matter and
files the `plan <slug> executed (all steps checked)` progress row.
Example: `2026-08-31T03:47:52Z | plan 2026-08-31-foo executed (all
steps checked)` in reports.md plus the flipped front-matter.

**5. step outcome class — one existing row per class.**
Landed = `- [x]` on the routed step (front-matter flip above).
Parked = `park()` (`overnight-cycle.sh:73-78`): alert row identity
`overnight:parked:<slug>` plus the
`operator-attention | <ts> | overnight|<slug> | parked: ...` handoff
row; also `accept-plans.py:146-148` for critical-class plans
(`overnight:plan-critical:<slug>`). Refused =
`overnight:bridge-refused:<slug>` (`overnight-cycle.sh:290-291`),
`overnight:critical-touch:<slug>` (`:333-334`), and accept-plans'
blocked rows `overnight:plan-accept-blocked:<slug>` and
`overnight:plan-accept-gate:{kernel,automation}`
(`accept-plans.py:157-159, 168-177`); a non-zero session rc also shows
as `disposition=dead` in the budget row. No-candidate = selector (a)
falling through (`overnight-cycle.sh:186-200`) into the research beat
breadcrumb (`:271`); a routing tick files its own no-candidate
breadcrumb here since it is the one class with no dedicated row today.
Duplicate-skip = field 6.

**6. the duplicate-skip event — what router-rearm-precheck needs
observable.**
The backlog row (`docs/project/backlog.md`, "Router-side re-arm
pre-check (router-rearm-precheck) — queued 2026-08-31") parks on
"one closed-step re-fire is demonstrably skipped". The skip is
currently unobservable: dedup is wall-clock only (thread 2 above), so
a re-add after the named step closes looks identical to a first fire.
Spec: before the router's `report-queue --add`, it consults plan state
with the same two greps the selector already uses
(`overnight-cycle.sh:192-193`: `status=accepted` in the front-matter,
an unchecked `- [ ]` step); when the identity's named step is closed
it skips the add and files exactly one observable pair —
a STATE.md breadcrumb `router | duplicate-skip | <identity> step
already closed` and a deduped alert row
`--add alert "router duplicate-skip: <identity> (named step closed;
candidate not re-drafted)" --identity "router:dup-skip:<identity>"
--window 86400`. The alert row is the operator-visible leg: the
operator panel reads only digest bullets and STATE.md breadcrumbs
whose event matches `alert` or the papercut/flagged/needs/operator
keywords (`jobs/operator-items-feed.py:91-93`), so a breadcrumb alone
would be invisible there. No router-internal state is kept — the skip
decision is re-derived from the plan file each time, exactly as the
backlog row asks.

### Not established

- No router tick exists in hngh-automation today; `routed-from`,
  `routed-at`, and the duplicate-skip pair are capture contracts for
  it, not running behavior. Fields 3-5 and the parked/refused rows are
  verified in current code.
- No producer writes a `routed-from=` front-matter attribute or
  Verification-line tag yet. Parser tolerance is established from the
  two regexes; a round-trip of a tagged plan file through
  `accept-plans.py` and `plan-feed.py` has not been exercised.
- No dashboard surface consumes routing state: `dashboard/plans.json`
  (`plan-feed.py:45-52`) carries only
  slug/status/risk/accepted/steps counts, and
  `jobs/operator-items-feed.py` reads only digest bullets and
  STATE.md breadcrumbs. Whether routed-outcome panels are wanted is an
  operator decision.
- Whether `report-queue --json`'s unread count can distinguish alert
  kinds is not established from the automation side:
  `overnight-cycle.sh:206-207` consumes the bare count only.

### Grounding

All paths below verified with `test -f` on 2026-08-31 (~/-form;
line numbers as read this beat):

- `~/Projects/etc/hngh-automation/scripts/overnight-cycle.sh` — OK.
  Verified call sites: `:64-67` `file_alert()` (alert rows,
  identity+window 604800); `:73-78` `park()`; `:180-183` plan-draft
  progress row; `:186-200` selector (a), with `:192`
  `grep -q "status=accepted" "$f"` and `:193`
  `step="$(grep -m1 '^\- \[ \]' "$f" | sed ...)"`; `:205-210` wake
  timestamp + `:206-207` `report-queue --json` unread read; `:290-291`
  bridge-refused alert; `:310-311` budget session-run row; `:317-321`
  executed flip + completion row; `:333-334` critical-touch alert;
  `:337-339` overnight-lead handoff row; `:342` overnight-done
  breadcrumb.
- `~/Projects/etc/hngh-automation/scripts/accept-plans.py` — OK.
  `:32-33` FRONT regex (trailing `[^>]*-->`), `:34` VERIFICATION
  regex, `:44` report-queue path, `:93-103` report() call shape,
  `:146-148` critical park, `:157-159` blocked-acceptance alert row,
  `:168-177` gate-red acceptance alerts, `:185-187` accepted progress
  row.
- `~/Projects/etc/hngh-automation/jobs/agent-supervision.py` — OK.
  `:216-221` report(); `:323-327` `supervision-evicted:<id>`, `:346-348`
  `agent-stall:<id>` alert, `:351-353` `agent-stall-recovered:<id>`
  flap row — the alert classes a router must link.
- `~/Projects/etc/hngh-automation/jobs/oversight-tick.sh` — OK.
  `:49-70` alert() (kind+detail, --identity/--window), `:80` stale-store,
  `:101` system flags, `:126` tree-skew, `:175-180` gate-red,
  `:326` rendered-surface, `:353` slow-unit, `:411` repeat-crumbs,
  `:414` loop-signal.
- `~/Projects/etc/hngh-automation/jobs/plan-feed.py` — OK. `:21-22`
  FRONT regex, `:45-52` plans.json fields (no routing state today).
- `~/Projects/etc/hngh-automation/jobs/operator-items-feed.py` — OK.
  `:91-93` is_operator_item() event/keyword filter.
- `~/Projects/etc/hngh-automation/lib/breadcrumbs.sh` — OK (the
  breadcrumb pattern cited for routed-at).
- `~/Projects/etc/hngh-automation/STATE.md` — OK (breadcrumb ledger).
- `~/Projects/etc/hngh-automation/agent-handoffs.md` — OK
  (overnight-lead / operator-attention rows).
- `~/Projects/etc/hngh-automation/logs/budget.md` — OK (session-run
  rows).
- `~/Projects/etc/hngh-automation/dashboard/plans.json` and
  `dashboard/operator-items.json` — OK (checked as consumers; neither
  carries routing state).
- `~/Projects/etc/hngh/docs/project/backlog.md` — OK
  (router-rearm-precheck row, "queued 2026-08-31").
- `~/Projects/etc/hngh/docs/project/reports.md` — OK (the alert/
  progress ledger every field above lands in).
- `~/Projects/etc/hngh/scripts/report-queue` — OK (identity/window
  mechanics already specified in Thread 2 above; not re-derived here).
