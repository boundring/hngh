# Subsystem anatomy — Hngh's body, in Clean Architecture terms

The operator describes Hngh with a body's vocabulary: will, motile
force, senses, limbs, memory, nervous system, limbic system,
circulatory system. This doc roots each in Clean Architecture method:
every biological function is a component with a named port, a named
adapter, and a test, and every dependency points inward. One law,
stated once and binding everywhere: **signals never flow outward** —
a sense may inform the center, a limb may act on evidence, and nothing
on the edge learns how the center decides.

## The anatomy

| Metaphor | Component | Port | Adapter | Tests |
|---|---|---|---|---|
| Will | `hngh.domain` pure policy (run lifecycle, governance matrix, closed vocabularies) | domain values + pure functions | none — it IS the center | property tests, closed-vocabulary tests |
| Motile force | `hngh.application` use cases (create-run, admit-transport, arm-run, start-run, checkpoint, close-run, select-course) | inward port contracts per use case | CLI dispatch (`scripts/hngh`) | per-use-case suites, policy-gate tests |
| Senses | read-side feeds and probes: oversight tick, watchdog probes, `research-feed.py`, `plan-feed.py`, `system-feed.py`, ui-audit | read ports over the world | AUTO `jobs/*-feed.py`, `cadence/*` probes | feed parsers, fail-closed probes |
| Limbs | mutation adapters: `omp-bridge` (delegated sessions), ceremony mutations (git add/commit/push), `jobs/ui-audit.mjs` writes | mutation ports (`+mutation-actions+`) | filesystem/git adapters | `test-omp-bridge.py`, verify-candidate, mutation-check |
| Memory — working | telemetry store (`dashboard/telemetry.db`, WAL) | capture port (`jobs/telemetry.py emit`) | sqlite adapter | capture-first tests; retention tiers; first reader: the remote leg's daily cap |
| Memory — curated | git ledger (docs/records, reports.md, plans/, research/) | the ledger append (report-queue, records) | files in git | report-queue suite; the commit IS the record |
| Nervous system | cadence continuum (1m…month timers) + supervision (5m tick) + overnight loop (`hngh-overnight.timer`, 2h) | the tick: one beat per firing, fail-closed | systemd timers + `cadence-tick.sh` | drop-in syntax sweep (`bash -n`), STATE breadcrumbs |
| Limbic system | attention: report-queue alerts, verdict pill, agent-handoffs | alert port with dedup identities | dashboard verdict spine | report-queue tests; marker + ui-audit checks |
| Circulatory system | model chain + credential refresh (lib/model.sh: unsloth → budgeted remote → ollama → archive) | model_call port, MODEL_USED receipt | HTTP adapters per backend | bench job; key-file-gated fail-closed legs |
| Skin | the dashboard (classic-Winamp skin) | read-only HTTP over feeds | style.css skins (`data-theme`) | ui-audit (axe + register rules) |

## Continuous operation — the loop that closes the body

The 2026-08-28 wave wires three table rows together: the nervous system
fires the beat, the limbs execute it, memory records it. Three
lifecycles and one budget bind them.

### The overnight work loop

`hngh-overnight.timer` fires `scripts/overnight-cycle.sh` every 2h.
The selector, first match wins:

| Priority | Work | Source |
|---|---|---|
| 1 | an accepted plan's next unchecked step | `docs/project/plans/` |
| 2 | the top queued lane | kernel selector (`select-course` over queue.md) |
| 3 | the day-tier research beat | `research-lines.tsv` |

Execution is delegated and bounded: `omp-bridge --run-start` gates a
delegated omp session (`zai/glm-5.3`) behind kernel admission, capped
at 1800s; the 5m supervision tick auto-replaces stalled runs.
Fail-closed: critical-class items — provider/credential config,
systemd unit lifecycle, non-prune deletions, hngh src/ or Makefile
changes — are never attempted; they park as an operator-facing alert
and the cycle moves on. The cycle never blocks on a human.

### The plan-ledger lifecycle

`docs/project/plans/*.plan.md` carries its own status line
(`status=accepted risk=normal accepted=<ts>`). Plans are operator- or
machine-authored; normal-risk plans are machine-accepted when their
verification steps are runnable and the gates are green — the
acceptance policy itself is operator-owned and lives in
plans/README.md — and the machine reads the status,
executes unchecked steps in order, and ticks each with its landing
commit. `jobs/plan-feed.py` (30m tier) publishes the ledger to
`dashboard/plans.json`. hngh-automation commits land free; hngh changes
land only through the certificate ceremony behind green gates.

### The research-line lifecycle

`cadence/day/05-research-beat.sh` advances one non-crystallized line
per beat through planned → expanding → contracting → crystallized
(`research-lines.tsv`), finishing lines before starting new ones. The
crystallization beat writes the line's lasting record to
`docs/research/<date>-<id>.md` — working research becomes curated
memory. Overnight beats run the same lifecycle; five 2026-08-28 lines
crystallized this way.

### The budgeted remote leg and the capture store

The remote leg (OpenRouter-compatible) is key-file gated and budgeted:
each call emits a telemetry row (kind=model, source=remote), and the
leg counts the day's rows against `REMOTE_DAILY_CAP_CALLS` before
dialing — cap reached, it falls through to ollama. The working memory
is now a dependency of the circulatory system's spend decision. The
store stays capture-before-views: rows land best-effort and
fail-closed, bounded by retention tiers; session-cost views are the
intended next readers.

## Dependency law, per the charter

- Senses and limbs depend inward on the kernel's ports; the kernel never
  imports an adapter.
- The nervous system (cadence) may invoke limbs and senses; it never
  decides policy — the will does.
- Memory writes are append-only; the curated record is git; the
  telemetry store is rebuildable and bounded.
- Presentation (skin, dashboard) reads state and files display rows; it
  never authorizes, mutates kernel state, or starts work.
- Every new biological function lands with its port, adapter, and test
  in the same change, or it is not admitted.
