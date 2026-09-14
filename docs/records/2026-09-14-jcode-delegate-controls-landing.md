# 2026-09-14 — Jcode delegation controls landing: /delegate route + Sessions-tab launch UI

Record for plan `docs/project/plans/2026-09-14-jcode-delegate-controls.plan.md`
(steps 1-3). Slice commit `a1a263d` (hngh-automation, free-commit lane).

## What landed

- `automation/dashboard-server.py`: `POST /delegate` — body
  `{slug, objective, provider, minutes}` validated fail-closed
  (`validate_delegate_body`: slug `[A-Za-z0-9-]{1,64}`, objective
  1..2000 chars, provider closed-set zai|unsloth, minutes real int
  1..30 — out-of-range rejected, never clamped); on pass it launches
  the ONE fixed command `bash lib/jcode-delegate.sh <slug>
  <objective> <minutes> <provider>` detached via Popen(start_new_
  session=True), no shell interpolation of operator text. 202 shape
  `{"ok": true, "slug": ...}`; 400 on bad input; 500 on exec failure.
  The delegate ledger/breadcrumbs, not the HTTP response, is the
  result record.
- `automation/dashboard/sessions-view.js`: delegate form on the
  Sessions panel header (`.sv-dg` register, matching `.sv-fbtn`):
  slug, objective, provider select zai/unsloth, minutes 1..30,
  submit button. Client re-validates the same rules the server
  enforces; status surfaces on the shared `.sv-opnote` transient line
  (clears after ~4s), never an inline error dialog.
- `automation/tests/test-delegate-route.py`: 12 hermetic pytest
  cases — valid body, per-field rejections (slug/objective/provider/
  minutes type+range), boundary minutes, non-dict body, dispatch
  registration, and (stubbing `subprocess.Popen`) the fixed argv
  `["bash", <...>/lib/jcode-delegate.sh, slug, objective, "10", "zai"]`,
  the 202 shape, 400 shape, and 500 on exec failure. Green 12/12.

## Audit evidence (step 3)

- `automation/jobs/ui-audit.mjs` (axe + clip/squash/font-floor/name
  register + winamp default) against the live served dashboard:
  1 violation across 1 rule — the pre-existing open axe:color-contrast
  identity (gantt track labels, own routed plan). The Sessions panel's
  delegate form contributes zero findings; every input/button carries
  an accessible name (aria-labels).
- Before/after captures: `automation/dashboard/shots/
  sessions-delegate-before.png` (HEAD sessions-view.js served from a
  /tmp copy on :8091 — no delegate row on the header) and
  `sessions-delegate-after.png` (live working tree :8890 — slug,
  objective, provider select, minutes, delegate button render inside
  the header row). Visual witness confirms the form renders and the
  before panel lacks it.
- Honest gap: the full `scripts/grade-interface` vision-grade pass did
  NOT run — no image-input-capable model is served on the reviewer
  endpoint (picked `gemma-4-12B` rejects image input, HTTP 400
  "model does not support the image input"). Fail-closed, no ledger
  grade row appended. Remaining loop: a vision-capable local model in
  the reviewer endpoint (pick_model rubric expects vl/vision/qwen
  ids), then one `grade-interface`-style grade of the after capture.

## Non-clobbering fanout note

Steps 1 and 2 of the plan were executed against the same files by
sibling sessions before this coordinator session; integration here was
review-verify-commit (diff read in full — every added line belongs to
the delegate slice), not re-implementation. The staged-index sweep
hazard (lesson 2026-09-14T08:44:40Z) was dodged by staging only the
three named slice files.
