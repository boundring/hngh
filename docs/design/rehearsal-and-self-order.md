# Rehearsal and self-order — the kernel dreams before it acts

Status: DESIGN — operator direction, 2026-09-09.

Cross-links: [autonomous-development-control.md](autonomous-development-control.md)
(governance doctrine), [work-visualization-direction.md](work-visualization-direction.md)
(the work graph), [../records/2026-09-09-operator-flexibility-doctrine.md](../records/2026-09-09-operator-flexibility-doctrine.md)
(policy fluidity, meta-optimization), [presentation-direction.md](presentation-direction.md)
(voice rules).

> A certificate that has never been refused has never been tested.

## Premise

Hngh already runs its governance loop on stores that nobody keeps:
`scripts/omp-bridge` drives `scripts/ceremony-drive` under a global
flock from a fresh `/tmp/hngh-cer-<ts>-<rand>` store, and every
automation harness does the same (`lib/hngh-record.sh` records why:
identifiers are per-process and always start at `run-1`, so a fresh
store per run is what makes `create-run` + `close-run` succeed). The
loop is cheap because its store is disposable. Nothing in that loop
touches the repository until `mutation-check` executes the
certificate-bound Git command.

That asymmetry is the whole idea. The loop up to the verdict is pure
evaluation over immutable values; only the tail mutates. Rehearsal
runs the loop with the tail removed, and calls the result a dream.

## The rehearsal lane

A rehearsal beat re-runs the closed loop, stop for stop, against a
scratch store:

1. **create-run + admit-transport** on a temp store (`/tmp/hngh-dream-<ts>`
   by convention). Store-local by construction; the existing
   ceremony-store hygiene in `automation/scripts/overnight-cycle.sh`
   already sweeps `/tmp/hngh-cer-*` older than 35 minutes, and the
   dream store joins that sweep.
2. **propose** — the deterministic ten-principle evaluation in
   `hngh.main:dispatch-command`. The evaluator receives immutable
   values only; it does not inspect a repository, process, clock, or
   network. A dream's propose is exactly as trustworthy as a real
   one, because it is the same code on the same evidence shape.
3. **issue-cert prepare-candidate, then stop** — the certificate
   binds candidate paths, content hash, and base revision, and
   issuing it is store-side only. The mutation executor is never
   invoked in a dream: `mutation-check` would run the
   certificate-bound Git command against the real repository, so
   even prepare-candidate waits for the real drive. The dream
   instead reports the exact commands the real drive would run, and
   beat 4 evaluates the candidate content without the executor.
4. **make test in an isolated git-archive tree.** `git archive HEAD`
   (plus the candidate files) unpacks into a temp dir and the gate
   runs there. The precedent is already in the ledger: the
   2026-09-02 routed-review wake proved a red working-tree test green
   in an isolated `git archive HEAD automation` copy, and the
   2026-09-09 kernel-gate-red-rc2 and automation-gate-red-rc2 blocks
   (2026-09-09-automation-schedule-optimization.plan.md, step 5) are
   load-correlated — parallel delegated sessions compiling SBCL on
   the same host interfere with gate subprocess runs. An isolated
   tree keeps gate pre-validation out of that contention instead of
   hoping the schedule cooperates.

### Zero side effects, stated as invariants

- No push: ceremony-drive's post-commit push leg is skipped by
  construction, never by an ignored failure.
- No progress-ledger writes: `docs/project/reports.md`, `plans.json`,
  and `queue.md` are untouched by a rehearsal. The dream's only trace
  is a breadcrumb row (machine ledger, append-only) recording that it
  ran and what it concluded — a fact for oversight, never a claim on
  the queue.
- No plan-file mutation: the acceptance sweep, the cycle's step
  ticking, and the curator (below) own plan front matter. A rehearsal
  never writes there, even when its verdict would justify it.
- No daemon: a dream is one cadence-driven one-shot. The clock stays
  the operator's cadence tree.

### Dreams and the fail-closed rule

