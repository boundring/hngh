# 2026-09-27 — dashboard metacycle (42-dashboard-introspect)

Operator goal: the dashboard should converge on operator intent — the
system notices its own gaps and files them as work. Delivered as an
hourly beat that evaluates machine-checkable intent probes, files unmet
gaps as research arcs, and alerts on regressions.

- Design: `docs/design/dashboard-intent.md` (INT-1..INT-22, loop
  mechanics, Jev doctrine)
- Beat: `cadence/hour/42-dashboard-introspect.sh` →
  `jobs/dashboard-introspect.py` (fail-open, exit 0 always)
- Tuning: `cadence-params.tsv` rows `introspect-min-gap-hours` (1),
  `introspect-retire-streak` (3), `introspect-wire-max-share` (25),
  `introspect-jev-min-gaps` (2), `introspect-jev-timeout` (20)
- Test: `tests/test-dashboard-introspect.sh` (hermetic fixture surface;
  all-met→no arcs, one-gap→one arc, met→unmet→regression alert with
  identity `dashboard-regression:<slug>` window 86400 + fresh evidence
  hash, era retirement→fresh `-r1` arc id, closed pacing window→deferred
  filing). Registered in the Makefile `test` target and the
  test-cadence-collapse tier table.

## Probe table (initial grade 2026-09-27T13:08Z: 14/22 met)

| probe | sev | initial | |
|---|---|---|---|
| masthead-splash | major | unmet | splash tokens present, ascii absent |
| masthead-expansion | major | unmet | edition.masthead.expansion empty |
| masthead-varies | minor | unmet | 0 distinct expansions |
| masthead-emboss | minor | met | text-shadow in masthead block |
| masthead-temperature | minor | unmet | temp_c present, temp_f None |
| paper-texture | major | met | #paper-canvas + paperInit |
| printed-frames | minor | met | double-rule borders |
| leaf-light-motion | minor | met | dapple/leaf tokens |
| choice-previews | major | met | every choice has outcome |
| dismiss-immediate | major | met | dismiss + removeChild |
| no-dead-buttons | major | met | all button ids referenced |
| family-card | major | met | family-marked ≤ 1 |
| no-empty-feedback | major | met | 0 empty `[feedback:idea]` |
| voice-majority | major | unmet | 53% < 60% |
| wire-capped | minor | unmet | 35% > cap 25 |
| single-webgl | minor | unmet | 2 context sites |
| reduced-motion | major | met | media query present |
| no-client-today | major | met | no client Date use |
| evidence-sources | major | met | all wire rows carry sources |
| fail-closed-auth | major | unmet | no 401/403 error path |
| feed-error-banner | minor | met | #papererr wired |
| scroll-60fps | minor | met | IntersectionObserver |

## Loop mechanics

1. Hourly (no stamp gate; hour tier paces): run 22 probes → grade M/T
   row, identity `dashboard-introspect:grade`, evidence `M/T` (re-fires
   only when the grade moves).
2. Unmet probes → arcs `arc-<date>-dashboard-<slug>` in
   `research-subjects.txt`, deduped by id; `33-research-beat` chews
   them. `introspect-min-gap-hours` paces sweeps; regression arcs
   bypass the window (fresh damage files now).
3. met→unmet → alert identity `dashboard-regression:<slug>`, window
   86400, evidence = sha256(failing detail)[:12]; `10-router-feed`
   consumes alerts.
4. Closure: `introspect-retire-streak` (3) consecutive met grades close
   the probe's era; a re-gap then files a FRESH `-r<era>` id, so the
   answered arc is never confused with the reopened question.
5. Jev (operator addendum, "advise as we go"): when ≥
   `introspect-jev-min-gaps` gaps pend, ONE batched `ask_nouls` call
   (lib/typesafe.py, jev-1.13.0, shared state paid once, input-only
   priced) scores file-now vs defer per pending slug and reorders
   filing. Child process, `introspect-jev-timeout` bound; any failure
   = probe order. Jev ADVISES, never certifies — deterministic probes
   own met/unmet. (Pattern: advice for ordering only, decisions stay
   file-evaluable.)

## Initial run + first live catch

Initial real run 13:08Z: grade 14/22, 8 arcs filed (Jev-ordered:
masthead-splash, voice-majority, wire-capped, single-webgl,
masthead-expansion, masthead-temperature, fail-closed-auth,
masthead-varies). Second run 13:12Z caught a real regression within
four minutes: a sibling dashboard edit dropped choice previews →
`dashboard-regression:choice-previews` alert + fresh arc + grade 13/22.
The loop converged on its first defect without operator action.

Incident during bring-up: the job's REPORT_ROOT defaulted to
`automation/` so grade rows landed in the legacy
`automation/docs/project/reports.md` side-ledger instead of
`docs/project/reports.md`. Fixed: default is the repo root (same rule
as scripts/report-queue); polluted rows/body reverted, verified the
row lands in the real ledger.
