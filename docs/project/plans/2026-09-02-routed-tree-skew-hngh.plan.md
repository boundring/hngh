<!-- plan: status=executed risk=normal accepted=2026-09-02T00:01:23Z routed-from=tree-skew:hngh -->
# 2026-09-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `tree-skew:hngh`
at 2026-09-02T00:00:45Z. Alert text: [oversight] tree-skew: Projects/etc/hngh dirty and uncommitted >4h ×40

## Steps

- [x] Whitelist check + handoff/commit of the stalled edit
      Verification: dirty-tree whitelist clean; stalled edit committed or handed off

## Execution record (2026-09-08)

Whitelist check found a gap, not a stalled human edit: the skew set was
machine state the whitelist never learned. `automation/research-lines.tsv`
(+ `research-dispositions.tsv`, same class) are beat-written research
lifecycle state — the standalone-repo `auto_wl` always carried
`research-lines.tsv`, but the subtree move into the kernel repo never
gained the equivalent, so every research transition kept the tree
perpetually dirty and re-armed the alert on any 4h quiet commit window.
Fix: both tsvs added to `hngh_wl` (4a28207); the stalled state committed
(690bb03). docs/ churn stays un-whitelisted by design — the hourly
30-kernel-ledger-sync owns it, and dirt persisting >4h there means the
sync broke, which is genuine skew. Stray untracked `automation/--model`
junk (botched CLI redirect, no owner) removed.

Prerequisite detour: the automation gate was red (rc=2) from an
incomplete fail-first sync — e2b03ce took 6 of archived e9ff90f's 10
files, skipping both research tests and the Makefile line registering
test-failfirst.sh, so pre-fail-first tests ran against the fail-first
beat. Sync completed (26ae21f); make test green (rc=0); the six
