<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the adopted research line on adding a normal-risk cadence planning surface for hngh-automation. It keeps all changes in automation-owned paths and relies on plain, script-verifiable artifacts rather than provider, credential, systemd, or kernel build changes.

## Steps

- [ ] Add cadence/hngh-normal-risk.txt with the required sections `scope`, `verification`, and `exit criteria`.
  Verification: grep -q "exit criteria" cadence/hngh-normal-risk.txt
- [ ] Add scripts/hngh_cadence_check.py using only Python stdlib to fail unless the cadence file contains all three required section names.
  Verification: python3 scripts/hngh_cadence_check.py
- [ ] Add tests/test_hngh_cadence_check.sh that invokes the cadence check script and propagates its exit status.
  Verification: bash -n tests/test_hngh_cadence_check.sh
- [ ] Add dashboard/cadence-status.md with a plain-text operator summary of the cadence check state.
  Verification: grep -q "cadence" dashboard/cadence-status.md
