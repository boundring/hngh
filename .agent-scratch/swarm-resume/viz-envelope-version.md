# Megastructure viz spec: versioning and envelope (viz-envelope-version)

Status: PROPOSAL (read-only exploration artifact). Grounded in
`automation/jobs/viz_schema.py`, `automation/jobs/graph-data.py`,
`automation/tests/test-viz-schema-version.py`, and
`docs/design/ui-evolve/patrol-payload-schema.md`.

## 1. Version field

- Use the existing seam convention, not `$id`/JSON Schema: the validator is
  deliberately stdlib-only (no `jsonschema`), so there is no `$id` URL to
  resolve. The versioned surface is the `"schema"` string on every payload:
  `"graph/1"`, `"patrol/1"`, `"history/1"` (viz_schema.py `SUPPORTED`).
- Format: `<family>/<integer-major>`; ASCII, no dots. An unknown or
  non-string `"schema"` value is an ERROR (fail closed) today; keep that.
- If a static `$id`-like identifier is ever wanted for documentation, define
  it as `urn:hngh:viz:graph:1` in the spec doc only; it must not become a
  required payload field (the envelope field set is frozen per version).
- Note the existing drift to reconcile: `patrol-payload-schema.md` drafts
  `"schema": "hngh.patrol.v1"` while the seam enforces `"patrol/1"`. The
  spec should pin `"patrol/1"` and update the draft doc, or vice versa --
  pick one and make the seam the authority.

## 2. generated_at format

- `graph/1`: `%Y-%m-%dT%H:%M:%SZ`, UTC, second resolution
  (graph-data.py line ~536, `now.strftime`). Type str; keep it.
- Spec rule: RFC 3339 UTC with literal `Z`, no fractional seconds, no
  offsets. Validation stays type-only (str) in the seam for now; a stricter
  regex check is an optional WARN-to-ERROR upgrade in a future version.
- Each family has its own timestamp field name (`generated_at` for graph,
  `run_ts`/`date` for patrol, per-entry `ts` for history); do not unify
  names within one version -- that is a breaking change.

## 3. Fail-closed rules (already implemented; spec codifies them)

Exit contract: CLI exits 0 accept, 2 on any ERROR, 1 usage. WARN never
changes exit code.

- Malformed: non-object payload, non-object node/edge/entry ->
  `entry-not-object` ERROR; malformed JSON upstream fails closed.
- Unknown envelope keys (top level) -> fail closed. The top-level key set
  plus `"schema"` value IS the versioned surface; additive envelope drift
  must bump the version.
- Missing required fields, wrong types -> ERROR.
- Duplicate node ids (`duplicate-node-id`), self-loop edges
  (`self-loop-edge`), dangling edge endpoints (`dangling-edge-endpoint`)
  -> ERROR.
- Nested payloads hidden behind unknown keys -> ERROR
  (`unknown-key-nested-payload`).
- Additive WARN lane (accepted, flagged): unknown scalar-valued extra keys
  INSIDE nodes/edges/entries; unknown `kind`/`state`/`rel` enum values.
  Enum extension therefore does not require a version bump; consumer falls
  back to neutral rendering (graph-view.js behavior).
- Serialization discipline: fixtures must survive
  `json.loads(json.dumps(...))` (viz-docs-serialization lesson); state this
  in the spec so producers emit plain JSON types (no tuples/datetime objects).

## 4. Single-schema file location

- One file, one authority: `automation/jobs/viz_schema.py` is the shared
  validation seam for all viz payload families. Keep every family's
  required fields, types, and enums defined ONLY there (docstring already
  states "one source of truth and one future gate" per family).
- The spec doc (`docs/design/ui-evolve/`, e.g. extend
  `patrol-payload-schema.md` pattern with a `viz-envelope.md`) describes
  the contract in prose but MUST NOT carry a second machine-readable copy
  of the schema. Tests (`test-viz-schema-{version,patrol,history,seam}.py`)
  import the seam module rather than restating rules.
- Producers (graph-data.py, future patrol/history emitters) import the
  constants (`NODE_KINDS`, `NODE_STATES`, `REL_VALUES`) from the seam or
  are gated by seam tests; consumers (graph-view.js) mirror enums but fall
  back gracefully on unknown values per the WARN lane.

## 5. Version bump policy

- Additive, non-breaking change (new node kind, new rel value, new
  scalar-valued optional key inside nodes/edges/entries): NO bump. The WARN
  lane already accepts these; extend the seam's enum/tuple lists and warn
  lane, update tests.
- Breaking change (new/removed top-level envelope key, changed field type,
  changed required set, changed timestamp semantics): bump the major:
  `graph/1` -> `graph/2`. The old validator keeps accepting old payloads
  (SUPPORTED is a tuple; multi-version support is in-place), producers
  switch to the new `"schema"` value, and unknown top-level keys fail
  closed so an old consumer never silently mis-renders a new payload.
- Deprecation: a version may be dropped from `SUPPORTED` only after
  producers no longer emit it; unknown `"schema"` values already fail
  closed, so removal is safe for consumers.
- Every bump updates, in one slice: the seam (field sets, TYPES,
  SUPPORTED), the gate tests, the spec doc, and all producers' `"schema"`
  stamps -- verified by `test-viz-schema-version.py` (which already checks
  both library API and CLI rc contract).

## 6. Gaps found (follow-ups for the owning lane)

- `graph-data.py build()` does not yet stamp `"schema": "graph/1"`; the
  gate currently fails closed on live output by design (staged rollout).
  Landing the stamp is the next mutation.
- `dashboard-server.py` does not call the validator on `/graph.json`
  output; wiring `validate_payload` (rc 2 -> serve last-good) would close
  the producer seam end to end.
- Patrol draft doc's `"hngh.patrol.v1"` vs seam's `"patrol/1"` naming drift
  needs reconciliation.
