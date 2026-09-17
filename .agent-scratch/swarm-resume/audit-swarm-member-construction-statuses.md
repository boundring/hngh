# Audit: SwarmMember status values, construction sites, and GC-layer coverage

Scope: /home/bricker/src/jcode (read-only). Status field is a free `String`
(`SwarmMember.status`, crates/jcode-app-core/src/server/state.rs:188-204);
the typed vocabulary is `SwarmLifecycleStatus`
(crates/jcode-swarm-core/src/lib.rs:136-151): Spawned, Ready, Running,
RunningStale, Completed, Done, Failed, Stopped, Crashed, Queued, Blocked,
Pending, Todo, Other(String).

## Construction sites (production, non-test)

1. client_session.rs:384-394 (subscribe/attach path): `status: "ready"`
   (client_session.rs:394). Pre-existing members keep their status and only
   re-attach channels (client_session.rs:384-392).
2. comm_session.rs:495-505 (spawn path, the "SwarmMember construction" of a
   spawned worker): `status` is `("running", "startup queued")` when the spawn
   carries a startup message, else `("spawned", "launching client")`
   (comm_session.rs:495-498).
3. headless.rs:243-250: `status: "ready"` (headless.rs:250).

So 'queued' is NOT the only non-terminal non-ready spawn status: 'spawned'
occurs at comm_session.rs:498, and 'running' at comm_session.rs:495-497.
'blocked' is never assigned to a member anywhere; it exists only in the
SwarmLifecycleStatus enum and in todo-item statuses
(crates/jcode-app-core/src/tool/todo.rs:1270, jcode-app-core/src/mission.rs:25).

## Status mutation sites (update_member_status family, swarm.rs:1291-1349;
   member.status assignment at swarm.rs:1394)

Production call sites and literal assigned:
- "ready": client_session.rs:275, 876-878, 1639-1641, 939 (direct
  `member.status = "ready"` on subscribe); client_lifecycle.rs:3064;
  live_turn.rs:155.
- "running": client_actions.rs:1127; client_lifecycle.rs:3217; comm_session.rs
  (spawn-with-startup-message, comm_session.rs:496 via construction);
  comm_control.rs:814-816 (task dispatch), 1182.
- "queued": comm_control.rs:1740-1742 (task assigned to member, before the
  soft interrupt is queued).
- "completed": client_actions.rs:1149; comm_control.rs:1033.
- "failed": client_actions.rs:1163, 1081 (area); comm_control.rs:1081;
  client_lifecycle.rs:3080; client_disconnect_cleanup.rs area (failed on
  disconnect-while-running is "crashed", below).
- "stopped": client_lifecycle.rs:3384 (cancel; detail "cancelled"),
  3452; client_disconnect_cleanup.rs:277 ("stopped", detail "disconnected");
  reload recovery maps persisted ready -> Stopped (swarm_persistence.rs:358-369).
- "crashed": client_disconnect_cleanup.rs:279 ("crashed", "disconnect while
  running"); swarm_persistence.rs:341-391 (reload recovery maps persisted
  Running -> Crashed, and non-surviving headless -> Crashed).
- Plan-item statuses ("pending", "running_stale", "done", etc., e.g.
  swarm.rs:581, comm_control.rs:467/966/1622) are VersionedPlan item statuses,
  not SwarmMember.status; "running_stale"/"pending"/"todo"/"blocked" are never
  written to a member in production code.

## Reachable member statuses in practice

ready, running, queued, spawned, completed, done (persisted/recovered;
terminal predicate swarm.rs:228-231), failed, stopped, crashed. Enum
values running_stale, blocked, pending, todo: parse-able via
`SwarmLifecycleStatus::from` / Other passthrough (lib.rs:186-204) but no
production writer for members. closed/disconnected: recognized as terminal by
`member_status_is_terminal` (swarm.rs:228-231) but never assigned; only the
detail string "disconnected" occurs (client_disconnect_cleanup.rs:277).

