<!-- plan: status=executed risk=normal accepted=2026-09-06T14:01:17Z routed-from=tree-skew:hngh -->
# 2026-09-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `tree-skew:hngh`
at 2026-09-06T14:00:36Z. Alert text: [oversight] tree-skew: Projects/etc/hngh dirty and uncommitted >4h ×94

## Steps

- [x] Whitelist check + handoff/commit of the stalled edit
      - [x] Whitelist check + handoff/commit of the stalled edit
      Verification: dirty-tree whitelist clean; stalled edit committed or handed off
      Resolved 2026-09-11: whitelist rerun (oversight-tick.sh:121 regex) left
      exactly one non-whitelisted dirty file, automation/.lesson-harvest-handoffs
      — a pure counter tick (43→52) written by cadence/day/01-lesson-harvest.sh
      inside the kernel repo without being landed; every other dirty path was
      whitelisted machine state. Root-cause fix in the owning job instead of the
      ceremony loop: advance_markers now commits the counter directly (same
      posture as cadence/hour/30-kernel-ledger-sync.sh — explicit path, refuse
      on staged work, no kernel code surfaces, no push), so future ticks never
      re-dirty the tree. The 2026-09-10 sibling (bridge-refused) was a prior
      beat's refusal, not an unresolved edit. Automation script suite green.
