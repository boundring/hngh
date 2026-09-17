# Audit: PersistedAwaitMembersState lifecycle and leak analysis

Repo: ~/src/jcode (read-only audit).
Files: `crates/jcode-app-core/src/server/comm_await.rs`,
`crates/jcode-app-core/src/server/await_members_state.rs`,
`crates/jcode-app-core/src/server/durable_state.rs`.

## Verdict

Orphaned `PersistedAwaitMembersState` files are NOT reaped immediately or
proactively, but they do not leak forever. Every file is bounded by a TTL and
reaped by the startup sweep (`resume_background_awaits`, which calls
`all_pending_await_members_including_expired`, a stale-pruning scan) at the
next server start, and opportunistically by any `load_state`/session lookup.
Worst case: an expired-pending file lingers for up to 24h past its deadline
(or for the remainder of the current process lifetime if the server never
restarts and no reload/session lookup touches the directory). Final-response
files linger up to 6h past resolution under the same conditions.

## TTLs (await_members_state.rs)

- L11: dir = `jcode-await-members` under runtime dir (durable_state.rs:38-40).
- L12: `FINAL_STATE_TTL = 6h` (file has `final_response`).
- L13: `PENDING_STATE_TTL = 24h` past `deadline_unix_ms`.
- L130-137 `is_stale`: final states stale when `now - resolved_at > 6h`;
  pending states stale when `now - deadline > 24h`.

## Every write site

1. `await_members_state.rs:168-170` `save_state` -> `save_json_state`
   (durable_state.rs:59-67, `write_json_fast`). Sole persistence primitive.
2. `await_members_state.rs:176-208` `ensure_pending_state`:
   reuses existing pending state if present (L188), else creates + `save_state`
   at L206. Called from `comm_await.rs:413-426` (new await request).
3. `await_members_state.rs:210-225` `persist_final_response`: rewrites the
   file with a terminal `final_response` (L223 `save_state`). Called from:
   - `comm_await.rs:192` in `finalize_await` (completion L246-253, timeout
     L272-275, empty-swarm L238-242, background-expired-at-request L449-472,
     startup-expired finalize L646-653).
   - `comm_await.rs:509`: blocking request already past deadline.
4. `comm_await.rs:432-437`: duplicate request rewrites delivery prefs
   (`background/notify/wake`) via `save_state`; deadline preserved.

There is no other writer.

## Every delete site

1. `durable_state.rs:47-53` in `load_json_state`: if the loaded file is
   `is_stale`, it is `remove_file`d. Reached via `load_state`
   (await_members_state.rs:164-166), which fires for any keyed lookup:
   new/duplicate await requests (comm_await.rs:344) and
   `refresh_pending_state` (comm_await.rs:174-176) inside the watcher loop.
2. `await_members_state.rs:252-277`
   `all_pending_await_members_including_expired`: full-directory scan; stale
   files are removed at L268-271 (`remove_file`). This is the only bulk
   sweeper. Triggered by:
   - Startup sweep: `server.rs:1375-1384` spawns `resume_background_awaits`
     on every server (re)start (comm_await.rs:608-680). Note: it filters to
     `state.background` AFTER the scan, but the pruning in the scan happens
     regardless of the filter, so blocking-pending orphans are also reaped
     here once stale.
   - Per-session lookup: `pending_await_members_for_session`
     (await_members_state.rs:227-234, via
     `all_pending_await_members` L239-245) -> called from
     `crates/jcode-app-core/src/tool/selfdev/reload.rs:194` during session
     reload bookkeeping. Also prunes stale as a side effect.

There is NO delete on: watcher completion (completion keeps the file in
final form for the 6h TTL), session end, swarm-member GC, or swarm teardown.
No periodic in-process GC timer exists.

## Driver-death scenario (run_plan driver dies)

- If only the requesting agent task dies but the server lives, the detached
  watcher (comm_await.rs:223-302) keeps running independently: it finalizes on
  completion or deadline and rewrites the file to final state, so no leak
  beyond the 6h final TTL. If all socket waiters disconnect, a BLOCKING watch
  exits without finalizing (comm_await.rs:266-269) and leaves the pending file
  behind.
- If the whole server process dies: pending files persist on disk. On next
  startup, `resume_background_awaits` finalizes expired background states as
  timeouts (comm_await.rs:629-655) or respawns live ones (L658-671), and the
  same scan deletes any file already stale. Blocking-pending orphans are not
  resumed but are deleted by the same stale-pruning scan once
  `deadline + 24h` passes (checked at each startup / reload lookup).
- Reload tool messaging (reload.rs:188-220) relies on the same mechanism:
  blocking awaits are surfaced for rerun; background awaits auto-resume.

## Summary table

| Event | File effect | Evidence |
|---|---|---|
| New await request | create (pending) | await_members_state.rs:206 |
| Duplicate request prefs change | rewrite | comm_await.rs:436 |
| Completion / timeout / empty swarm | rewrite to final | comm_await.rs:192; await_members_state.rs:223 |
| Blocking request past deadline | rewrite to final | comm_await.rs:509 |
| Startup expired background | rewrite to final | comm_await.rs:646-653 |
| Stale at keyed load | delete | durable_state.rs:47-53 |
| Stale at directory scan (startup / reload lookup) | delete | await_members_state.rs:268-271 |
| Session end / member GC | nothing (no hook) | n/a |

Definitive answer: files are eventually reaped (bounded by 6h/24h TTLs plus
the next startup sweep or reload-time lookup), never immediately on driver
death, and never leak permanently unless the server process never restarts
and no `load_state`/directory scan ever runs again.
