# 2026-09-21 — Filesystem record transport: probe/read race fails closed

## Finding

Bead hngh-d5u narrowed to a TOCTOU window in
`src/adapter/filesystem.lisp`: `existing-keys` (probe-file then
read-lines, :98-101) and `store-entries` (probe-file then read-lines,
:128-134) both trust `probe-file` before opening. A record file that
passes the probe but fails open — deleted, replaced by a directory, or
made unreadable in the window — surfaced a raw file error, not the
adapter's `TRANSPORT-FAULT`, so a consumer could see an unexpected
condition type exactly when the transport was in an abnormal state.

## Change

`read-lines` (:92) now wraps the open/read in a `handler-case` that
converts any error to `TRANSPORT-FAULT`. Both racy callers route
through this one function, so the fix is single-site; the corrupt-line
and read-eval refusals (which already signal `TRANSPORT-FAULT`) pass
through unchanged. Root-existence and append-fault paths keep their
existing handlers (:119, :104-111).

## Verification

Failing test first: `tests/adapter/test-filesystem.lisp` replaces the
record file with a directory at the same path (probe passes, open
fails deterministically) and asserts both `store-entries` and
`store-record-run` signal `TRANSPORT-FAULT` — red before, green
after. Full gate `make test` green.

## Residual

The :123→:125 duplicate-check-then-append window remains a theoretical
duplicate under concurrent external writers; the kernel is
single-threaded and concurrent store writers are outside the adapter's
threat model (fail-closed duplicate detection stays best-effort).
