# Prior art: (d) swarm members stuck in non-terminal status ('queued'/'spawned') with no GC reaper

Task: prior-art-d-stuck-queued-gc. Date: 2026-09-15.
Scope: upstream jcode repo (github.com/1jehuang/jcode) issues + PRs, open and
closed; mitigation commits 3cfac3fca and d87f04afd; local mirror
~/src/jcode (read-only). Companion evidence:
sibling artifact `audit-swarm-member-construction-statuses.md` (same
directory) establishes the code-side facts cited below.

## Verdict

- Prior art: FOUND, but only partial overlap. No existing issue or PR
  describes the exact candidate-(d) failure (persisted `queued`/`spawned`
  members restored verbatim after reload with no process and no reaper).
  Issue #1249 (open, Sep 14 2026) independently reports the same *symptom
  class* - "Nothing ever reaps a member that never attached" - for members
  stuck at `running / startup queued` with live_attachments: 0, and
  explicitly requests a startup timeout + failure transition. It is the
  closest prior art and is currently unaddressed.
- The two cited mitigation commits exist and do what the task description
  says, but they do NOT cover the ghost gap. Neither commit's reaper touches
  `queued` or `spawned` statuses; the reload-recovery passthrough for those
  statuses persists at HEAD.
- Filing upstream is WARRANTED, but as a comment/addendum on #1249 or a
  narrow new issue cross-linking it, not a duplicate.

## Mitigation commit 1: 3cfac3fca - "Prevent leaked jcode client processes from stacking up"

- Link: https://github.com/1jehuang/jcode/commit/3cfac3fca
- Full SHA: 3cfac3fca7b2c57504dea4a6ea8beb26019cdf45, dated Sat Jul 18
  2026, in master at HEAD of the local mirror (verified via
  `git merge-base --is-ancestor`).
- Verified identical content in local mirror (`git show 3cfac3fca --stat`)
  and on GitHub (webfetch).
- Two leak paths addressed:
  1. TUI orphan exit: detect abandoned controlling terminal via
     /proc/self/stat tty_nr (new `terminal_liveness` module in
     crates/jcode-tui/src/tui/app/terminal_liveness.rs, +93 lines) and quit
     the client on input EOF in local/remote/disconnected loops. This kills
     orphaned *client processes*; it does not touch swarm member *state*.
  2. Server-side idle worker reaper: new `reap_idle_spawned_workers` loop
     hooked into the terminal-member GC interval
     (crates/jcode-app-core/src/server.rs +111). Candidate filter in
     `idle_spawned_worker_reap_candidates` (swarm.rs, now ~:277-289 at HEAD):
     `report_back_to_session_id.is_some()` AND `role != "coordinator"` AND
     (`status == "ready"` OR `member_status_is_terminal(status)`) AND
     `last_status_change.elapsed() >= idle_after` (default 30 min,
     `JCODE_SWARM_IDLE_WORKER_REAP_SECS`, 0 disables).
- Key gap vs candidate (d): the status filter is exactly
  `ready || terminal`. Members in `queued`, `spawned`, or `running` are
  never candidates. The commit's own test
  (`idle_spawned_worker_reap_selects_only_finished_idle_spawned_agents`)
  asserts a `running` spawned worker is NOT reaped. So a member wedged in
  `queued`/`spawned`/`running`-with-no-process is invisible to this reaper
  forever.
- Intent match: the commit message explicitly frames the reaper as the
  "backstop for coordinator cleanup" for workers that "finished (ready/
  terminal status)" - it deliberately does not attempt liveness detection
  of unfinished workers. #1249 later shows what that omission costs.

## Mitigation commit 2: d87f04afd - "fix(swarm): garbage collect terminal members"

- Link: https://github.com/1jehuang/jcode/commit/d87f04afd
- Full SHA: d87f04afdf229c1cc24f31eb95f01fa182bb4537, dated Sat Jul 11
  2026, in master at HEAD of the local mirror (verified).
- Verified identical content in local mirror and on GitHub.
- What it does:
  - Defines `member_status_is_terminal` = completed | done | failed |
    stopped | crashed | closed | disconnected (swarm.rs ~:227-233 at HEAD).
  - `expired_terminal_member_ids` (swarm.rs ~:235-246): terminal members
    with `last_status_change.elapsed() >= retention` (default 24 h,
    `JCODE_SWARM_TERMINAL_MEMBER_RETENTION_SECS`).
  - `prune_expired_terminal_swarm_members` GC loop every 60 s
    (server.rs), skipping any session with a live agent runtime.
  - `member_consumes_swarm_capacity` = NOT terminal: terminal members no
    longer count toward `MAX_SWARM_MEMBERS` (comm_session.rs), so ghost
    members in non-terminal statuses still consume the spawn budget.
  - Persistence layer (swarm_persistence.rs +114): `terminal_since_unix_ms`
    recorded on snapshot; startup loading prunes members terminal-past-
    retention and rewrites the snapshot so records do not resurrect.
