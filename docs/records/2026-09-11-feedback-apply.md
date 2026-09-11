# 2026-09-11 — feedback auto-apply for quick theme/format items

Operator interactivity directive, apply slice. Companion to the capture
layer (jobs/feedback-ingest.py): what happens after an item lands on the
operator-items feed.

## Governance boundary

- automation/dashboard/ is the wholly gitignored runtime surface; style
  edits there are reversible file edits, NOT certificate-bound kernel
  mutations. jobs/feedback-apply.py never writes outside
  automation/dashboard/ + its own state (automation/state/).
- Trust rule preserved: machines apply only what the operator's own
  feedback asked for, and only the whitelisted one-line class. No
  guessing: unparseable requests stay unapplied operator items.

## Whitelist

- `[feedback:css-theme|data-format][quick]` -> property edits on
  dashboard/style.css only, driven by the ingest shorthand table:
  base font size -> font-size, panel gap -> gap, margins -> margin,
  spacing -> padding; explicit hex/named color -> color on the matched
  rule. Font-size edits always target the base font rule (html/body,
  font shorthand aware) — the shorthand says "base". Other properties
  target the rule matched from the item's element field (whole-word
  token match); no match appends a new rule, capped at 5 per beat.
- `[feedback:correction]` -> auto-inspect only: runs the named check if
  the text references tests/... or scripts/... (one file, 120s cap),
  files one report row with the result (alert on failure), never edits.
- Everything else (idea, non-quick) -> operator-only; the alert row is
  the whole action.

## Clamps

- +/−2px per apply, per property; total drift clamped to +/−16px from a
  baseline recorded on first apply (state/feedback-baseline.tsv);
  requested values below 0px are clamped to 0. A clamp refusal is
  recorded in APPLIED.md + a breadcrumb; nothing is applied.
- style.css missing or unparseable (unbalanced braces) -> nothing is
  applied and one correction report row is filed.

## Revert

- Every apply appends one APPLIED.md line carrying the previous value
  and the post-edit sha256 (state/feedback-applied.tsv row: item id,
  ts, property, old, new, sha). `feedback-apply.py --revert-last`
  restores that one previous value (or deletes an appended rule) and
  removes the line. One level deep by design; no history framework.

## Tests

- tests/test-feedback-apply.py (9 hermetic cases, wired into the
  Makefile test target): apply + history, color, non-whitelist left
  unapplied, append cap, baseline runaway clamp, revert-last (+ empty
  no-op), correction with named check files a report row and never
  edits, correction without a check reports that.
