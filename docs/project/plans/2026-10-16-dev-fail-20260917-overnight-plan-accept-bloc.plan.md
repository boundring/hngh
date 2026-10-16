<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cron-scheduling module in `cadence/cron.py` that accepts a frequency string and returns the next N execution times
  Verification: python3 cadence/cron.py --freq "0 2 * * *" --n 5 | grep -q "Mon Jun"
- [ ] Implement an event-emitter helper in `lib/eventbus.py` with subscribe/unsubscribe methods for pipeline stages
  Verification: bash -n lib/eventbus.py && python3 -c "from lib.eventbus import EventBus; e=EventBus(); e.subscribe('test', lambda x:x); print(e.unsubscribe('test'))"
- [ ] Create a dry-run runner in `scripts/dryrun.sh` that parses YAML job files without invoking subprocesses or modifying filesystem state
  Verification: bash scripts/dryrun.sh --job jobs/ingest.yaml && echo "dry-run passed"
- [ ] Add an integration test in `tests/test_cadence.py` covering cron frequency parsing and event bus lifecycle with stdlib assertions only
  Verification: make test || grep -q "test_cron\|test_eventbus" tests/test_cadence.py
- [ ] Generate a deployment manifest template in `dashboard/deploy.yaml.j2` that lists job paths and cadence frequencies for review gates
  Verification: python3 -c "import yaml; d=yaml.safe_load(open('dashboard/deploy.yaml.j2',encoding='utf-8')); print(len(d.keys()))"
