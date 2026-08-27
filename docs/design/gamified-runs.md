# Gamified-run model

Status: DESIGN — P2 contract, 2026-08-27. Ceremony-ready.

Source: [`../project/master-plan.md`](../project/master-plan.md)
(DesignPlan facet: gamified runs, one run = one named character + a
story beat; the roguelike death-and-replacement rule; the honesty
leash), the 2026-08-26 affinity directive (`Self-optimization +
gamification design`), and the closed run/afterlife domain values in
[`../core/run-contract.md`](../core/run-contract.md).

Cross-links: [`buddy-menu-spec.md`](buddy-menu-spec.md),
[`command-center.md`](command-center.md),
[`autonomous-development-control.md`](autonomous-development-control.md),
[`presentation-boundary.md`](presentation-boundary.md).

## Runs as stories

A run is a short-term agentic session; the gamified model treats each
run as **one named character with a story beat** — a quest the
character mounts, works, and either completes or dies on. The story is
a rendering layer over real run fields: every event type below is
derived exclusively from the run's recorded state transitions,
receipts, certificates, and afterlives. There is no separate
narrative ledger and no free-form fiction in governance.

## Event types

| Event | Derives from (real fields) | Renders as |
|---|---|---|
| `quest` | run created + admission receipt (`:created` → `:armed`/`:running`); machine-steered course choice | character mounts the course, one caption with the objective |
| `victory` | certificate-bound commit/push completed; run closed `:evacuated` with a verification receipt | reward flourish, run page shows the certificate hash |
| `setback` | verification failure, manifest incomplete, refusal labels on any step, checkpoint refused | pause frame + the literal refusal label |
| `reward` | score-record / after-life lesson harvested (lesson-reuse), promotion record | XP-equivalent shown as the recorded fact, never invented points |
| `death` | run closed `:dead` (terminal disposition) or a session terminated by the roguelike rule | death frame; the replacement character is spawned per the roguelike rule |

The event vocabulary is fixed and closed (`quest`, `victory`,
`setback`, `reward`, `death`). An unmapped terminal state renders as
its literal state term, not a new event.

## The roguelike agent-death rule

Central to the model: when a run dies or a slice exceeds its budget,
the **session is not extended** — a fresh character (a new run) picks
up the remaining objective with the after-life lesson attached:
salvage labels, rejected hypotheses, and the lesson candidate from the
recorded `afterlife-record` (see
[`../core/run-contract.md`](../core/run-contract.md)). Death is
terminal for the session; the mission persists. The dashboard's run
page shows the death, the salvage, and the replacement.

The same rule applies where the operator already applies it: an
exhausted slice stays dead and red; a successor run inherits the
lesson, never the budget.

## The honesty leash

Any narrative field carries `perceptual:true` at the boundary that
produces it and is **rendered for display only**. Specifically:

- Narrative is never an input to governance: no event name, caption,
  or flavor enters a proposal, a certificate, a verdict, a loadout,
  or a gate.
- Narrative is never an input to selection: `perceptual` fields are
  excluded from course-selection candidates, expedite ripples, and
  scheduling computations. The machine-steered selector consumes
  only `identifier`, `mounted-p`, `last-increment-ts`,
  `priority-rank` — no story fields.
- A renderer may show a quiet display name for a run character;
  the stored run identifier and state remain canonical and are
  always shown alongside (see
  [`presentation-boundary.md`](presentation-boundary.md)).
- The buddy/OSD speech and the dashboard story lines come from the
  event table above only; a malformed or missing derivation renders
  the literal fact, never an invented event.
- Removing the gamification layer removes only display: no data
  migration, no behavior change, no gate change.

## Where events surface

- **Buddy/OSD** (`buddy-menu-spec.md`): `quest`/`victory`/`setback`/
  `death` drive the one-shot animation transitions; captions are the
  recorded facts.
- **Webapp dashboard**: run page = quest card + step breadcrumbs +
  verdict + certificate hash; the roster shows the character name
  beside the run id.
- **CLI**: `present` renders the same facts plainly, no story layer;
  `status` shows active lane and recent events as labels.

## Non-goals

- A points/level system with invented economy — `reward` is the
  recorded score/lesson fact, nothing more.
- Narrative entering any control path, now or later.
- Persisting story state outside the existing run/after-life records.
- Any change to the run lifecycle, admission, or certificate gates.

## Open questions

- Whether character names are operator-chosen per run or derived
  (stable hash of the run id) — either is display-only.
- How `setback` narration distinguishes advisory refusals
  (expected) from stalls (attention-worthy) without leaking into
  control input; the alert path already carries the distinction.