Key answer: 'queued' is not the only non-terminal non-ready spawn-time
status. 'spawned' (comm_session.rs:498) is set at construction for spawns
without a startup message, and 'running' for spawns with one
(comm_session.rs:495-497). 'blocked' never occurs as a member status.

## GC layer coverage per status

1. Idle reaper (`idle_spawned_worker_reap_candidates`, swarm.rs:277-289;
   30 min default, swarm.rs:261-263): covers spawned workers
   (`report_back_to_session_id` set, role != coordinator) whose status is
   "ready" OR any terminal status, idle >= threshold. Statuses covered: ready,
   completed, done, failed, stopped, crashed, closed, disconnected.
2. Terminal GC (`expired_terminal_member_ids`, swarm.rs:235-246; retention
   window, broadcast filter member_in_status_broadcast swarm.rs:219-222):
   covers exactly member_status_is_terminal: completed, done, failed,
   stopped, crashed, closed, disconnected.
3. Salvage (`salvage_assignments_of_dead_member`, swarm.rs:318-361;
   DeadMemberSalvage swarm.rs:293-317): triggered by
   `member_status_is_dead` = failed, stopped, crashed (swarm.rs:253-255).
   It does not change the member status; it requeues/fails plan items the
   dead member held.
4. Reload recovery (`recover_member_status`, swarm_persistence.rs:341-391):
   running -> crashed ("recovered after reload while running", :346-352);
   ready -> stopped ("idle worker / client not restored", :358-369);
   non-terminal headless (except completed/done/failed/stopped) -> crashed
   (:371-385). spawned/queued pass through unchanged (final `(status, detail)`
   at :389) - a gap worth noting: a persisted "spawned"/"queued" member is
   restored as-is even though no process survives restart.

### Mapping table

| Status | Written at (member) | Terminal? | Dead? | Idle reaper | Terminal GC | Salvage trigger | Reload recovery |
|---|---|---|---|---|---|---|---|
| ready | client_session.rs:394,275; headless.rs:250; client_lifecycle.rs:3064; live_turn.rs:155 | no | no | yes | no | no | -> stopped (swarm_persistence.rs:358-369) |
| running | client_actions.rs:1127; client_lifecycle.rs:3217; comm_control.rs:816,1182; comm_session.rs:495 | no | no | no | no | no | -> crashed (:346-352) |
| queued | comm_control.rs:1742 | no | no | no | no | no | passthrough (:389) - potential ghost |
| spawned | comm_session.rs:498 (construction only) | no | no | no | no | no | passthrough (:389) - potential ghost |
| completed | client_actions.rs:1149; comm_control.rs:1033 | yes | no | yes | yes | no | kept (:375-385 headless) |
| done | persisted only (no production writer) | yes | no | yes | yes | no | kept headless |
| failed | client_actions.rs:1163; comm_control.rs:1081; client_lifecycle.rs:3080 | yes | yes | yes | yes | yes | kept |
| stopped | client_lifecycle.rs:3384,3452; client_disconnect_cleanup.rs:277; reload recovery | yes | yes | yes | yes | yes | kept |
| crashed | client_disconnect_cleanup.rs:279; reload recovery | yes | yes | yes | yes | yes | set by recovery |
| closed / disconnected | never assigned; terminal predicate only (swarm.rs:228-231) | yes | no | yes | yes | no | n/a |
| running_stale, blocked, pending, todo | no member writers (plan-item / todo-item only) | no | no | no | no | no | parse as-is |

## Conclusions

- 'queued' is not the only non-terminal non-ready status: 'spawned' is the
  initial status of every spawned worker without a startup message
  (comm_session.rs:498), 'queued' is a transient post-spawn dispatch state
  (comm_control.rs:1742), 'running' is both a spawn state (startup message,
  comm_session.rs:495-497) and a work state. 'blocked' never occurs for
  members in practice.
- Recovery gap: reload restores persisted 'spawned' and 'queued' members
  verbatim (swarm_persistence.rs:389), where no live process exists; they
  match neither the terminal GC nor the idle reaper until they transition.
