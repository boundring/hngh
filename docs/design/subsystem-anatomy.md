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
| Senses | read-side feeds and probes: oversight tick, watchdog probes, `research-feed.py`, `system-feed.py`, ui-audit | read ports over the world | AUTO `jobs/*-feed.py`, `cadence/*` probes | feed parsers, fail-closed probes |
| Limbs | mutation adapters: `omp-bridge` (delegated sessions), ceremony mutations (git add/commit/push), `jobs/ui-audit.mjs` writes | mutation ports (`+mutation-actions+`) | filesystem/git adapters | `test-omp-bridge.py`, verify-candidate, mutation-check |
| Memory — working | telemetry store (`dashboard/telemetry.db`, WAL) | capture port (`jobs/telemetry.py emit`) | sqlite adapter | capture-first tests; retention tiers |
| Memory — curated | git ledger (docs/records, reports.md, plans/, research/) | the ledger append (report-queue, records) | files in git | report-queue suite; the commit IS the record |
| Nervous system | cadence continuum (1m…month timers) + supervision (5m tick) | the tick: one beat per firing, fail-closed | systemd timers + `cadence-tick.sh` | drop-in syntax sweep (`bash -n`), STATE breadcrumbs |
| Limbic system | attention: report-queue alerts, verdict pill, agent-handoffs | alert port with dedup identities | dashboard verdict spine | report-queue tests; marker + ui-audit checks |
| Circulatory system | model chain + credential refresh (lib/model.sh: unsloth → remote → ollama → archive) | model_call port, MODEL_USED receipt | HTTP adapters per backend | bench job; key-file-gated fail-closed legs |
| Skin | the dashboard (classic-Winamp skin) | read-only HTTP over feeds | style.css skins (`data-theme`) | ui-audit (axe + register rules) |

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
