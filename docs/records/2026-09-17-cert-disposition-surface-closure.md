# 2026-09-17 — cert disposition surface closure: orphaned candidate certs
# are moot by mechanism; commit-subject-on-main is the whole registry

## Assignment (gate follow-up, extends abandoned-5d9bd1ff)

The a4f-log-sweep/reflog-unreachable critique gate asked: where is a
candidate certificate's disposition recorded, and what closure does
cert `a3286b78` (subject of unreachable commit `5d9bd1ff`) require?
Gate facts established before this record:

- `a3286b78` and its replacement `a25e82bb` (subject of
  `cf36b6f2`, which IS reachable from `main`) appear in neither
  `~/.hngh-automation` nor `~/.hngh` (grep -rl both empty).
- Beyond `a3286b78`, two MORE certs are declared only on dangling
  commits, both 2026-08-25 (outside the 09-13..16 sweep window, same
  orphaned-metadata class): `65820f40` (commit `4887c0b8`,
  `scripts/dashboard-readout` +201/-21; content landed via
  `17260b1a`) and `9e1b74ee` (commit `a28b7a45`, `Makefile` +6 test
  lines; all six lines verified present on `main`'s `Makefile`).

## Resolution: no ledger tracks certs; the registry is the subjects on main

This is now of record and moot-by-mechanism, per the two records this
one extends:

- docs/records/2026-09-17-certificate-ephemerality-of-record.md: the
  kernel mints each certificate in memory, renders it to stdout once,
  and destroys it; no kernel `src/` path writes a certificate to any
  store. The only durable trace of any mint is the commit subject
  `hngh: candidate <64hex>`.
- docs/records/2026-09-17-candidate-reconciliation-closure.md: the
  machine-side surface census (store record.lisp files, queue/report
  ledgers, dashboard timelines) found zero certificate rows; the
  feasible reconciliation rung is label-to-content recomputation from
  git alone (patrol check, `c2bda901`).

This closure re-verified the surface question against the live MCP
read tools (`queue-report`, `dashboard-readout`): their timeline and
queue payloads carry run receipts and generic rotation/event hashes,
zero 64-hex certificate ids. There is no cert-id registry anywhere:
not in the kernel store, not in the automation ledgers, not in either
home. "Commit subject on `main`" is the whole registry — 298 unique
candidate certs across main's labeled subjects, counted at closure
time.

Consequence: an orphaned cert (declared only on a commit unreachable
from `main`) has no second record to correct or supersede. Recording
`a3286b78 = superseded-by-a25e82bb` in a ledger would fabricate the
very artifact the ephemerality record proves does not exist. The
disposition record below is the closure the ceremony allows: prose of
record, not ledger surgery.

## Disposition of the four orphaned certs

All four are the same class: a candidate whose labeled commit never
landed, while the commit's actual content DID land through a later,
differently-labeled commit on `main`. The hash over the content
differs between attempts (timestamps and context bytes feed it), so
the landing carries a different cert label — that is the mechanism,
not a defect:

- `a3286b78` — unreachable `5d9bd1ff` (guard-table row +9); content
  byte-equivalent to reachable `cf36b6f2` (cert `a25e82bb`), verified
  identical added-line sets; landing row present on `main`
  (`tests/scripts/test-loop-history-guard.py`, the `a5520fb2`
  exemption).
- `a25e82bb` — the landing twin itself; reachable, nothing to close.
- `65820f40` — unreachable `4887c0b8` (2026-08-25,
  `scripts/dashboard-readout` +201/-21); content landed via
  `17260b1a` (itself a candidate-labeled commit, cert `325a190c`),
  reachable.
- `9e1b74ee` — unreachable `a28b7a45` (2026-08-25, `Makefile` +6
  test-runner lines); all six lines verified present on `main`'s
  `Makefile` at closure time (one probe line shown per gate method).

No content loss in any of the four; no ledger row is owed for any of
them; the recon patrol's content-binding leg would PASS each landing
twin if its lookback window ever reached them (the 2026-08-25 pairs
predate the window and the guard-table pair ages out of the 24-commit
lookback naturally).

## The census wording defect, corrected

The wip-family-census beat (2026-09-17, session transcript, not a
committed record) described `a3286b78` as an object-store-missing git
object "rebuilt during rebase". That is mechanically wrong:

- `a3286b78` is a 64-hex external certificate id embedded in a commit
  subject, not a sha1 git object name. `git cat-file -t
  a3286b78f8d9bab1cd6f34072c9c4c429e6ad2ffd67a6ae1adc3c64eb4944901`
  fails with `fatal: Not a valid object name` — re-verified at
  closure time.
- The gate's premise (a missing object to investigate) therefore
  dissolves: there is no object, and never was one to lose. The
  census's own content conclusion ("the exemption row landed via
  `cf36b6f2`, no content loss") was correct; only the object framing
  was confused. This record is the correction of record; no committed
  census text carried the error, so no text edit is owed.

## What this record lands

Documentation only (machine free-commit lane; kernel `src/` and
`tests/` untouched):

1. This record: the disposition-surface resolution, the four-cert
   disposition table, and the census wording correction.
2. No ledger rows, no exemptions-file rows, no code changes: the
   orphaned certs are moot by mechanism (ephemerality), and the
   reconciliation check needs no extension for commits outside its
   declared lookback.

Back to the [records index](README.md).
