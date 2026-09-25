<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/monitoring.sh` script that logs a timestamped heartbeat to `digest/heartbeat.log`
  Verification: `bash -n cadence/monitoring.sh`

- [ ] Create `jobs/heartbeat.yml` job definition that invokes `cadence/monitoring.sh` every 5 minutes
  Verification: `bash -n jobs/heartbeat.yml`

- [ ] Add `tests/test_heartbeat.sh` that runs `cadence/monitoring.sh` and checks `digest/heartbeat.log` has a new entry
  Verification: `bash tests/test_heartbeat.sh`

- [ ] Register the new job in `cadence/schedule.yml` under the `monitoring` group
  Verification: `grep -q heartbeat cadence/schedule.yml`

- [ ] Run `make test` to confirm all existing and new tests pass
  Verification: `make test`
