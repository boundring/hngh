<!-- plan: status=executed risk=normal accepted=2026-09-02T10:01:26Z routed-from=gate-red:hngh -->
# 2026-09-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `gate-red:hngh`
at 2026-09-02T10:00:45Z. Alert text: [oversight] gate-red: hngh make test red — gate-check alert row unread in ledger

## Steps

- [x] Re-run the named gate, capture the failing check, fix or park
      Verification: both `make test` gates green; failing check captured

      Executed 2026-09-08T01:06Z. Both gates green on direct re-run:
      kernel `make test` rc=0 (2855 checks, ~37s), hngh-automation
      `make test` rc=0 (~30s). Failing check captured from alert body
      598ffaaa (2026-09-08T01:01:33Z): the kernel gate's
      `tests/scripts/test-dashboard-live.py` step raised
      subprocess.TimeoutExpired on `scripts/dashboard-readout --watch 1`
      (hard 5s spawn wait) → `make: *** [Makefile:20: test] Error 1` →
      accept-plans.py rc=2. Load flake, not a persistent red gate: the
      bursts (2026-09-05 ×6, 2026-09-06 ×8, 2026-09-07, 2026-09-08)
      coincide with overnight-cycle launch storms, and each next 30-min
      accept tick re-runs green. Durable fix (raise or load-harden the
      5s watch-spawn wait in tests/scripts/test-dashboard-live.py) is
      kernel tests/ territory — FORBIDDEN this session — parked to
      backlog ("Kernel gate watch-test load flake"); recurrence
      self-heals on the next accept tick.
