# honest gamification mechanics: every stat from a named real field

Status: crystallized 2026-09-01 from master-plan section 4 research backlog
(line: honest gamification mechanics) and the DesignPlan "Gamified runs"
bullet it elaborates. No code was written in this beat; the kernel `src/`
tree was neither read nor touched.

Evidence basis: real repo surfaces read in targeted ranges on 2026-09-01
(every cited path passed `test -f`; see Grounding). Short quotes are
verbatim from the named files; paraphrase is marked. Anything without a
named real field is listed under Not established rather than guessed — a
hallucinated source line is this repo's named anti-pattern, and the
public-content gate (absolute home paths, credential shapes, eval/exec) is
pre-flighted before ceremony per `docs/project/lessons-2026-08-31.md`.

---

## 1. What the backlog line actually asks

Verbatim, `docs/project/master-plan.md` §4 (DesignPlan facet):

> **Research backlog (must precede the fun builds)** — buddy
> summoned-not-nagging menulearning; handoff-brief schema; the
> steer-vs-die threshold; self-hosting prior art; which biological
> abstractions are concrete vs branding; honest gamification
> mechanics. Each ties to a build rung.
>
> **Gamified runs** — one run = one named character + a story beat;
> real events (quest/victory/setback/death/reward) rendered only from
> real run fields; narrative tagged `perceptual:true` and **never**
> enters governance (the honesty leash).

The question the backlog names: which game mechanics can this system
render honestly today — each backed by a named field that already exists —
and which are parked because their field does not exist yet or would need
kernel `src/` changes.

## 2. What honesty means here (the leash, grounded)

`docs/design/gamified-runs.md` (P2 contract, ceremony-ready) fixes the
shape, and this doc adds nothing to it:

- The story is a rendering layer over real run fields: every event type
  is derived exclusively from the run's recorded state transitions,
  receipts, certificates, and afterlives. There is no separate narrative
  ledger and no free-form fiction in governance (its "Runs as stories").
- Narrative is never an input to governance: no event name, caption, or
  flavor enters a proposal, a certificate, a verdict, a loadout, or a
  gate; never an input to selection either — the machine-steered selector
  consumes only `identifier`, `mounted-p`, `last-increment-ts`,
  `priority-rank` (its honesty-leash bullets).
- A malformed or missing derivation renders the literal fact, never an
  invented event; the event vocabulary is fixed and closed (`quest`,
  `victory`, `setback`, `reward`, `death`) and an unmapped terminal state
  renders as its literal state term.
- Kernel-side, evidence is structurally non-authoritative: receipt,
  score, and afterlife records "cannot start a run, change lifecycle
  state, or grant authority" (`docs/core/run-contract.md`, "Evidence is
  non-authoritative"). The roguelike review says the same thing as
  policy: "Scores inform tuning; they never authorize an action or punish
  a model" (`docs/research/2026-08-11-clean-architecture-roguelike-run-review.md`
  guardrail 6).

What governance actually rides on today, verified in the ledgers: green
gates plus certificate-bound commits. `docs/project/reports.md` row
`b2c9f16e` (2026-09-01T00:31:18Z): "plan 2026-09-01-overnight-continuity
auto-accepted (normal-risk, verification runnable, both gates green)".
`docs/journal/2026-08-31.md`: "4 commits before the wrap; 4
candidate-bound". `~/Projects/etc/hngh-automation/agent-handoffs.md`:
"make test green pre+post (2855 checks)". No story field appears in any
of those decisions.

## 3. One run = one named character

- The character IS the run. Kernel: the `Run` value is an identifier plus
  a mission, role-template, and loadout snapshot
  (`docs/core/run-contract.md` Values table). Automation: the handoff
  ledger names runs `2026-08-30-overnight-continuity|run-1` and `|run-2`
  — the run identifier and slug are the real name.
- Capability, not personality: a character is a versioned role template;
  "A 'Killy' or 'Cibo' skin may appear in rendered text; the
  machine-readable role remains a narrow capability record" (roguelike
  review guardrail 3). A display name must always render beside the
  canonical run identifier (design cross-link
  `docs/design/presentation-boundary.md`).
- Die-and-replace is already recorded as fact: the automation handoff
  ledger's own header is "roguelike death-and-replacement record", and
  the design repeats the rule — "an exhausted slice stays dead and red; a
  successor run inherits the lesson, never the budget".

