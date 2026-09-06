<!-- plan: status=accepted risk=normal accepted=2026-09-04T18:01:27Z routed-from=service-state:unsloth-down -->
# 2026-09-04 — routed candidate

Routed by scripts/router-tick.py from alert identity `service-state:unsloth-down`
at 2026-09-04T18:00:45Z. Alert text: unsloth serving down while llama-server.service inactive (recoverable via service-ctl)

## Steps

- [ ] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo
