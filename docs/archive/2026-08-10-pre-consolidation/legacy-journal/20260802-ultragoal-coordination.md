# Ultragoal Coordination Snapshot — 2026-08-02

**Plan:** `hngh-coordination-20260802`
**Story:** `G001-coordination`
**Producer:** opencode/Sisyphus, GPT-5.6 Luna, local-first, $0 remote spend

## Agent Lanes

- **Luna / Sisyphus:** bounded W5.1/W5.2 implementation in the Hngh main
  worktree. No M7, MCP, systemd, or benchmark edits in this lane.
- **Hermes / Terra:** contracts, queue integration, and final review. Terra's
  handoff is explicit: finish the current W5 slice, then Terra integrates
  queue-v3.
- **MiMo:** evidence-only triage of adoption artifacts 49, 50, 51, 54 and
  pending queue items 52/53. No Hngh source edits.
- **Local Hermes check-in:** suggested rechecking `*read-eval*` at
  `wire-protocol.lisp:135`; shared evidence already records that constraint as
  present, so this is stale/redundant rather than a new implementation task.

## Shared State

- Night queue: 58 artifacts in `.done/`; pending items are 52 and 53 plus the
  `.done/` directory entry. Do not renumber or duplicate those tasks.
- Hngh main: `79db55f`, ahead of origin by 9; working tree contains existing
  documentation/session work plus the uncommitted W5 files.
- Queue-v3 lane: `40785b3`; Hermes reports validation, task-queued events, and
  the daemon close/read race fix ready for integration.
- A3 lane: `8a00a74`; retain until Terra's integration decision.
- Shared plan: `.hermes/plans/2026-08-02_095923-hngh-coordination-program.md`.

## W5 Evidence

- `data/squads.lisp`: local `day-queue` and `night-ralph` definitions.
- `squads/day-queue.spec` and `squads/night-ralph.spec`: executable local-only
  specs.
- `src/plugins/mission-control.lisp`: registry validation, launcher bridge,
  ownership-gated down/status, and prompt-forward state.
- `tests/unit/test-mission-control.lisp`: deterministic registry/lifecycle
  tests with an injected command runner.
- Mission-control suite: 21/21. `make build`: exit 0. Both squad spec parser
  smokes: exit 0.
- Full-suite runs have intermittent unrelated daemon socket/Emacs live-test
  failures; no W5 test fails. One serial run reached 999/999 before the
  environment race recurred.

## Decision Boundary

Current next action is **Terra integration review**, not another feature wave:

1. Luna posts the W5 files and evidence.
2. Terra reviews/rebases queue-v3 and reruns the full suite on the integrated
   tree.
3. MiMo returns the adoption evidence matrix.
4. Only after that do we create approved W5.3/W5.4 tasks.

No commit was made in this session because the current user message did not
explicitly request the irreversible commit action; the tree remains available
for owner/Terra integration.

## Safety Review Addendum

Hermes/Terra review artifact `~/.hngh-night/artifacts/55-w5-squad-state-safety-review.md`
found that the first W5 implementation wrote ownership after launching and
used direct superseding writes. The repair now:

- publishes state through same-directory temp-file plus `rename-file`;
- persists `:starting` before launch;
- transitions to `:running` only after launch success;
- persists readable `:failed` evidence on launch or transition errors;
- permits `squad-down` only for exact Hngh-owned `:running` state.

Focused mission-control verification is now **28/28**, including launcher
failure, atomic rename failure, lifecycle, registry, and prompt-forward tests.
This supersedes the earlier 21-check evidence for the W5 safety claim; the
Ultragoal ledger remains at G002 complete plus this review follow-up because
its completed story cannot be rewritten after the fact.
