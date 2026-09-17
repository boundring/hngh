# 2026-09-16 — Scrub consolidation: one token family, one definition

Node: llc-gate-scrub-site-divergence. Closes the seams flagged by
llc-digest-ledger-redaction, llc-boundary-redaction, and
llc-scrub-regex-gap.

## Problem

Four independent scrub definitions had drifted:

1. `automation/lib/redact.sh` sed — tilde family (~ / ~tmp), mid-token
   guard, kernel ledger rendering.
2. `scripts/report-queue` REDACT_RES — same tilde family, sink-side.
3. `automation/jobs/news-articles.py` PATH_TOKEN_RE — [redacted path]
   marker, url-first named group, home/tmp/tilde only.
4. `automation/jobs/digest-ledger.py` PATH_TOKEN_RE — same identity
   regex, third copy.

Consequences: a token redacted at one seam sailed through another
(different families), and downstream consumers/tests could not agree on
which marker to expect (different conventions). Explicitly open:
digest-ledger printed `sessions` last_plan and `plans` queue_next
unscrubbed; the Users and root absolute-prefix families, scheme-relative
//host/home/, and URL
userinfo (user:pass@host) were covered nowhere.

## Decision

- ONE definition: `automation/lib/scrub.py` (python importable),
  wrapped by `automation/lib/scrub.sh` (sh sourced: `scrub_paths`,
  `redact_home_impl`); `redact.sh` is now a shim keeping the
  historical `redact_home` name.
- ONE token family: home / Users / root / tmp (bare or with segments),
  scheme-relative //host/home/..., tilde paths, and credential URL
  userinfo die; URLs survive verbatim except userinfo; word fragments
  (Xrooted, MACRO + home, Xtmpfile) and URL path components survive.
- Marker unification (deliverable 3): `[redacted path]` is THE marker
  for prompt-side/echo-guard seams (scrub_paths); the tilde rendering
  (~ = the tilde rendering of an operator home, ~tmp = /tmp) remains THE
  kernel-ledger sink
  convention (redact_home / redact_boundary). These are now one family
  with two named renderings mirrored on both sides and pinned by
  differential parity tests, not two regex conventions. Both die on
  absolute paths; downstream tests assert the rendering each surface
  produces, per this mapping.
- Kernel relationship: dependency direction stays inward — kernel
  code never imports automation/. scripts/report-queue mirrors the
  family in REDACT_RES as the git-tracked sink-side backstop; parity
  with the module is pinned by tests on both sides (kernel:
  test-report-queue.py test_alert_redaction_covers_full_canonical_family;
  automation: test-scrub-module.py).

## Seams closed

- digest-ledger.py `build()`: sessions last_plan quote and plans
  queue_next quote now pass through scrub_paths before the mega line
  (red-first: test-digest-plan-seam-scrub.py, 5 cases; budget.md
  night-session LABEL rows and plans.json queue_next are the plausible
  carriers — live evidence: STATE.md alert crumbs carried
  ~/.hngh-automation/unsloth.token today 22:00Z).
- Users and root absolute-prefix families, //host/home/, userinfo:
  covered in the module and
  in the kernel sink (kernel red-first:
  test_alert_redaction_covers_full_canonical_family).
- Migrated onto the module: jobs/news-articles.py,
  jobs/digest-ledger.py, jobs/patrol.py, jobs/digest-html.py,
  jobs/gdelt-news.py, lib/model.sh (_scrub_paths jq copy retired),
  lib/digest-block.sh, lib/redact.sh (shim).

## Tests

- automation/tests/test-scrub-module.py (24 cases): family, marker,
  idempotence, scrub_grep, tilde rendering.
- automation/tests/test-digest-plan-seam-scrub.py (5 cases, red-first
  on the two live seams).
- tests/scripts/test-report-queue.py: new
  test_alert_redaction_covers_full_canonical_family (red first).
- Differential parity battery: module redact_home vs kernel
  redact_boundary on 16 adversarial samples — 0 diffs.
- Regression: all prior scrub/redact suites green
  (test-news-articles.sh, test-model-reply-scrub.sh,
  test-digest-append-scrub.py, test-digest-html.py, test-digest-local.py,
  test-config-backup-fail-redact.sh, test-oversight-tick-alert-redact.sh,
  test-credential-alert-dedup.sh, test-credential-evidence.py,
  test-patrol.py, test-gdelt-news.py, test-report-queue.py).

## Not checked / follow-ups

- credential-health.sh keeps its local $HOME->~ substitution (exact
  literal of the operator's own home, a subset of the family); folding
  it into scrub.sh is a small follow-up.
- scrub_grep is defined and tested but no live consumer yet; wiring it
  into the gate-crumbs scanner is a separate slice.
- The kernel ceremony mirror means the family now lives in two files
  by design (module + sink); a drift would surface as a parity test
  failure, not a silent leak.
