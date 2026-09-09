<!-- plan: status=parked risk=normal accepted=2026-09-04T18:01:27Z routed-from=service-state:unsloth-down  cause=obsolete disposed=2026-09-09T15:27:53Z reason="identity fired once 2026-09-04T18:00Z and never re-occurred in ~13k STATE.md rows (live alerts re-fire hourly, cf. gate-red/tree-skew); recovery groundwork executed in 2026-09-03-capabilities steps 1-"-->
# 2026-09-04 — routed candidate

Routed by scripts/router-tick.py from alert identity `service-state:unsloth-down`
at 2026-09-04T18:00:45Z. Alert text: unsloth serving down while llama-server.service inactive (recoverable via service-ctl)

## Steps

- [ ] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo
