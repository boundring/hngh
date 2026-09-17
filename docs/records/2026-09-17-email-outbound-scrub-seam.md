# 2026-09-17 — notify-email outbound-scrub seam (ts-angle3-email-outbound-scrub)

## Problem

The 2026-09-16 redaction seam map ("outbound payloads need the op://
family cut plus a vocabulary check or an outbound-only gate") did not
inventory the most concrete outbound channel: the notify-email
side-channel. Loading confirmed the runtime:

- `automation/lib/notify-email.sh email_sidechannel` (alert_row)
  writes the alert body to a temp file and passes it straight to
  `scripts/notify-email.py send`; the `classify` step applies no
  redaction either (`classify_alert` is vocabulary-only by design).
- `scripts/notify-email.py` contained ZERO scrub/redact references:
  immediate-class alerts reached the operator's SMTP recipient with
  whatever the producer passed, relying solely on emitter
  pre-redaction (`lib/causes.sh redact_home` and `lib/digest-block.sh
  scrub_paths` are the only emitting seams that scrub; most emitters
  do not).
- The report-queue row is NOT a substitute scrub: the row redacts at
  the sink (`scripts/report-queue redact_boundary`), but the email
  body is a SEPARATE outbound copy of the producer's raw text, so the
  sink-side guard never touches the email bytes.

Also confirmed as out of the tree but adjacent: neither
`automation/lib/scrub.py` nor the sink-side mirror carries an `op://`
token family, and `user:pass@host` userinfo survives outside a
`scheme://` URL (the `_USERINFO` rule requires the `//` context). The
op:// cut remains a documented boundary point; the userinfo gap is
inherited from the ONE token family rather than introduced here.

## Contract decision

The email channel is an outbound surface INDEPENDENT of the
report-queue row. It cannot inherit the row's redaction (the row
text is scrubbed only in the ledger, not the email body), and the
duty cannot be pushed to emitters (most don't pre-redact; that was
exactly the gap the emitter census closed). Therefore the send path
carries the duty itself: `notify-email.py send` scrubs `--subject`
and body through the machine-local token family
(`automation/lib/scrub.py scrub_paths`, the single source) at the
LAST boundary before SMTP compose. `classify` stays vocabulary-only
(it is the importance rubric, not a scrub site). Fail-closed: if the
scrub module is unreadable, the send refuses (exit 2) rather than
leaking — the same grade the digest append seam uses.

## What landed

- `automation/scripts/notify-email.py` — `scrub_outbound()` +
  module-local lazy loader (`_OUTBOUND_SCRUB` seam) over
  `lib/scrub.py scrub_paths`; wired into `main()` before compose, on
  both `--subject` and the `--body-file/--body-text` body. Ordinary
  prose and source URLs survive verbatim (redaction, not dropping);
  credential userinfo inside URLs dies to `[redacted]@host`.
- Tests (red first, `automation/tests/test-notify-email.py`
  `OutboundScrub`):
  - body + subject + DRY_RUN compose carry no machine-local path
    tokens; `[redacted path]` markers present; source URL preserved
    with `[redacted]@` userinfo; prose kept (MIME decoded in-test).
  - `test_classify_stays_vocabulary_only`: classify stays the rubric;
    the raw pathy text passes through — proof the duty cannot live in
    classify and must sit on send.
  - `test_missing_scrub_module_fails_closed`: absent module ->
    exit 2, no SMTP contact.

## Emitter census (seam-map closure, report-queue --add callers)

Kinds matched to the 2026-09-17PUBLIC_KINDS widening (alert +
progress are sink-redacted; expense/optimization/scheduled are
operator-local). No emitter was found carrying raw machine-local
paths outside the seam sites already closed (causes.sh, digest-block
.family). Callers by kind:

- alert (sink-redacted, emission-side relief now combined with the
  email leg's own scrub): 58-patrol.sh, 26-publication-review,
  27-patrol.sh, 32-deck-facts.sh, agent-watchdog.sh,
  credential-health.sh, dashboard-self-review.py, oversight-tick.sh,
  notify-email.sh (alert_row), accept-plans.py, overnight-cycle.sh,
  news-screen.sh, patrol.py, beat-watchdog.py,
  dashboard-server.py, feedback-apply.py (alert branch),
  33-research-beat.sh, 02-ledger-prune.sh, 03-gate-check.sh,
  04-review-prep.sh, 06-review-disposition.sh, 17-torch-audit.sh,
  18-mimic-drill.sh, 19-ux-review.sh, 22-ttsr-fit.sh,
  23-bctx-canary.sh, 25-wiki-health.sh, config-backup.sh,
  11-service-recovery.sh (kind-arg report fn), 01-activity-tick.sh
  (kind-arg report fn).
- progress (sink-redacted): 06-remote-posture, 07-budget-digest,
  08-doc-suite-check, 09-email-digest, model-demote.sh, service-ctl.sh,
  hygiene.py, plus the Cadence progress/alert report fns above.
- optimization: 13-email-qa.sh, 01-zoom-out.sh (month tier).
- operator-bound variants of the same envelope sit in mcp/hngh_mcp_server.py
  (kind-arg report fn), jobs/agent-supervision.py,
  jobs/context-ratio.py, jobs/graph-data.py, jobs/history-feed.py
  (queue readers, not --add emitters).

## Validation

- Red: 3/4 new OutboundScrub tests failed on the raw pathy send
  before the guard; classify stayed green (correct — it is not a
  scrub site).
- Green: `automation/tests/test-notify-email.py` 58/58 OK,
  including `test_dry_run_compose_is_scrubbed_too` (no socket in the
  dry path either), and the fail-closed probe (exit 2, no SMTP call
  when the module path is unavailable).
- Fixtures assemble path tokens by concatenation so this file never
  carries a literal `/home/<user>` token
  (verify-candidate ABSOLUTE_PATH_PATTERN discipline).

## Open boundary (not closed here, on the map for the next slice)

The `op://` token family remains unmatched in BOTH redaction
definitions (scrub.py and report-queue). An `op://vault/item/field`
reference in an alert body would now still survive the outbound
scrub (it is not a path token in the family). The userinfo-outside-URL
case (`bot:pass@host` without `scheme://`) is the same story, inherited
from the ONE family. Both are single-source changes to
automation/lib/scrub.py + scripts/report-queue (mirrored) and should
land with the seam-map's third rail rather than as an email local
override — the one-family rule is why they are parked, not forgotten.
