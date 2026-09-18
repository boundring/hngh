# Beads + Jev propagation check — 2026-09-18 ~22:10Z

## Beads census (live `bd` state)

- 18 issues open, 1 closed (`hngh-4eh`), 0 in progress. Priority: P0=4, P1=7, P2=5, P3=2. Ready=14, blocked=4.
- First real loop closed: `hngh-4eh` (ts-fast-lane wrapper + `model.sh` beat-skip gate,
  commits `10cccb2d` + `d740d967`). Note: bead close status is `closed`, not `done`;
  a worker-created dependency (`hngh-4eh` blocked by `hngh-ypb`) had to be removed first —
  the dep direction was inverted (implementation does not depend on the assessment doc).
- Worker findings banked: census (crab), claims — no worker ever claimed a bead (deer),
  evidence linkage weak/fair 2/5 on the single closed bead (duck: no commit refs, files,
  validation, or close reason on the bead itself; repo-side `d740d967` names the bead).
- Dolt/tombstone semantics (pig/ox/ram/sauropod/owl/mosquito/lobster/ladybug): `bd delete`
  is a hard row delete with no tombstone; re-import of a stale export resurrects as open;
  closed issues sync as live rows (last-write-wins can reopen); conflicts halt exit 2 for
  manual resolve; git carries zero issue state without export. Propagation is only via
  `bd sync` / `bd dolt push/pull`. Practical rule: never re-import stale exports; push after closes.
- Follow-ups: mandate `bd close --reason` with hashes/files/validation; backfill linkage;
  add acceptance criteria to open backlog beads (6 flagged by `bd lint`).

## Jev combination readiness

- `automation/lib/typesafe.py` landed (`10cccb2d`), tested live (0.92, ~1s) and fail-closed
  (None without key). `model.sh` beat-skip gate landed (`d740d967`): SKIP_LOCAL bypasses
  both Unsloth sites, 30s cached verdict, fail-open to existing guards.
- Per-bead question map: `hngh-4m1` absorb = Choice; `hngh-vip` Unsloth = Noul beat-skip
  (already wired); `hngh-4j4` reviewer gates = Score per gap.
- bear decomposed jev-combo into 4 children; combination map pending synthesis.

## Collapse trajectory

- Graph: 50 seeded → 937 nodes, ~26% closed per badger; 392-wide ready vs 3 worker slots.
  Deep mode decomposes without bound (bili-cert branch). Beads (18) are the collapse
  mechanism: work tracked as beads closes; work tracked as graph nodes multiplies.
- 11 dead-route (opencode-go 403 era) failures remain terminal; all re-runnable on the
  working direct-OpenRouter route.
- Guidance: future work as small light-mode graphs per topic; keep this deep plan for
  the bili-cert audit only.

## Next three

1. `hngh-vip` (Unsloth midnight gate + defer guard consuming the wired beat-skip).
2. `hngh-4m1` (Choice-driven decision-inventory absorb).
3. Backfill `hngh-4eh` linkage + acceptance criteria on open beads.
