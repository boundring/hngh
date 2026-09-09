# 2026-09-09 — wake-mutation-lane rotation beat: boundary proposal certified, src mutation parked

## Scope

Rotation beat for the queue's `wake-mutation-lane` row (backlog
"Certificate-bound wake mutation lane (boundary amendment)"; r17 record
`2026-08-25-r17-wake-peer.md` is the surface being bound). The beat runs
the governance loop as far as the machine boundary allows: the
`:wake-mutation` kernel src mutation is operator-only for machine
sessions (2026-09-03 staging plan), so the certificate lands the
boundary-proposal documentation plus the park alert, and the src change
is parked, not attempted.

## The proposal (from the backlog row, unchanged)

One certificate for one wake of one pinned peer: a `:wake-mutation`
action in the mutation vocabulary, rechecked against fresh evidence
(pin, MAC, current lease, last-seen fact) immediately before the
action, executed behind the mutation executor port, refused on stale or
missing facts. Rung 17 already ships the request surface —
`wake-ports`, `wake-result` (`:issued | :refused | :fault`), and
`wake-peer` with strict pins parsing and the `:federation` admission
receipt — so the lane binds that existing request to the certificate
machinery rather than inventing a new one.

## Mutation vocabulary (read, not modified)

`src/adapter/mutation.lisp:8-9`:

```lisp
(defparameter +mutation-actions+
  '(:none :prepare-candidate :stage :commit :push))
```

The `dispatch-issue-cert` and `dispatch-mutation-check` action checks
(`src/main.lisp:1371`, `src/main.lisp:1490`) refuse any verb outside
this closed set (exit 2). `:wake-mutation` becomes admissible only by
the src change itself — which is exactly the boundary this beat parks
at, and why no machine-side certificate can name it today.

## Loop stages executed

1. Park alert: `scripts/report-queue --add alert ... --identity
   wake-mutation-lane:src-mutation` — row `9a50bcda`
   (2026-09-09T16:24:54Z) in `docs/project/reports.md`, body
   `docs/project/report-bodies/2026-09-09T16:24:54Z-alert-9a50bcda.md`,
   naming the exact files and the operator-landing path.
2. Advisory model review on the candidate via the operator reviewer
   transport (`scripts/hngh review run-1 content-hash=... paths=...
   reviewer=~/.hngh-automation/reviewer-local.conf`; r13
   operator-reviewer precedent; endpoint `127.0.0.1:8888`, model
   `unsloth/Ornith-1.0-35B-GGUF`); receipt in the ceremony run ledger
   and the dispatching session report. Advisory by policy — the verdict
   gate below is deterministic.
3. Ten-principle verdict (the gate): `propose` with
   `evidence-requirements=<principle>:claim-proof:<content-hash>` for
   all ten matrix names; the certificate only issues on 10/10 passed.
4. Certificate: `issue-cert` + `mutation-check` for `prepare-candidate`
   and `commit` over the docs candidate (this record, the alert row,
   and its body); commit message `hngh: candidate <content-hash>`;
   certificate-gated push per the ceremony-drive instrument.
5. Gate: `make test` green — 2855 checks baseline immediately before
   the beat, re-run after the commit.

## Where the loop stops (the park)

The loop reaches the mutation stage only for the docs candidate above.
The `:wake-mutation` src mutation is parked at the operator boundary:
machine sessions do not touch kernel `src/`, `tests/`, `Makefile`, or
`hngh.asd` (2026-09-03 staging plan). Exact files and the
operator-landing path live in alert row `9a50bcda`:
`src/adapter/mutation.lisp:8-9` (vocabulary + fresh-evidence mapping in
the same file), `src/packages.lisp:247` (export), `src/main.lisp:1371`
and `:1490` (dispatch member checks), `tests/adapter/test-mutation.lisp`
(refuse/execute fixtures). The operator lands it through the same
dogfood ceremony with `make test` green.

## Remaining unknowns

- The fresh-evidence shape for a wake (pin-file `:file-sha256` today vs
  new evidence kinds for MAC/lease/last-seen) is operator-design work
  for the landing slice; the current evidence set is the git triple
  (`:repository-revision`, `:working-tree-status`, `:file-sha256`).
- The queue row stays `queued`: the rotation completes only when the
  operator lands the src change; this beat's certificate covers the
  proposal + park, not the lane itself.
