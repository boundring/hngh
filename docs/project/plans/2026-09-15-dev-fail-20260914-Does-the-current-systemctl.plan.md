<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-current-systemctl (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line "Does the current systemctl status or equivalent execution log for the hngh-automation crumb writer show a failure state or last-run timestamp prior to 2026-09-12T21:03Z?" by addressing the identified instrumentation gap through automated staleness detection and reporting mechanisms.

## Steps

- [ ] Create `scripts/check_crumb_staleness.py` that reads the crumb writer's last-run timestamp file and compares it against a configurable threshold (default 2026-09-12T21:03Z)
  Verification: python3 scripts/check_crumb_staleness.py --help

- [ ] Add `lib/staleness_threshold.conf` containing the default threshold timestamp and staleness window in ISO 8601 format
  Verification: grep -q "2026-09-12T21:03Z" lib/staleness_threshold.conf

- [ ] Create `tests/test_staleness_check.py` with unit tests verifying the staleness detection logic handles both fresh and stale timestamps correctly
  Verification: python3 tests/test_staleness_check.py

- [ ] Add `cadence/crumb_writer_monitor.sh` that invokes the staleness check script and writes a machine-readable status file to `digest/`
  Verification: bash -n cadence/crumb_writer_monitor.sh

- [ ] Create `dashboard/staleness_indicator.html` displaying the current crumb writer status with last-run timestamp and staleness state
  Verification: grep -q "staleness" dashboard/staleness_indicator.html
