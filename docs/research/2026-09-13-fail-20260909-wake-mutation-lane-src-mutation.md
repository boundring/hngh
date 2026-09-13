# fail-20260909-wake-mutation-lane-src-mutation — the :wake-mutation kernel src mutation parked at the operator boundary

## Question

Routed alert `wake-mutation-lane:src-mutation` (2026-09-09T16:24:54Z, row
`9a50bcda`): the wake-mutation-lane rotation beat parked at the machine
boundary because the `:wake-mutation` kernel src mutation is operator-only
(2026-09-03 staging plan boundary). Can a machine session fix this, or is
park the correct terminal disposition?

## Evidence read

- `docs/records/2026-09-09-wake-mutation-lane-rotation.md` — the beat already
  ran the full governance loop as far as the machine boundary allows: park
  alert filed, advisory model review, ten-principle verdict, certificate over
  the docs candidate, green `make test` (2855 checks). The src change itself
  was explicitly parked, not attempted.
- `src/adapter/mutation.lisp:8-9` — the closed mutation vocabulary is
  `(:none :prepare-candidate :stage :commit :push)`; `:wake-mutation` is not
  a member, and the record's exact-landing path still matches (verified this
  session: vocabulary unchanged at lines 8-9).
- `src/packages.lisp:247` — `hngh.adapters.mutation` exports the vocabulary
  and evidence constructors; no wake symbol present (verified).
- `src/main.lisp:1469` and `:1588` — the dispatch member checks refuse any
  action outside the closed set (the record cited `:1371`/`:1490`; the
  structure moved with intervening edits, the refusal semantics did not).
- `automation/STATE.md:16117-16527` — the router routed the alert into plan
  `2026-09-09-routed-wake-mutation-lane-src-mutation`; one dedup suppression
  at 18:00:13Z, no further occurrences since.
- `docs/project/queue.md:13,47,98,110-112` — the `wake-mutation-lane` row
  stays `queued`: rotation completes only when the operator lands the src
  change.

## Doctrine applied

Machine sessions do not touch kernel `src/`, `tests/`, `Makefile`, or
`hngh.asd` (2026-09-03 staging plan boundary; operator-flexibility doctrine
docs/records/2026-09-09-operator-flexibility-doctrine.md §2 allows such work
only through the certificate ceremony with a green `make test` — an authority
a machine session holding this plan does not carry for src). The fix is
therefore outside this session's mutation surface by design, exactly as the
rotation record anticipated.

## Findings

- The park is a boundary fact, not an unresolved defect: every machine-side
  prerequisite (proposal, certificate, review receipt, green gate) already
  landed on 2026-09-09.
- The `:wake-mutation` vocabulary change is confined to five named kernel
  surfaces: `src/adapter/mutation.lisp:8-9` (vocabulary + fresh-evidence
  mapping), `src/packages.lisp:247` (export), `src/main.lisp` dispatch
  member checks (now `:1469`/`:1588`), and `tests/adapter/test-mutation.lisp`
  (refuse/execute fixtures).
- Open operator-design work recorded in the rotation record: the
  fresh-evidence shape for a wake (pin-file `:file-sha256` today vs new
  evidence kinds for MAC/lease/last-seen).

## Recommended next line

Park. No machine session can close this alert; it closes only when the
operator lands the src change through the same dogfood ceremony with a green
`make test`, at which point the queue row `wake-mutation-lane` rotates and
the alert's fix lands with it. Re-open a research line only if the operator
asks for the fresh-evidence design to be drafted before the landing slice.
