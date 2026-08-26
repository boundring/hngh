# Automated interface grading

## The loop

`implement → capture → local vision critique → ledger → next slice`

Each UI slice is built, then `scripts/grade-interface` grabs a real screenshot of the running
dashboard and submits it to a local vision model with a fixed rubric. The model's critique and a
`N/10` grade are appended to `docs/project/ui-grades.md`. The operator reads the ledger, picks the
next improvement, and the loop repeats.

## Why fail-first

Nothing blocks on operator opinion. The vision model grades every slice — objectively, from what
it actually sees. The operator steers, deciding what to fix next from the ledger; they never have to
be the only judge of whether a UI change is an improvement. A low grade is honest data, not a
failure of the loop. The script exits 0 even for low grades so the loop keeps running.

## The rubric

The model is asked to be a ruthless design critic and report *only what it sees*:

1. title/header text (quoted verbatim)
2. panels/tables: alignment, borders, spacing
3. any ASCII-art figure and its quality
4. colors/contrast
5. ugly/cramped/broken elements
6. overall: impressive or amateur

It must end with `GRADE: N/10`. If the grade line is missing the run records `GRADE: unparsed`.

## Model auto-selection

The reviewer conf (`~/.hngh-automation/reviewer-local.conf`) gives the endpoint and token file.
The conf's default model is text-only, so the grader lists `/v1/models` and auto-picks a
vision-capable model: prefer ids containing `gemma`, else `vl`/`vision`, else `qwen`. If none
match it exits 2 and lists available ids (never silently uses a text model). `--model=<id>`
overrides the pick.

## Ledger format

`docs/project/ui-grades.md` is a markdown table: `| timestamp | target | grade | first finding |`.
Each run appends one row: UTC-ish wall-clock time, the surface graded
(`dashboard-tui` or `dashboard-readout`), the `N/10` grade, and the first finding (≤120 chars,
pipes escaped).

## How to run

```sh
python3 scripts/grade-interface            # grade the current dashboard
python3 scripts/grade-interface --model=ID # force a specific vision model
python3 scripts/grade-interface --out=/tmp/x.png
```

It launches (or finds) the dashboard window, captures it, critiques it, and appends to the ledger.
Stdlib-only, one-shot, no daemon. Fails closed: a bad capture, unreachable model, or empty critique
reports honestly and exits non-zero rather than fabricating a grade.