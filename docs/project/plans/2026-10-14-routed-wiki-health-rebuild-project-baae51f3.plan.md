<!-- plan: status=accepted risk=normal accepted=2026-10-14T10:06:31Z routed-from=wiki-health-rebuild:project:baae51f3 -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-21T10:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `wiki-health-rebuild:project:baae51f3`
at 2026-10-14T10:00:12Z. Alert text: wiki-health project: SPLIT -- 233 pages on disk, 99 in registry, meta 28 d old (threshold 14 d). rebuild attempted 2026-10-14T09:08:39Z -- insufficient. Fix: run the llm-wiki rebuild from an omp session with cwd ~/Projects/etc/kb/llm-wiki -- extension tool wiki_rebuild_meta; Hngh never writes meta/ rebuilds 7d: 1 attempts, 0 unfrozen

## Steps

- [ ] Delve: open research subject fail-20261014-wiki-health-rebuild-project-baae51f3 for wiki-health-rebuild:project:baae51f3; record disposition; then fix or park
      Verification: research subject fail-20261014-wiki-health-rebuild-project-baae51f3 present in research-subjects.txt with a recorded disposition; alert fixed or parked