## 4. Mechanics → verified fields

The five closed events, mapped to what exists on each plane. Kernel
fields are the domain contract in `docs/core/run-contract.md`; automation
fields are live capture points read this beat.

| mechanic | kernel field (contract) | automation field (live today) |
|---|---|---|
| `quest` | run starts in `created`; Mission value carries objective, non-objectives, source references, acceptance criteria, writable scopes, verification, evacuation condition | accepted plan with unchecked `- [ ]` steps (auto-accept row `b2c9f16e`, "both gates green"); quest-mount = the `overnight\|<slug> \| session-run` row in `~/Projects/etc/hngh-automation/logs/budget.md` |
| `victory` | transition `running`/`checkpointed` → `evacuated`, then `afterlife` → `scored` → `archived` (closed FSM, every unlisted pair signals `invalid-run-transition`) | handoff row `rc=0 evacuated log=...`; plan flip to `status=executed` with the "plan <slug> executed (all steps checked)" progress row; certificate-bound commit + push range in the journal (`1754cb9` "candidate dcd92507...", "pushed 5f0a0a2..1754cb9") |
| `setback` | verification failure, manifest incomplete, refusal labels on any step, checkpoint refused (design event table); narration must keep advisory refusals distinct from stalls (design open question) | `\| alert \|` rows in `docs/project/reports.md` (e.g. loop-signal "STATE 3x identical crumb"); plan-accept blocked identities `overnight:plan-accept-blocked:<slug>` / `overnight:plan-accept-gate:{kernel,automation}` |
| `death` | `dead` terminal state (legal from `created`/`armed`/`running`/`checkpointed`); Afterlife record: terminal cause, observed facts, salvage labels, rejected hypotheses, one lesson candidate | `~/Projects/etc/hngh-automation/agent-handoffs.md` — the roguelike death-and-replacement record; `jobs/agent-watchdog.sh` on the 5m oversight tick detects a death signal and records LOG-ONLY handoffs; a real death with cause is on file: "The 20:00Z beat died (rc=124, 30m kill) 14s after landing its ceremony commit" (`docs/project/lessons-2026-08-31.md`) |
| `reward` | Score record: delivery, cost, headroom, turnaround, lesson reuse (contract Values table); XP-equivalent "shown as the recorded fact, never invented points" (design event table) | afterlife lesson candidates harvested automatically into `docs/project/lessons-2026-08-31.md` (lesson-harvest.sh, 09:00Z; a lesson becomes policy only after review); measured stats with named fields in `~/Projects/etc/hngh-automation/dashboard/time-ledger.json` |

