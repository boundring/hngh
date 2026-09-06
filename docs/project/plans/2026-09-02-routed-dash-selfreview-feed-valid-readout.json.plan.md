<!-- plan: status=executed risk=normal accepted=2026-09-02T00:01:23Z routed-from=dash-selfreview:feed-valid:readout.json -->
# 2026-09-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-valid:readout.json`
at 2026-09-02T00:00:45Z. Alert text: [dash-selfreview] feed-valid:readout.json: unacceptable-now — unparsable: Extra data: line 331 column 1 (char 7876)

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
      Executed 2026-09-06T01:25Z (this wake): same alert identity and
      same finding as the 09-01 twin (this routing was the router's
      hourly re-bump of the still-live alert row inside its 24h dedup
      window — report-bodies 4734a5ae shows only hourly router
      occurrences, no new self-review firing). Root cause and fix are
      recorded in the 09-01 plan tick: shared-tmp rename race, fixed
      hngh-automation c129e61 (per-process tmp names for all feed
      writers + tests/test-readout-writers.py). Verify (met): same
      evidence — dashboard-self-review all-clear; automation `make
      test` green; hngh kernel `make test` green pre-ceremony (2855
      checks).
