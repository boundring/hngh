# 2026-09-15 — Viz payload schema validation seam (`viz_schema.py`)

Deep-task node `schema-validate-seam`. Task: design and implement the
shared validation seam for the dashboard viz payloads — stdlib-only, no
jsonschema, `SCHEMA` constant, `validate(payload) -> (ok, detail)`,
fail-closed rc-2 contract.

**Status: landed.** `automation/jobs/viz_schema.py` +
`automation/tests/test-viz-schema-seam.py`. All four viz gates pass:
history 16, seam 32, patrol 23, version 14.

## Contract

| Family | Tag | Source of truth | Producer today |
|---|---|---|---|
| graph | `graph/1` | `automation/jobs/graph-data.py` `build()` | yes, unstamped (see gap) |
| patrol | `patrol/1` | `patrol.py` findings contract (`findings_md`, stdout `PASS|FAIL`, `patrol:<id>` alerts) + `docs/design/ui-evolve/patrol-payload-schema.md` | draft only |
| history | `history/1` | none yet — gated by `automation/tests/test-viz-schema-history.py`, producer owned by node `viz-history-payload` | no |

## API

- `validate(payload_text, tag=None) -> (ok, detail, warns)`; `tag=None`
  auto-detects from `payload["schema"]`.
- `validate_graph/validate_patrol/validate_history(text)` — pinned-tag
  adapters (the history one keeps the pre-existing gate green).
- `validate_payload(payload: dict, tag: str) -> issues` — issue dicts
  `{"severity": "ERROR"|"WARN", "code", "detail"}` (shared interface with
  the version-gate sibling test).
- `SCHEMA` — public tag -> {fields, required} table.
- CLI: `python3 automation/jobs/viz_schema.py [--schema TAG] payload.json`
  — rc 0 accept, rc 0 + `warn:` lines on stderr for the WARN lane,
  rc 2 fail closed, rc 1 usage errors (so rc 2 always means "payload
  rejected", never "bad invocation").

## Decisions

- **Envelope surface is versioned; entries are additively tolerant.**
  Unknown top-level keys fail closed (the committed history gate pinned
  this). Unknown scalar keys *inside* nodes/edges/entries warn and
  accept; unknown keys carrying nested objects/arrays fail closed (a
  nested payload could hide deeper schema violations).
- **Warn-only enums:** unknown `rel`/`state`/node `kind` values warn and
  accept (additive vocabulary drift). The patrol `cause` bestiary stays a
  fully open enum per the schema doc — unknown causes are data (the
  journal rounds files new causes by design), neither warned nor
  rejected.
- **Bool is not int** for patrol counts; patrol count invariant
  `pass_count + fail_count >= patrol_count` enforced.
- Structural fail-closed set: malformed JSON, missing/non-string/wrong/
  unknown `schema`, unknown envelope keys, missing required fields,
  wrong types, duplicate node ids / duplicate entry keys, self-loop
  edges, dangling edge endpoints, nested payloads behind unknown keys.

## Known wiring gap (gated, not papered over)

`graph-data.build()` does not stamp `"schema": "graph/1"` yet, so live
`/graph.json` output fails closed under the validator until the builder
adds the stamp (one-line follow-up in `build()`; the seam's e2e test
proves a stamped payload validates clean and round-trips). Wiring the
gate into the dashboard server is likewise a follow-up, not done here.

## Validation

- `python3 automation/tests/test-viz-schema-seam.py` — 32 OK.
- `python3 automation/tests/test-viz-schema-history.py` — 16 OK
  (committed gate, now loading the real seam instead of its contract
  stand-in).
- `python3 automation/tests/test-viz-schema-patrol.py` — 23 OK;
  `test-viz-schema-version.py` — 14 OK (sibling gates, converged via the
  shared contract).
- CLI smoke: rc 0 clean, rc 2 wrong-type + missing file, rc 1 usage.
