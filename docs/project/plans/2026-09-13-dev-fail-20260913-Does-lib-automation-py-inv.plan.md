<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-13 - dev-fail-20260913-Does-lib-automation-py-inv (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implement findings F1 (subprocess seam) and F2 (overnight harness coverage gap) by adding a local integration test script that invokes `bin/hngh` as an external process via `subprocess.run`, asserting the corrected CLI contract resolves, then registering it in the existing CI gate so regression is caught synchronously rather than overnight.

## Steps

- [ ] Create `scripts/verify-lib-harness-seam.sh` that uses Python's stdlib `subprocess.run` to call `bin/hngh --version`, asserts a clean exit code and non-empty stdout, and writes results to `digest/RESEARCH-BEAT-*-fail-20260913-Does-lib-automation-py-invoke-bin-hngh-v.md`
  Verification: bash scripts/verify-lib-harness-seam.sh

- [ ] Add the new script as a prerequisite in `cadence/hour/33-research-beat.sh` before the model-leg call, so any subprocess seam regression blocks the beat early with a clear error message referencing findings F1/F2
  Verification: grep -q "verify-lib-harness-seam" cadence/hour/33-research-beat.sh

- [ ] Commit both files to hngh-automation and run `make test` in jobs/, scripts/, and cadence/ directories to confirm no existing gates are broken by the addition
  Verification: make test -C jobs/ && make test -C scripts/ && make test -C cadence/
