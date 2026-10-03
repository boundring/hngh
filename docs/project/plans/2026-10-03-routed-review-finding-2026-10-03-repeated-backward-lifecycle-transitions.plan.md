<!-- plan: status=accepted risk=normal accepted=2026-10-03T18:06:04Z routed-from=review-finding:2026-10-03:repeated-backward-lifecycle-transitions -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-10T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-03 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-03:repeated-backward-lifecycle-transitions`
at 2026-10-03T11:00:42Z. Alert text: repeated backward lifecycle transitions in research-lines.tsv: crystallized → reviewed for synth-2026-10-03-1 (f9159a16), synth-2026-10-03-2 (65883603), ...enable-verify (2227fc3c), ...bench-ti (484df8a9), and 5dfa8329 (5221d5c6). Status regression from a terminal-looking state is either by-design (undocumented) or a state-machine bug. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