Character-sheet stats that honestly render today, every number a named
field: per-unit `last_wall_s`, `runs_24h`, `p50_s`, `max_s`
(time-ledger.json `units[]`); session-run rows in budget.md; ceremony
commit counts per wake (the journal's "machine-checked" ledger section);
gate state (kernel/automation test suites green or red). The ledger also
proves honesty scales down: a quiet day is rendered as a fact, not
hidden — reports.md 2026-08-27: "Nothing committed, checked, or rotated
on this date — the ledger is quiet. That is also a fact."

## 5. Parked-by-design (needs kernel `src/`, machine-forbidden)

- **Score-record persistence.** The Score record exists as a domain
  value with closed fields, but no scored-run instance exists yet:
  time-ledger.json's `ceremonies` array is empty (length 0 as read
  2026-09-01), and the run contract parks persistence itself ("Filesystem
  persistence and concrete adapters remain out of scope until those
  contracts are tested"). A renderer must show that as none, not invent a
  row. Wiring score capture = kernel-side work → parked-by-design.
- **Any points/level economy.** Explicit design non-goal: "`reward` is
  the recorded score/lesson fact, nothing more"; "level" is an authority
  tier, operator-gated, never a progression ladder (roguelike review
  guardrail 4: "A model cannot level itself up").
- **Any narrative persistence or control-path use.** Design non-goals:
  "Persisting story state outside the existing run/after-life records";
  "Narrative entering any control path, now or later".

## 6. Not established

- **Character display names.** An explicit open question in the design
  (operator-chosen vs stable hash of the run id); today only the run
  identifier and slug exist as real names.
- **Streaks, XP, ranks, tiers-as-rewards.** No field anywhere in either
  repo renders these; inventing one would violate the leash. Streak-like
  series must be derived from real timestamps (e.g. consecutive
  `session-run` rows, cadence tick rows) if ever wanted.
- **Budget-row dispositions.** `logs/budget.md` as read today carries
  3-field rows (`timestamp \| name \| session-run`); a grep for
  dead/evacuated/disposition over the file returns zero matches. rc and
  disposition live in the handoff ledger rows (`rc=<N> evacuated log=...`),
  which is the field a death/victory renderer should cite.
- **System/session/roster character stats.** The master plan names this
  honest gap itself (§1: "the domain models only *runs* (no
  system/session/roster values)"); R1 observables are the future field
  source, nothing renders them today.
- **Scored-run instances.** See §5 — the transition exists in the FSM;
  no example row exists yet.

## Anti-scope

This is a research doc, not narrative authoring and not a feature
proposal: no code, no plan steps, no runtime changes. Every mechanic
above is stated as "derives from field X, renders as Y" or marked parked.
The design doc (`docs/design/gamified-runs.md`) already owns the
contract; this doc grounds it in what the ledgers can feed it today.

## Batched landing

This doc is an uncommitted working-tree research artifact; it rides the
next certificate ceremony and is landed by the orchestrator (no machine
git operations in the kernel repo). No code was written in this beat.

## Grounding

All paths verified with `test -f` on 2026-09-01 (kernel paths
repo-relative; automation paths in ~/-form):

- `docs/project/master-plan.md` — PASS; §4 backlog + gamified-runs
  bullets quoted verbatim (lines 73–81).
- `docs/design/gamified-runs.md` — PASS; read in full (103 lines): event
  table, honesty leash, surfacing points, non-goals, open questions.
- `docs/core/run-contract.md` — PASS; read in full (57 lines): Values
  table (Run/Mission/Role template/Loadout/Receipt/Score record/Afterlife
  record), lifecycle FSM, "Evidence is non-authoritative", "Next
  boundary".
- `docs/design/presentation-boundary.md` — PASS; cited as the design's
  cross-link for canonical-identifier display (not read beyond
  existence).
- `docs/research/2026-08-11-clean-architecture-roguelike-run-review.md`
  — PASS; guardrails 3, 4, 6, 7 and the run-FSM section quoted.
- `docs/research/2026-08-31-buddy-summoned-not-nagging-menu-learning.md`
  — PASS; structure conventions and its "not established" discipline.
- `docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md`
  — PASS; run-event surface (alert/progress rows, plan-step lifecycle
  fields, outcome classes) reused as the automation-side field source.
- `docs/journal/2026-08-31.md` — PASS; candidate-bound commit counts,
  "book of the day" (read lines 1–50).
- `docs/journal/2026-09-01.md` — PASS; ceremony commit + router-tick
  demonstration rows (read lines 1–34).
- `docs/project/reports.md` — PASS; row shape `| timestamp | kind | id |
  first line | body |`, alert/progress examples, auto-accept row
  `b2c9f16e` (lines 1–43 + 546).
- `docs/project/lessons-2026-08-31.md` — PASS; read in full: the rc=124
  death record, ceremony-drive/gate pre-flight lesson, harvest format.
- `~/Projects/etc/hngh-automation/STATE.md` — PASS; breadcrumb format
  "ISO-8601 UTC timestamp | job | event | detail", appended exclusively
  by lib/breadcrumbs.sh (lines 1–15).
- `~/Projects/etc/hngh-automation/logs/budget.md` — PASS; 15
  `session-run` rows, 3-field shape; zero grep matches for
  dead/evacuated/disposition (basis for a Not-established item).
- `~/Projects/etc/hngh-automation/agent-handoffs.md` — PASS; header
  "roguelike death-and-replacement record", watchdog description, rc /
  evacuated / log= rows, executed-plan row with 2855-checks gate.
- `~/Projects/etc/hngh-automation/dashboard/time-ledger.json` — PASS;
  structure inspected: `{generated_at, units[], ceremonies[]}`; units[0]
  keys `unit, last_wall_s, runs_24h, p50_s, max_s`; `ceremonies` empty.
- `~/Projects/etc/hngh-automation/jobs/agent-watchdog.sh` — PASS;
  existence verified (death-signal detector cited by the handoff ledger
  header; not read beyond existence this beat).
