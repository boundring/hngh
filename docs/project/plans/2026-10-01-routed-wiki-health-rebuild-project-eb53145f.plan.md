<!-- plan: status=accepted risk=normal accepted=2026-10-01T21:05:43Z routed-from=wiki-health-rebuild:project:eb53145f -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-08T15:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `wiki-health-rebuild:project:eb53145f`
at 2026-10-01T15:00:41Z. Alert text: wiki-health project: SPLIT -- 132 pages on disk, 99 in registry, meta 15 d old (threshold 14 d). rebuild attempted 2026-10-01T09:08:39Z -- insufficient. Fix: run the llm-wiki rebuild from an omp session with cwd ~/Projects/etc/llm-wiki -- extension tool wiki_rebuild_meta; Hngh never writes meta/ rebuilds 7d: 1 attempts, 0 unfrozen

## Steps

- [ ] Delve: open research subject fail-20261001-wiki-health-rebuild-project-eb53145f for wiki-health-rebuild:project:eb53145f; record disposition; then fix or park
      Verification: research subject fail-20261001-wiki-health-rebuild-project-eb53145f present in research-subjects.txt with a recorded disposition; alert fixed or parked
