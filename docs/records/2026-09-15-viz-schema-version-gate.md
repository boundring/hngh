# 2026-09-15 — viz schema version-gate acceptance tests (node schema-tests-version-gate)

Task: hermetic acceptance tests for the version-gate behavior of the viz
payload validation seam, `automation/tests/test-viz-schema-version.py`,
no `dashboard/` dependency.

## What landed

- `automation/tests/test-viz-schema-version.py` — 15 cases in 8 classes
  (14 version-gate cases + the `probe-verify-suite` self-check added in
  3e4834df), all against `automation/jobs/viz_schema.py` (the seam
  landed in ea265b86; interface settled by direct DM with that node):
  - each family accepts its own current version (`graph/1`,
    `patrol/1`, `history/1`), asserted through both the library API
    (`validate_payload` -> issue list, ERROR rejects) and the CLI;
  - `'schema'` key absent fails closed, including the tag=None
    auto-detect path;
  - unknown future version `graph/99` fails closed with a detail
    mentioning both versions (received and expected), library and CLI;
  - malformed JSON fails closed (CLI/bytes level);
  - non-string schema values fail closed (int, None, float, list, dict,
    bool), including auto-detect;
  - unknown-envelope-key fails closed (the envelope surface is the
    versioned surface); additive scalar keys inside nodes/entries are
    the WARN lane: accepted with a warning flag, CLI rc 0 + warn line;
  - rc contract asserted once end to end: valid -> 0, fail-closed ->
    exactly 2 (distinct from 0 and from harness-error 1);
  - serialization discipline (viz-docs-serialization lesson): every
    valid fixture survives `json.loads(json.dumps(payload))` losslessly
    and still validates.
- `automation/Makefile` — wires the new gate (and the history sibling)
  into `make test` next to the existing patrol gate.

## probe-verify-suite definition (node probe-verify-suite)

Per the committed probe pattern (probe-head-drift /
probe-schema-seam / probe-tmp / probe-worktree-scan): a small headless
check living inside `test-viz-schema-version.py`, callable standalone
(`--probe`, exit 0 verified / 1 drift) and invoked by the suite itself
(`TestProbeVerifySuite`), printing one machine-parsable line:

```
PROBE-VERIFY-SUITE as-of-utc=<ts> head=<short> \
  suite(automation/tests/test-viz-schema-version.py)_clean=yes \
  seam(automation/jobs/viz_schema.py)_clean=yes
```

It certifies, byte-for-byte against `HEAD:` at
`git rev-parse --show-toplevel`: (1) the gate suite that ran equals the
committed suite, and (2) the CLI binary the suite invokes equals the
committed seam module. Rationale: with concurrent swarm committers, an
uncommitted edit to a shared gate means an auditor reviews different
bytes than the ones that produced the green run (the probe-head-drift
lesson). A not-yet-committed suite is reported (`committed=no`), not
failed, so the probe works in the pre-first-commit window. The probe
validated itself on first run: it flagged exactly the uncommitted probe
edit it was introduced in (suite_clean=no) and went green only after
that commit landed.

## Verification

- `python3 automation/tests/test-viz-schema-version.py` — 14/14 OK.
- `python3 automation/tests/test-viz-schema-history.py` — 16/16 OK;
  `test-viz-schema-patrol.py` — OK.
- `automation/ make test` — ALL PASS with the wiring in place.

## Known open question (cross-node, not resolved here)

Two `patrol/1` shapes currently coexist: the committed patrol gate
(408b6a40) validates a `{schema, findings: [...]}` envelope with its own
in-file contract validator, while the seam (ea265b86) validates the
design-doc envelope (`results`/`rounds`/`alerts`) under the same tag.
Both gates are green because each tests its own validator, but the tag
must not acquire two production meanings; one of the two contracts (or a
bump to `patrol/2`) needs to win before any emitter ships. Flagged to
the seam owner and the coordinator.
