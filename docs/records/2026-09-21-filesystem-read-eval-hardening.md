# 2026-09-21 — filesystem read-eval hardening

## Summary

Closed the read-eval poisoning seam in the filesystem record transport
(bead hngh-d5u / hngh-v2q certificate-path slice).

## Defect

`src/adapter/filesystem.lisp` `read-line-form` read stored record lines
with `read` under the ambient `*read-eval*` (true by default). A
malicious or corrupt store line carrying `#.` reader syntax therefore
executed arbitrary code at replay time — the store is operator-facing
data, so a poisoned record file was an code-execution vector on every
`store-entries` replay.

## Fix

`read-line-form` now binds `*read-eval*` to NIL for the read: the `#.`
reader macro is refused, the read error is caught by the existing
handler-case, and the corrupt line is a TRANSPORT-FAULT. Fails closed;
stored lines are data, never code.

## Verification

Failing test first: `tests/adapter/test-filesystem.lisp` gained a check
that appends a `#.42` line to a live store file and asserts
`store-entries` signals TRANSPORT-FAULT (it previously replayed the
evaluated `42`). After the fix, `make test` is green — 2932 checks
passed, and the README machine-counted line was bumped to 2,932 for the
doc-numbers guard.

## Scope

Certificate-path candidate: `src/adapter/filesystem.lisp`,
`tests/adapter/test-filesystem.lisp`, `README.md`, `CHANGELOG.md`, and
this record. The TOCTOU write-hole between `existing-keys` and
`append-line` (`src/adapter/filesystem.lisp:119-123`) remains open under
bead hngh-d5u; locking is a separate design decision.