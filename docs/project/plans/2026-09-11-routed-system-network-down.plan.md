<!-- plan: status=executed risk=normal accepted=2026-09-11T04:20:00Z routed-from=system-network-down  cause=obsolete disposed=2026-09-11T04:00:49Z reason=router escalation-park after 3 occurrences; superseded 2026-09-11T04:20Z — step executed: root cause found (flag never probed the network), fix landed in automation/jobs/system-awareness.sh, disposition recorded -->
# 2026-09-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `system-network-down`
at 2026-09-11T01:00:12Z. Alert text: [oversight] system-network-down: critical resource flag set

## Steps

- [x] Delve: open research subject fail-20260911-system-network-down for system-network-down; record disposition; then fix or park
      Verification: research subject fail-20260911-system-network-down present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Outcome

- Root cause: the network-down headroom predicate (`model=fail && peers=0`)
  never probed the network. The model endpoint is the LOCAL unsloth proxy
  (127.0.0.1:8888) and `peers=0` is just the operator's peer devices asleep
  (steamdeck offline 4h, brickus 207d) — so every local-model hiccup at
  night flagged "network-down": nightly 2026-09-08..09-11, identity routed
  2026-09-04..09-11 (7 plans, all parked undiagnosed).
- Fix (2026-09-11): automation/jobs/system-awareness.sh probes the WAN
  directly (curl api.github.com — any HTTP answer = up, same convention as
  probe-model-route) and network-down = WAN fail; model endpoint + peers
  stay as reported evidence fields. Regression test
  automation/tests/test-system-awareness.sh (A: model fail + WAN ok must
  NOT flag; B: WAN fail must flag). Verification: test PASS, automation
  `make test` green.
- Disposition recorded: research-subjects.txt + research-dispositions.tsv
  row fail-20260911-system-network-down (action=adopted).
- Note: origin push may refuse while the kernel gate is red
  (kernel-gate-red-rc2, known blocker owned by other plans); push-on-demand
  standing authorization applies.

## Occurrences

- 2026-09-11T02:00:21Z re-occurred (dedup window expired)
- 2026-09-11T03:00:33Z re-occurred (dedup window expired)
- 2026-09-11T04:00:49Z re-occurred (dedup window expired)