- Key gap vs candidate (d): GC only fires for the terminal set. `queued`,
  `spawned`, and `running` are not terminal, so a member stuck in those
  statuses never enters this GC. Worse, because
  `member_consumes_swarm_capacity` is true for them, each ghost consumes
  the runaway-prevention spawn budget, exactly the wedge #1249 describes.

## Do the mitigation commits address the ghost gap? No.

The ghost gap (sibling artifact, mapping table): reload recovery
`recover_member_status` (swarm_persistence.rs:341-391) maps running ->
crashed, ready -> stopped, non-surviving headless non-terminal -> crashed,
but non-headless `spawned` and `queued` pass through verbatim at :389.
Verified still true at mirror HEAD (`git show HEAD:...swarm_persistence.rs`).
Neither reaper covers them:

| Status | Idle reaper (3cfac3fca) | Terminal GC (d87f04afd) | Reload recovery | Net effect |
|---|---|---|---|---|
| queued | no (filter is ready/terminal) | no (not terminal) | passthrough | ghost forever, consumes capacity |
| spawned | no (filter is ready/terminal) | no (not terminal) | passthrough | ghost forever, consumes capacity |
| running | no (deliberate; see test) | no (not terminal) | -> crashed on *reload* only | ghost until a server restart reload |

Note: `running` ghosts are eventually cleaned IF a full server reload
happens (running -> crashed on reload, then terminal GC). `queued` and
`spawned` ghosts survive even that: reload restores them verbatim, still
non-terminal, still capacity-consuming. That is the deepest part of the
gap, and it is unique to queued/spawned.

