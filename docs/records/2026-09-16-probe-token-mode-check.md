# 2026-09-16 — probe-model-route: token file stat-checked to exactly 0600

## Problem

`scripts/probe-model-route` `reachable()` read the reviewer conf's
`token-file` with a bare `Path(...).read_text()` and no permission
enforcement: a loose-perm token file (say 0644) was silently trusted and
its secret sent in the Authorization header. Every other credential
reader in the tree already fails closed here — the kimi/ocgo/zai readers
in `automation/lib/model.sh` stat-check mode 600 and skip the backend
otherwise — so the probe was the odd one out.

## What landed

- `scripts/probe-model-route` `reachable()` — before reading, the token
  file is stat'd and anything not exactly `0o600` raises
  `ValueError("<path>: token file too open (mode NNNN); chmod 0600
  required")`, flowing through `probe()`'s existing ValueError arm to
  `(False, message)` and the one-file form's exit 1 with the message on
  stderr. Docstring updated to state the posture. `import stat` added;
  nothing else in the script touched.
- `tests/scripts/test-probe-model-route.py` — new `ProbeTokenMode`
  class, written red first:
  - `test_too_open_token_file_refused`: conf pointing at a 0644 token
    file → `reachable()` raises ValueError naming the path and 0600;
    `probe()` returns `(False, ...)`; the subprocess one-file form exits
    1 with "too open" on stderr and no network round-trip.
  - `test_tight_token_file_still_probes`: the 0600 control with
    `urlopen` stubbed (BytesIO answer) still probes `True`.

## Gate

Full `make test` green (2931 lisp checks, exit 0); the probe suite runs
9/9 OK. No README count change: the doc-numbers guard only recomputes
the lisp suite count.

## Ceremony

Landed through `scripts/omp-bridge --ceremony` over the script, the
test, and this record (certificate-gated commit `hngh: candidate
<hash>`, certificate auto-push when origin answers). CHANGELOG.md is
written but excluded from this commit: the same region carries another
machine session's still-uncommitted entry, and the commit stages only
this slice's files; the coordinator sweeps the CHANGELOG into a
ledger-sync commit.
