<!-- plan: status=accepted risk=normal accepted=2026-09-10T19:01:32Z routed-from=push-blocked:openrouter-key-hngh -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `push-blocked:openrouter-key-hngh`
at 2026-09-10T19:00:18Z. Alert text: push origin main declined: GitHub push protection — OpenRouter API key in docs/research/2026-09-10-lobehub-api-research.md:11,81 (commit 13007a8, local-only ledger sync). Operator action: rotate the key, redact lines 11+81 (forward commit alone will NOT clear the block — the scan covers the push range), then allowlist-or-repush. Blocks 3 unpushed commits incl. gate fix d78a622 (quota-routing hermeticity, make test now green rc=0)

## Steps

- [ ] Delve: open research subject fail-20260910-push-blocked-openrouter-key-hngh for push-blocked:openrouter-key-hngh; record disposition; then fix or park
      Verification: research subject fail-20260910-push-blocked-openrouter-key-hngh present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-10T20:00:18Z re-occurred (dedup window expired)