Local live repro (2026-09-14/15, suspend/resume): the sibling artifact
cites 24 worker sessions stuck Active. Current durable state
(~/.jcode/state/swarm/*.json, read-only check) shows member-level statuses:
bug swarm `completed:20, running:2`; dolphin swarm `running:4, ready:1`.
The `running` ghosts will be cleared on next server reload (recovery maps
them to crashed); the `queued`/`spawned` ghosts (if any persisted) would
not be. 71 `"status":"queued"` strings in the bug snapshot are plan-item
statuses, not member statuses (per sibling artifact construction-site
analysis).

## Upstream prior art survey (open + closed)

Direct searches (all open+closed unless noted):
- "swarm stuck", "swarm ghost OR reaper OR leak", "startup queued OR never
  reaps OR stuck queued", "swarm zombie OR phantom OR wedged OR never
  attaches", "live_attachments OR member timeout OR startup timeout",
  "worker stuck active OR cleanup swarm", "swarm suspend OR hibernate OR
  stuck active" (no results for the last).

Findings, ranked by relevance:

1. **#1249 (OPEN, Sep 14 2026) - strongest prior art.**
   "Visible swarm spawn fails at matching versions: worker session never
   persisted, then coordinator wedges forever at 'startup queued'"
   https://github.com/1jehuang/jcode/issues/1249
   - 18 visible-spawn workers died at startup (no session file for
     --resume); every dead worker stayed `running / startup queued` in
     swarm state forever, 30+ min after death: "Nothing ever reaps a
     member that never attached, so the coordinator waits forever."
   - Explicitly requests: "Time out a member stuck at startup queued with
     live_attachments: 0 and mark it failed, so the coordinator does not
     wait forever."
   - This is the same no-reaper-for-non-attached-members failure class as
     candidate (d), reported independently one day before our repro. It
     focuses on the spawn-time `running/startup queued` variant, not the
     reload-passthrough `queued`/`spawned` variant. No labels, no
     assignee, no linked PR as of 2026-09-15.

2. **#1119 (OPEN, Aug 31 2026).** "Visible swarm spawn can use stale
   current binary and lose new session"
   https://github.com/1jehuang/jcode/issues/1119
   - Root-cause ancestor of #1249: visible spawn resumes a session that
     was never persisted -> "No session found" -> worker never starts,
     never reports READY. Comment 2 identifies Session::save() skipping
     untouched sessions. Labels P1, regression, reproducible,
     needs-decision; no fix merged.

3. **#1070 (OPEN, Aug 26 2026).** "Fresh-spawn resume command opens
   Terminal instead of a new Jcode instance"
   https://github.com/1jehuang/jcode/issues/1070
   - Third spawn-path variant: worker never attaches (live_attachments: 0),
     blocking READY forever. #1249 cites it as related.

4. **#1143 (OPEN, Sep 1 2026).** "Completed swarm agents remain pinned in
   the live footer and reappear across swarm pages"
   https://github.com/1jehuang/jcode/issues/1143
   - Adjacent, not duplicate: *terminal* members lingering in the live UI
     for the 24 h retention window (presentation-layer filter request).
     Its root-cause section correctly characterizes the reaper as a
     process-lifecycle backstop, not a liveness/GC policy for the live
     strip. Confirms the maintainer knows the reaper's scope is narrow.

5. **#1090 (CLOSED, fixed-pending-release, Aug 28 2026).** "Daemon
   idle-exit kills live headless swarm workers 5 minutes after the
   coordinator detaches" https://github.com/1jehuang/jcode/issues/1090
   - Inverse failure (daemon reaps *live* workers because in-process
   workers are invisible to the idle monitor). Relevant background: the
   codebase's occupancy/liveness signals around non-terminal members are
   known-fragile. Its fix treats "headless member in a non-terminal,
   non-ready status as occupancy" - the same status classification
   candidate (d) needs, from the opposite direction.

6. **#1031 (OPEN, Aug 22 2026).** "[Feature] Add an authoritative runtime
   contract for task liveness and recovery"
   https://github.com/1jehuang/jcode/issues/1031
   - Umbrella feature request for a unified liveness/recovery state
     machine (stale_suspected, observer_unknown, reconciliation before
     cancel/retry). The ghost gap is a member-state instance of the
     problem class it describes, though it targets task records rather
     than swarm member records.

7. Contextual/adjacent: #940 (P0, OPEN - daemon replays detached commands
   after stopping workers; process-kill side, not member-status side),
   #512 (P1, OPEN - spawns die at boot / 'unknown done' reporting),
   #1210 (OPEN - run_plan driver exits when ready tasks have no assignable
   worker). None describe a member-status GC reaper for non-terminal
   statuses.

PR survey (open+closed, "swarm reap OR garbage collect OR stuck"): no PR
implements a non-terminal-member reaper. The GC/reaper work landed as
direct commits by the maintainer (d87f04afd, 3cfac3fca), plus
33cd27330 ("fix(server): prune stale swarm recovery state", Jul 19 2026 -
dormant *plan* retention after 7 days, not member statuses) and
fe5797a03 ("fix(server): drop long-terminal swarm members from
SwarmStatus broadcasts"). No follow-up commit after 3cfac3fca touches the
queued/spawned passthrough (git log --since=2026-07-18 over swarm.rs and
swarm_persistence.rs confirms).

## Is filing upstream warranted? Yes - as a cross-link/comment, not a fresh duplicate.

- The symptom class (no reaper for never-attached/stuck non-terminal
  members) is independently corroborated by #1249 and #1119/#1070. Filing
  a brand-new top-level issue would partially duplicate #1249.
- The *novel* content our repro adds to the record:
  1. The reload-recovery passthrough (`queued`/`spawned` restored verbatim
     even though no process survives, swarm_persistence.rs:389) is a
     second, distinct entry path into the same stuck state that #1249's
     spawn-time path does not cover. Ghosts entered this way survive even
     a server restart.
  2. Ghost members in any non-terminal status permanently consume
     `MAX_SWARM_MEMBERS` capacity (member_consumes_swarm_capacity), which
     is how a wedge becomes self-sustaining (matches #1249's 18-worker
     wedge impact section).
  3. A machine suspend/resume reproduces the stuck state for live
     processes too (24 worker sessions stuck Active, 2026-09-14/15) -
     i.e., it is not limited to the visible-spawn launch path.
- Suggested upstream action: comment on #1249 with the reload-passthrough
  mechanism + suspend/resume repro + the capacity-consumption angle,
  cross-link #1119/#1070/#1031, and propose the narrow fix family: (a)
  startup/attach timeout for spawned members (as #1249 requests), (b)
  reload recovery mapping spawned/queued -> crashed (mirroring the
  running->crashed and ready->stopped precedents in the same function),
  (c) optionally an idle age limit for *any* non-terminal spawned member
  with live_attachments 0. Fix (b) is a two-line change in an existing,
  tested recovery function.
- Repo constraint observed: "Issue creation is restricted in this
  repository" (banner on every issue-list page). New issues cannot be
  filed by outside accounts; commenting on #1249 may also require
  permissions. Filing may therefore require the maintainer or an operator
  action.

## Method/repro notes

- Commit verification: `git show <hash> --stat` plus full diffs in the
  local mirror; webfetch of both GitHub commit pages returned identical
  diffs. `git merge-base --is-ancestor` confirms both in master HEAD.
- HEAD gap verification: `git show HEAD:crates/jcode-app-core/src/server/
  swarm_persistence.rs` (recover_member_status passthrough) and
  `.../server/swarm.rs` (idle_spawned_worker_reap_candidates filter,
  member_status_is_terminal set) confirm the gap persists at HEAD.
- Issue/PR search: GitHub web search over the repo's issue and PR trackers
  with the query list above; every candidate title opened and read in
  full. No search of closed PR bodies beyond titles/labels was possible
  without auth; commit-log greps (queued, stuck, reap, garbage, attach)
  over the local mirror compensated.
- Local state inspection: python json parse of
  ~/.jcode/state/swarm/*.json (read-only) to separate member-level from
  plan-item statuses.
