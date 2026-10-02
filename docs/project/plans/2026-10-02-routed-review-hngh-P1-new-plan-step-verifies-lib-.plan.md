<!-- plan: status=proposed risk=normal accepted=- routed-from=review:hngh:P1-new-plan-step-verifies-lib- -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T16:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh:P1-new-plan-step-verifies-lib-`
at 2026-10-02T16:00:41Z. Alert text: review P0/P1 (hngh): P1: new plan step verifies `lib/interval_parser.py` with `bash -n` — a shell syntax check on a Python module passes regardless of content; same anti-pattern as prior `bash -n tests/test_cadence_utils.py`; verification commands that cannot fail are not verifications

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
