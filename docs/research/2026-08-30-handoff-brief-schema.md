# failure-informed handoff brief: minimal schema

Status: crystallized 2026-08-30 from the evening selfdev plan's handoff-brief
research beat; file authored 2026-08-31 during plan execution (the plan
mandates 2026-08-30-* filenames). Per-beat material lives in hngh-automation
digest/RESEARCH-BEAT files; this record is the schema itself.

# Final Structured Summary — A Minimal Failure-Informed Handoff Brief Schema

**Line:** handoff brief schema for watchdog-detected session death and replacement
**Lifecycle state:** contracting → **contracted / recommended record**
**Disposition:** Define one minimal, field-by-field brief that a dying or
replaced delegated session can emit (or a steering leg can reconstruct from
producers already in the tree) so its replacement starts failure-informed
instead of re-walking the same ground. Every field below is anchored to a
producer that already exists and was read; no new machinery is proposed.

---

## 1. Purpose

The roguelike watchdog records LOG-ONLY handoffs in the automation repo's
`agent-handoffs.md` so an operator / the agentic steering leg can end a
session and launch a *failure-informed* replacement (the ledger preamble's
own words). But the ledger records only the death (class + evidence); it does
not carry the dead session's state. The missing piece is a brief — a small,
parseable record of what the session was doing, what it finished, what it
left dirty, and why it died. `omp-bridge --orient` already hands a *starting*
brief to a session (queue next, roadmap next, working tree, last ceremony
commit); the schema below is the *ending* counterpart: the same repo-grounded
style, plus the failure facts only the dying session (or its watchdog line)
knows.

## 2. The brief: eight fields

Each field names its real producer — the artifact read while crystallizing
this schema that already carries that field's information in some form.

| # | Field | Producer (read 2026-08-30/31) | Grounded shape |
|---|-------|-------------------------------|----------------|
| 1 | `objective` | `hngh/scripts/omp-bridge --run-start SESSION OBJECTIVE` | One sentence, non-empty (empty OBJECTIVE is refused, exit 2). The run is created with this objective as its mission; the brief repeats it verbatim, never paraphrases. |
| 2 | `lane` | `hngh/docs/project/active-work.md` lane lines | `<HH:MM> lane: <slug> — <state>: <detail>. Next: <step>` — e.g. `12:15 lane: hngh-autonomy-build — started: report-queue + run-autonomous + tests + ceremony + automation hook. Plan written; next: ground-read ceremony/backlog/…`. The brief's lane field is the slug plus the final `Next:` clause. |
| 3 | `budget spent` | `hngh/scripts/omp-bridge --run-start` loadout | The delegated budget *ceiling* is the loadout: `loadout-context-limit=8000`, `loadout-token-limit=8000`, `loadout-cost-limit=2000`, `loadout-time-limit=3600`. What the session actually spent against those ceilings has no producer in the read set — see §4. |
| 4 | `what landed` | `hngh/scripts/omp-bridge --orient` (Last ceremony commit section); `active-work.md` lane lines | The last certificate-bound commit reachable from HEAD: date, hash, `hngh: candidate …` subject — e.g. `2026-08-30 8dfab6df… / hngh: candidate ef3c5861…` (observed live via `--orient`, exit 0). Lane lines add the human form: `ceremony committed e86f4cf… (commit 1eff057)`. |
| 5 | `what is uncommitted` | `hngh/scripts/omp-bridge --orient` (Working tree section) | `git status --porcelain` count plus first path: `18 uncommitted paths (e.g. M docs/design/ui-evolve/current-overlay.json…)` (observed live). The brief carries this line as-is; the replacement re-runs `git status` itself for the full list rather than trusting a summary. |
| 6 | `failure mode` | `hngh-automation/agent-handoffs.md` lead format | The watchdog's own classification, one line: `session-drop \| <ts> \| <slug>\|<session-id> \| <class>: <evidence>` with classes `stall` (open turn, no tool progress, no live subagent), `loop` (≥ N identical trailing tool calls), `error` (hard error, no corrective step). Real death rows also exist in the `overnight-lead` class: `rc=124 dead log=logs/…` — rc plus the log path is the evidence. |
| 7 | `correction` | `hngh/docs/project/active-work.md` correction-style lane lines | The mid-lane correction the session itself recorded: e.g. `env verified: report-queue ABSENT (fail-closed live path) … Next: edit dashboard-tui` — an assumption overturned and the adjusted next step in one line. A dying session's brief carries its last such correction, if any. |
| 8 | `replacement instruction` | `hngh-automation/agent-handoffs.md` preamble + `overnight-lead` rows | The preamble's framing: watchdog handoffs exist so an operator / steering leg can "end the session and launch a failure-informed replacement". The `overnight-lead` rows already point the replacement at its evidence (`log=logs/overnight-…log`). A structured replacement instruction — restart same lane with amended objective vs. park — has no producer; see §4. |

