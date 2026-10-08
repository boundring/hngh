<!-- plan: status=accepted risk=normal accepted=2026-10-08T10:07:02Z routed-from=wiki-health-rebuild:project:eb53145f -->
<!-- attempt: 3 -->
<!-- expires: 2026-10-15T10:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-08 — routed candidate

Routed by scripts/router-tick.py from alert identity `wiki-health-rebuild:project:eb53145f`
at 2026-10-08T10:00:42Z. Alert text: wiki-health project: SPLIT -- 136 pages on disk, 99 in registry, meta 22 d old (threshold 14 d). rebuild attempted 2026-10-08T09:10:14Z -- insufficient. Fix: run the llm-wiki rebuild from an omp session with cwd ~/Projects/etc/llm-wiki -- extension tool wiki_rebuild_meta; Hngh never writes meta/ rebuilds 7d: 7 attempts, 0 unfrozen

## Steps

- [ ] Delve: open research subject fail-20261008-wiki-health-rebuild-project-eb53145f for wiki-health-rebuild:project:eb53145f; record disposition; then fix or park
      Verification: research subject fail-20261008-wiki-health-rebuild-project-eb53145f present in research-subjects.txt with a recorded disposition; alert fixed or parked