Dreams are rehearsal beats run during idle capacity — the hour
cadence's spare window, the heartbeat's quiet stretch. They produce
evidence, and evidence has exactly one use: it is filed. A rehearsal
refusal files an alert row quoting the refusal text verbatim (the
2026-08-28 ceremony-loop lesson: refusal surfaces carry the refusal
reason), and the row routes through `scripts/router-tick.py` like any
other alert.

What a refusal must never do is suppress the real action's governance.
The real ceremony re-proposes with fresh evidence; the dream is not
its gate, its shortcut, or its excuse. The doctrine's non-goal stands
verbatim: no claim that a record or evidence report authorizes a
future action. A dream is a report about a future action, nothing
more — the future action still pays full price at the real gate.


## Self-ordering: the curator beat

A periodic curator beat reads the work graph
([work-visualization-direction.md](work-visualization-direction.md)):
nodes are plans, steps, and queue rows; edges are unlocks, feeds, and
parked-because. The graph already has one builder planned in the feed
layer; the curator is its first consumer that acts instead of renders.

The curator has exactly four verbs, each grounded in an existing
mechanism:

1. **Reorder.** Set `priority=high` in accepted-plan front matter,
   per the selector key defined by schedule-optimization step 2. This
   is the same edit today's sweep made when flagging the
   omp-hngh-integration plan; doctrine section 3 (meta-optimization)
   is the standing authorization for choosing which plans earn it.
2. **Merge.** Propose parking duplicate-scope plans as superseded,
   with the evidence inline — the router disposition convention
   (`cause=`, `reason=`, `disposed=` front-matter fields; see the
   2026-09-03 routed-plan headers). The 2026-09-09 disposition
   sweep's guardrails apply unchanged: never touch `risk=critical`,
   already-parked plans, or plans whose premise has no
   counter-evidence; when in doubt, leave it live.
3. **Hand off.** Flag plans whose execution profile fits the deck
   node (Phase 3 research beat per `automation/docs/DECK-NODE.md`) as
   operator-items or front-matter annotations naming the node.
4. **Stage enabling work.** Annotate depends-on edges in execution
   notes so the selector and the gantt render the true order, and
   let enabling work jump ahead per doctrine section 3. This is
   annotation, not queue surgery: the selector still reads filename
   order and priority keys; the curator only maintains the keys and
   the edges.

### Everything through the gates

The curator edits plan front matter exactly the way today's
disposition sweeps do: as repository mutations landed through
`scripts/ceremony-drive` with a green `make test`, one candidate
slice per beat. It never bypasses `accept-plans.py`, never flips
statuses outside a certificate, never edits a plan whose acceptance
it did not first re-read from disk. When a curator judgment exceeds
its four verbs, it files an operator-item instead — one-word-answerable,
per doctrine section 4 — and waits. Curiosity is cheap; authority is
not.

## Boundary: what simulation must never do

| Never | Why |
|---|---|
| Write to real stores (`~/.hngh`, `~/.hngh-automation/store`) | Dreams run on `/tmp` stores only; a shared store also collides on the per-process `run-1` identifier. |
| Touch `~/.hngh` | The kernel-side boundary is absolute (AGENTS.md); automation calls the CLI inward, and the kernel never learns the word "rehearsal". |
| Mutate plans outside the ceremony | A plan-file edit without a certificate is scope-broadening by definition; the curator's own edits ride the ceremony like every other candidate. |
| Start daemons, watchers, schedulers | Rehearsal and curator beats are one-shots on the operator's cadence tree; no new clock is created. |
| Push, commit, or write ledgers during rehearsal | The dream's output is a report; the report files evidence rows, never repository state. |
| Treat a rehearsal verdict as a certificate | Doctrine non-goal, restated: no record authorizes a future action. The real loop rechecks every fact with fresh evidence. |

The boundary is what keeps the kernel side-effect-free. Clean
architecture gets its due here: rehearsal and curation are outer
automation adapters — glue over `scripts/hngh`, `scripts/ceremony-drive`,
and the cadence tree. Dependency direction stays inward; no `src/`
component changes. Promotion into the kernel happens only if a use
case earns a seat in the component map, and the rehearsal lane is
designed so that day never needs to come for its first rungs to pay.
