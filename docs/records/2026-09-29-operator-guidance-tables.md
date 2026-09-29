# Operator decision cards carry note guidance

Date: 2026-09-29. Surface: broadsheet newspaper (`/` on the dashboard,
`automation/dashboard/index.html` + `broadsheet-view.js`), fed by
`automation/scripts/newspaper-compose.py`.

## Problem

Operator decision cards offer Park (guidance note REQUIRED by
`POST /operator-item/park`, 400 when missing) and Acknowledge (optional
note), but the articles carried no recommendations: no cause-and-effect
table for the verbs, no example notes, no pointers to documents that
explain what a guidance note is for. The operator was asked to write a
note blind.

## Change

- `newspaper-compose.py`: every operator decision card now carries a
  `guidance` payload: `why` (reusing OP_NARRATIVE_WHY), `note_rules`
  (<=200 chars, pipes stripped, recorded in the report-queue row and the
  durable ledger), a `verbs` table mirroring the card's own choices 1:1
  (label / note requirement required-optional-none / durable effect per
  the server's `_op_settle` ground truth), per-class example notes with
  the effect each filing causes, and 2 verified doc links per class
  (`OP_GUIDANCE_DOCS`, existence-checked at authoring time).
- `broadsheet-view.js` (+ additive `.oguide*` CSS): when an expanded
  article has `guidance`, renders an italic why line, a verb/note/effect
  table, example notes as `"<note>" -> <effect>` rows, the note-rules
  line, and the doc list. `docs/` paths link through the served jailed
  route `/hngh-docs/docs/...` (same rule as routes-view refHtml); other
  paths render as plain cited text. Fail-open: cards without guidance
  render byte-identical to before.

No changes to scoring, caps, classification, choice endpoints, flood
logic, or the server.

## Verification

- `automation/tests/test-newspaper-compose.py`: new Guidance tests fail
  before / pass after; file 28 tests OK.
- `automation/tests/test-broadsheet-view.py`: new OperatorGuidance
  tests (wiring, renders-when-present, fail-open-when-absent,
  note-semantics pin) fail before / pass after; file 45 tests OK.
- Full automation gate green after an unrelated one-row
  `automation/research-lines.tsv` field-count repair (row 297, tab
  inside the title field joined per row 290 convention).
