# Lessons index

Curated by operator/agent review of the daily lessons harvest
(`docs/project/lessons-<date>.md`, produced by
`../../hngh-automation/cadence/day/01-lesson-harvest.sh`). Regenerated
when the roll-up step lands; until then, edited by hand. Only rows with
evidence paths live here — a lesson without a path is a rumor.

| Lesson | Blocker | Evidence | Change landed | Guardrail added |
|---|---|---|---|---|
| plans-ran-dry | No plan supply; the machine idled 40h+ with zero kernel commits | [backlog.md](backlog.md) "Night-agent plan authoring"; [CHANGELOG.md](../../CHANGELOG.md) 2026-08-30 | Alert → plan-candidate routing, done 2026-09-01 ([backlog.md](backlog.md) "Alert → plan-candidate routing — done"); router-side re-arm pre-check, done 2026-09-01 | `../../hngh-automation/scripts/router-tick.py` refire/dedup; blocked acceptance files an alert, never silent ([backlog.md](backlog.md) 2026-08-31 lesson note) |
| review-digest bloat | Review digest grew to 122KB — findings buried in diff noise | [CHANGELOG.md](../../CHANGELOG.md) 2026-08-28 wave: "122KB -> 1.9KB" | Digest reduced to findings-only (1.9KB) | Prompt shape in `../../hngh-automation/cadence/day/04-review-prep.sh`: "Output ONLY a terse markdown list of findings" |
| tree-skew whitelist + unversioned plan ledger | Tree-skew flapped on machine-maintained paths; the whitelist that silenced it also hides the plan ledger from the monitor | [CHANGELOG.md](../../CHANGELOG.md) 2026-08-28; `../../hngh-automation/jobs/oversight-tick.sh` (`hngh_wl` whitelists `docs/project/plans/`); `../../hngh-automation/jobs/sweep-artifacts.sh` (stages STATE/dashboard/digest/logs/stats/systemd/Makefile, never plans) | Whitelist landed — false alarms stopped | Partial: the plan ledger stays unversioned and invisible to the monitor; open finding, first item for the Audit station of [../design/descent.md](../design/descent.md) |
| DESKTOP_IP splice bug | Deck's `HNGH_DESKTOP_IP` sourced empty: quoted heredoc tag kept `$DESKTOP_IP` splices unexpanded | [CHANGELOG.md](../../CHANGELOG.md) 2026-08-28 wave | lint-identifiers learned quoted-heredoc scoping; bug caught and fixed | `../../hngh-automation/scripts/lint-identifiers.sh` in the standing gate |
| loop-recognition | Same alert identity re-routed into fresh plan candidates while its fix never landed — ten tree-skew candidates on 2026-09-05 alone | `docs/project/plans/2026-09-05-routed-tree-skew-hngh*.plan.md` (×10); escalation row ×9 in [reports.md](reports.md) 2026-09-05T07:00:45Z | Router dedup window + daily escalation to operator visibility (`../../hngh-automation/scripts/router-tick.py`) | Dedup stops candidate spam, not the cause; classed obsolete in [../design/bestiary.md](../design/bestiary.md) — kill/park route pending |
| steer-vs-die threshold | No decided rule for steer-vs-kill on stalled sessions; judged ad hoc per session — OPEN | [../research/2026-08-30-steer-vs-die-threshold.md](../research/2026-08-30-steer-vs-die-threshold.md) (researched, unbuilt) | None yet — missing-design class in [../design/bestiary.md](../design/bestiary.md); grow admission should gate on it | None yet; [roguelike-agentic.md](roguelike-agentic.md) carries the interim judgment rule |

---

Back to the [documentation index](../README.md).
