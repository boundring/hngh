# Coordinator handoff - 2026-09-15 ~14:58 UTC (pre ambient-enablement restart)

## Why this file exists
The jcode shared server was restarted to activate ambient mode
(config approved by operator, applied + TOML-validated). This session
(session_dolphin_1789472126868_b6fe1d64bcfa1dc6) dies with the old server.
Resume with: jcode --resume session_dolphin_1789472126868_b6fe1d64bcfa1dc6
or read this file and continue fresh.

## Immediate post-restart checklist
1. Verify ambient started: ls ~/.jcode/ambient/ (state.json should appear),
   tail ~/.jcode/ambient/logs/ambient-2026-09-15.log
   Also try: JCODE_DEBUG_CONTROL=1 jcode ambient status
2. First ambient cycle: garden-only (proactive_work=false), provider
   opencode-go / glm-5.3, budget 75k/day, min interval 30m. Expect a
   catch-up cycle shortly after boot. Confirm it did NOT touch kernel src/
   (garden-only = memory ops only) and did not burn zai.
3. Quota check: ~/.hngh/tools/quota-check.py (zai + ocgo live probes,
   --json mode; Kimi has no API endpoint - dashboard only, RESERVED until
   2026-09-19 17:19, then small tasks only).
4. Swarm-resume state: N artifacts in this dir (worklist.json tracks the
   original 133-node graph; most explores DONE - count .md files vs
   worklist). Remaining useful leaves: none critical - the two parent
   syntheses (viz-design.md, viz-history-work-parent.md) are DONE.
   Ceremony-bound implement nodes (sg-*, retry-render-pipeline,
   retry-viz-schema) are PARKED FOR OPERATOR (kernel surface).
5. Consolidation option: write a synthesis record of the full exploration
   (viz-design ladder + hist spec set) to docs/records/ - ask operator.

## Key paths
- Artifacts: /home/bricker/Projects/etc/hngh/.agent-scratch/swarm-resume/
- Original graph: ~/.jcode/state/swarm/session_session_bug_1789409372212_64cac2ea81d2ca9d.json
- Quota tool: ~/.hngh/tools/quota-check.py
- Config backups: ~/.jcode/config.toml.bak-pre-external-off,
  ~/.jcode/config.toml.bak-pre-ambient-on
- CI drift record: docs/records/2026-09-15-ci-patch-id-drift.md (corrected
  by 8899934c; cure = ceremony: --no-binary patch_id_of + re-register)
- hngh-automation gate: verified GREEN (morning patrol alert was stale)

## Rules in force
- Max ~3 concurrent workers; stop lifecycle=ready workers promptly (6-slot cap)
- Workers DM coordinator on completion (completion contract in prompts)
- Kimi RESERVED until 7d reset; zai for batches, ocgo secondary + now ambient
- Kernel src/tests/Makefile/hngh.asd + repo-root scripts/: ceremony only
