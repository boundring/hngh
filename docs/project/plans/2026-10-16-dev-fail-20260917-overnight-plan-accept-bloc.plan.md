<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/notify.sh` script that echoes a summary line and exits 0 on success, serving as a lightweight local integration harness for the automation pipeline  
  Verification: bash -n cadence/notify.sh && echo "Syntax OK" || exit 1
- [ ] Update `Makefile` to include `cadence/notify.sh` in the standard test target so it runs automatically when `make test` is invoked without arguments  
  Verification: make test | grep -q notify.sh && echo "Included" || exit 1
- [ ] Create a `tests/cadence_test.sh` unit test that sources `cadence/notify.sh`, captures stdout, asserts the summary line contains "hngh automation", and reports pass/fail via standard echo-based assertion  
  Verification: bash tests/cadence_test.sh | grep -q "PASSED" || exit 1
- [ ] Add a README entry in `jobs/` explaining that new cadence jobs should inherit from `cadence/notify.sh` as their base template for consistent output formatting  
  Verification: grep -q "inherits" jobs/cadence_notify_template.md && echo "Documented" || exit 1
- [ ] Ensure all files modified so far pass syntax validation before the next commit by running a combined check on every touched path using bash -n and git diff --stat as a gate  
  Verification: bash -n cadence/notify.sh && bash tests/cadence_test.sh | grep -q "PASSED" && echo "All checks passed" || exit 1