Filling rule: the brief is emitted field-by-field in this order; fields 1, 2,
4, 5, 6 are always fillable from the producers above; fields 3, 7, 8 are
filled only when the session has real evidence, else the literal token
`not established` — never a guess.

## 3. Parseability

The brief is a flat record, one `field: value` line per field, no nesting, so
a future session (or the steering leg) can fill or consume it mechanically:
`objective: … / lane: … / budget-spent: … / landed: … / uncommitted: … /
failure-mode: … / correction: … / replacement: …`. Field names are fixed;
values are free text but single-line, mirroring the ledger's pipe-separated
discipline (the ledger refuses `|` inside notes for exactly this reason —
`omp-bridge --register` enforces it, exit 2).

## 4. Not established

- **Budget spent as a consumed quantity**: the loadout limits define the
  ceiling (producer: `--run-start`), but no read producer records what a
  dead session actually consumed against them. Until a producer exists, the
  brief's budget field records the ceiling plus `not established` for spend.
- **Structured replacement instruction**: the ledger preamble and
  `overnight-lead` rows establish the *intent* (failure-informed replacement)
  and the *evidence pointer* (`log=` path), but no producer writes an explicit
  restart/park/amend decision. The brief's replacement field is therefore
  free text until a producer defines it.
- **Whether the watchdog itself should emit briefs**: the watchdog is
  explicitly log-only ("never kills or launches agents"); this schema assigns
  emission to the dying/replaced session or the steering leg, not the
  watchdog. Any extension of the watchdog's role is an operator decision and
  is out of scope here.

## 5. Secondary framing

`~/Projects/etc/20260830/09-runbook.md` (operator-authored,
audited) was read as optional framing material. Its §7 "Key in-flight state"
mirrors this schema's spirit — HEAD, uncommitted whitelisted dirt, gate
state, what plan is executing — and its §2 maps where state lands. Its
*framing* (state must be recoverable from a fixed, named list of places) is
consistent with this schema and is adopted as context only; none of its
operational mechanics (timers, stop commands) are imported, because the
schema's fields must be grounded in producers read for this beat, not in a
cheat sheet's assertions.

## 6. Batched landing

This doc rides the next certificate ceremony: it is written to the working
tree only and the orchestrator lands it with the rest of the 2026-08-30
evening selfdev wave's batched doc landings. No code was written for this
beat; the schema is a record, not an implementation.

## Grounding

Verified paths read for this beat (2026-08-31, `test -f` each):

- `hngh/docs/project/active-work.md` — lane lines (fields 2, 4, 7)
- `hngh-automation/agent-handoffs.md` — watchdog handoff ledger: preamble,
  lead format, classes, real `session-drop`/`overnight-lead`/`bridge-register`
  rows (fields 6, 8)
- `hngh/scripts/omp-bridge` — script source read: `--orient` brief sections
  (Queue Next / Roadmap Next / Working tree / Last ceremony commit),
  `--run-start` objective + loadout limits, `--register` pipe-discipline
  refusal (fields 1, 3, 4, 5; §3)
- `~/Projects/etc/20260830/09-runbook.md` — optional secondary
  framing only (§5)

Live run: `hngh scripts/omp-bridge --orient` (verified read-only in source
before running: it only reads the queue/roadmap files and runs
`git status --porcelain` / `git log`) — exit 0, brief reproduced under
fields 4 and 5.
