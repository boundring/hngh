<!-- plan: status=parked risk=normal accepted=- routed-from=research-beat:review-unparseable  cause=obsolete disposed=2026-09-17T07:00:25Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-16 — routed candidate

Routed by scripts/router-tick.py from alert identity `research-beat:review-unparseable`
at 2026-09-16T03:00:39Z. Alert text: research review verdict unparseable for fail-20260915-FOLLOWON (model unsloth:unsloth/Qwen3.8-27B-GGUF)

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-17T05:00:13Z re-occurred (dedup window expired)
- 2026-09-17T06:00:34Z re-occurred (dedup window expired)
- 2026-09-17T07:00:25Z re-occurred (dedup window expired)
