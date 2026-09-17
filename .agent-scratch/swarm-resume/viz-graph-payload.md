# Graph payload survey: /graph.json schema (viz-graph-payload)

## Pipeline

- Builder: `automation/jobs/graph-data.py` `build()` returns
  `{"generated_at": "<UTC ISO Z>", "nodes": [...], "edges": [...]}`.
- Server: `automation/dashboard-server.py` `graph_feed()` (line ~321) calls
  `graph_data.build()` and passes the payload through unfiltered; cached
  30s per mode slot (`_graph_cache[0|1]`); fail-soft to last good graph
  (fails closed only on cold-start exception). Served at
  `GET /graph.json`; `?all-sessions=1` selects slot 1 (extended-session
  build, `all_sessions=True` in the builder).

## Nodes

Each node: `{"id": str, "kind": str, "label": str, "state": str, "detail": str}`.
IDs are `prefix:name` namespaced and unique by construction (colliding
malformed/shadowed session stems get `-malformed` / `#2` suffixes).
Special id `"kernel"` is the fixed root node.

### kind enum (13, mirrored in graph-view.js `KINDS`)

| kind | id prefix | state logic |
|---|---|---|
| kernel | (none) | always `healthy` |
| leg | `leg:` | telemetry: `healthy` if last event <=2h, `stale` if older, `neutral` if no events 24h |
| service | `service:` | systemd unit active -> `healthy`, inactive -> `alerting`, no unit match -> `neutral` |
| package | `package:` | in-use + install path resolves -> `healthy`; in-use + ghost -> `alerting`; else `neutral` |
| seam | `seam:` | always `healthy` |
| spawn-path | `spawn:` | always `neutral` |
| patrol | `patrol:` | `alerting` if FAIL in reports.md trailing 24h else `healthy` |
| surface | `surface:` | always `neutral` (emitted once per surface, N patrol `watches` edges) |
| cap | `cap:` | `healthy` if declared in cadence-params.tsv/config.env, else `alerting` |
| guard | `guard:` | `healthy` if test file exists under automation/tests/, else `alerting` |
| research-line | `research:` | always `neutral` |
| jcode-session | `jcode:` | Active + last activity <=10min -> `healthy`; non-Active -> `neutral`; Active >10min or unparsable -> `stale`; malformed/shadowed -> `alerting` |
| swarm | `swarm:` | always `neutral` (one hub per coordinator with >=1 emitted subagent) |

### state enum (4, graph-view.js `STATES` / `COLORS`)

`healthy` (#3fb950), `stale` (#d29922), `alerting` (#f85149),
`neutral` (#8b949e). Kernel node renders with `kernel` (#f0f6fc)
regardless of state.

### detail convention

Free-text string of leading `k=v` tokens (regex `[a-z][a-z0-9-]*=\S+`,
max 12 parsed by `parseDetail()`) plus free tail. Consumer renders pairs
as rows and links http(s) values. Reserved: `tokens=` not emitted yet.

## Edges

Each edge: `{"src": str, "dst": str, "rel": str}`; both endpoints must be
emitted node ids (no danglers, no self-loops). `rel` enum observed in the
builder: `chain-admits` (kernel->leg), `bounded-by` (cap->kernel),
`runs` (kernel->service), `watched-by` (service->patrol),
`ghost-row-guard` (package->guard), `credential-seam` (kernel->seam),
`fail-soft-guard` (seam->guard), `launches-through` (kernel->spawn-path),
`drives-leg` (spawn->leg), `watches` (patrol->surface), `research-beat`
(research->kernel), `spawns` (session->session), `coordinates` /
`hosts` (swarm hub->sessions), `works-on` (session->kernel).
Consumer treats edges as opaque src/dst index pairs (plain depth-tinted
lines; focus edges highlighted blue); `rel` is not rendered or filtered.

## Consumer expectations (graph-view.js)

- Filter chips enumerate the static 13-kind and 4-state lists; unknown
  kinds/states in payload still render (colors fall back to
  `COLORS.neutral`, size to default) but get no chip.
- Layout pins `kernel` at origin and radially shells
  `jcode-session`/`swarm` nodes; filters are `!kindOff[kind] &&
  !stateOff[state]`.
- Panel/fetch: fetch `/graph.json` (mode appended), 10s abort timeout,
  `cache: 'no-store'`, 60s auto-refresh preserving camera/filter/selection.
