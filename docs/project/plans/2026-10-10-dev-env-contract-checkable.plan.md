<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/heartbeat.sh` script that emits a timestamped log line to `jobs/heartbeat.log` on every run
  Verification: bash cadence/heartbeat.sh && grep "$(date -u +%Y-%m-%dT%H:%M:%SZ)" jobs/heartbeat.log
- [ ] Add a `tests/test_heartbeat.sh` script that runs `cadence/heartbeat.sh` and asserts the log line exists
  Verification: bash tests/test_heartbeat.sh
- [ ] Add a `dashboard/status.json` file containing a static `{"status":"ok","last_run":"now"}` payload
  Verification: python3 -c "import json; d=json.load(open('dashboard/status.json')); assert d['status']=='ok'"
- [ ] Add a `digest/summary.md` file containing a single line `# hngh-automation digest: operational`
  Verification: grep -q "operational" digest/summary.md
- [ ] Add a `scripts/validate.sh` script that checks `bash -n` on `cadence/heartbeat.sh` and `tests/test_heartbeat.sh`
  Verification: bash scripts/validate.sh
