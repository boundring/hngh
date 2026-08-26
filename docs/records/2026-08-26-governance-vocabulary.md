# 2026-08-26: Governance vocabulary relaxation

## Scope

A prose-only rung (operator directive 2026-08-26, the
`governance-vocabulary` queue item): relax the over-fixed
"ceremony"/"ritual" terms across the docs to the flexible governance
vocabulary (governance, validation, acceptance, admission). No symbols
were renamed; no behavior changes.

## Change

- Rewrote prose-only uses of "ceremony"/"ritual" in the README and
  `docs/*` to the flexible vocabulary: "the ceremony" -> "the governance
  loop", "self-governed ceremony" -> "self-governed validation loop",
  "ceremony commit" -> "validated commit", "ceremony-bound" ->
  "governance-bound", "post-ceremony" -> "post-validation", "ritual
  record" -> "governance record", and so on.
- Kept every name intact exactly: the `ceremony-drive` CLI/script token,
  `drive_ceremony`, `CEREMONY`, the proposal strings (caller=ceremony-drive,
  declared-capabilities=ceremony), and timeline rows / table structure.
- Kept deliberate uses: the `governance-vocabulary` backlog/queue/roadmap
  entries quote the old terms as the thing being relaxed.
- Added a short terminology note to `docs/README.md`: the vocabulary is
  flexible; `ceremony-drive` is a stable CLI name, not a doctrine.

## Files

README.md, `docs/README.md`, and the `docs/*.md` prose set touched by the
rung (design, journal, project, records).

## Verification

- `make test` green (2774 lisp checks passed, all python suites 0, ASDF
  load clean) — the doc-numbers and timeline-events guards held.
- Re-grep for "ceremony"/"ritual" across the docs shows only the kept
  `ceremony-drive` token, the deliberate governance-vocabulary
  meta-quotes, and verbatim working-log lines; CHANGELOG was untouched.

## Notes

- CHANGELOG.md, queue.md, and roadmap.md were not edited by anyone but
  the parent folds records; this record is the slice's own file.