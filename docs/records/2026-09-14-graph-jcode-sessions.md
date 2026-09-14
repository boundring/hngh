# 2026-09-14 — graph-data: jcode session/swarm nodes

Task: deep-graph node `sg-builder-sessions`. Extends the operations-graph
builder (`automation/jobs/graph-data.py`, the canonical path — any note
naming `automation/dashboard/graph-data.py` is stale) with the jcode
session layer: one `jcode-session` node per `~/.jcode/sessions/
session_*.json` and one `swarm` hub per coordinator with >=1 subagent.
Builder contract is unchanged: `build()` still returns
`{generated_at, nodes, edges}` with `nodes[].{id,kind,label,state,detail}`
and `edges[].{src,dst,rel}`; existing kinds and tests are untouched.

## What landed

- **jcode-session nodes** (`automation/jobs/graph-data.py`, `_read_sessions`
  + `_emit_sessions`): id = `jcode:<session_id>` (id taken from the file's
  `id` field; filename stem equals it in the real layout), label =
  `short_name` with a 12-char truncated-id fallback. Detail is k=v pairs
  (viewer `parseDetail` caps at 12): status, model, provider (from
  `provider_key`), cwd (from `working_dir`), age (from `updated_at`,
  human units), pid (from `last_pid`), effort (from `reasoning_effort`
  when present). `tokens=N` is deliberately reserved, not emitted: no
  source exists yet (journal/budget ledger is phase 2), and the graph
  never invents numbers.
- **swarm hubs**: one `swarm:<coordinator_id>` node per coordinator that
  holds >=1 emitted subagent (a lone session spawns no hub), with
  `coordinates` edge hub->coordinator and `hosts` edges hub->each sub.
  Coordinator->subagent `spawns` edges are emitted only when both
  endpoints are emitted, so the no-dangling-edges contract test holds.
- **works-on edges**: optional `jcode:<sid>` -> `kernel` `works-on` when
  the session's `working_dir` sits inside the hngh repo (repo root walked
  from `registries_dir.resolve().parent.parent`; resolve-first so the
  server's relative `'config'` argument does not collapse to `.`).
- **State mapping** reuses the existing 4-state vocabulary, no new
  colors: status `Active` + `last_active_at` <= 10 min -> healthy;
  non-Active -> neutral; Active but > 10 min (or unparsable activity
  timestamp) -> stale. jcode writes `status` either as a plain string
  (`"Active"`) or as a one-key tagged dict (`{"Crashed": {...}}`, 5 of
  137 live files measured 2026-09-14); the tagged form is unwrapped to
  its key, anything else fails closed to non-Active.
- **Scale controls**: by default only sessions active within 24h are
  emitted, plus the parent-linked closure (both directions, transitive)
  so every spawned/hosts edge has both endpoints. Measured live:
  123 jcode-session nodes + 1 swarm hub (20 subs) against 291 files.
  `all_sessions=True` (new `build()` kwarg) lifts the filter and emits
  everything parseable. The dashboard server already forwards
  `GET /graph.json?all-sessions=1` as `all_sessions=bool(...)`; the
  refresh child's side of that contract is covered by
  `automation/tests/test-graph-feed-refresh.py` — no server edits here.
- **Injectable sessions dir**: `sessions_dir=None` defaults to
  `~/.jcode/sessions`; tests pass fixture dirs, never live data.

## Malformed-JSON decision: alerting, not skip

The task offered two fail-closed shapes and asked for one, tested and
documented. Chosen: **a malformed session file emits its node with state
`alerting`** (label = truncated filename stem, detail
`malformed session file (json unparsable)`) instead of being silently
skipped with a count. Rationale: this graph is an operator attention
surface — a corrupt session file is exactly the kind of thing the
operator should see in red, and the existing builder vocabulary already
uses alerting for missing guards and ghost packages. Malformed nodes are
never hidden by the 24h scale filter. A file that parses but has no
usable `id` (not a non-empty string) is treated as malformed too —
fail closed, no invented ids.

## Timestamps

jcode writes nanosecond-precision ISO (`2026-09-14T18:09:35.670154024Z`),
which `datetime.fromisoformat` rejects. `_parse_any_ts` truncates the
fraction to microseconds before parsing and returns None on anything
unparsable (callers treat None as stale/unseen — never an exception).

## Suite

`automation/tests/test-graph-data.py` gains `JcodeSessionNodes` (8
fixture tests: nodes/detail/edges, label fallback, state mapping,
malformed alerting, swarm hub edges, works-on in/out of repo, scale
filter + bidirectional parent closure + all-sessions escape, absent-dir
noop) over hermetic fixture files. `BuildGraph` now pins
`sessions_dir` to a nonexistent fixture path so the registry tests stay
hermetic. Full file: 19 tests, all pass except the pre-existing
`ServerWiring.test_view_registered_in_shell` failure (gitignored machine
`dashboard/index.html` no longer carries `vendor/three.min.js`; fails
identically on the pre-change baseline, machine-data drift, not this
slice). `test-plan-feed-graph.py` stays green (5 OK).
`test-graph-feed-refresh.py` green (8 OK).

## What is deliberately not here

- No `tokens=N` detail pair (no source; phase 2 journal/budget ledger).
- No dashboard-server.py changes: the `?all-sessions=1` query-string
  pass-through and cache slotting already exist on the server side.
- No journal parsing: journals are skipped files, read by nothing here.
