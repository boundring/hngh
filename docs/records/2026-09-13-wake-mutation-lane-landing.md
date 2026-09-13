# 2026-09-13 — wake-mutation-lane: the :wake-mutation src mutation
# lands through the ceremony; the operator-stall class is retired

## Operator authorization (2026-09-13)

The operator asked: "Why is there yet another operator-gated boundary?
It's been 10 days since that staging boundary. Help us make sure Hngh
doesn't get stopped by this kind of needless operator gate again. We're
authorizing it."

Intent: the operator authorizes landing the :wake-mutation kernel src
mutation and authorizes removing this class of needless operator stall.
The authorization is recorded here and implemented as the doctrine 2a
amendment (docs/records/2026-09-09-operator-flexibility-doctrine.md)
and the AGENTS.md boundary-paragraph amendment. It unblocks this
mutation and the class of certificate-path slices; it is not a bypass
of the ceremony.

## What landed

- `src/adapter/mutation.lisp` — `+mutation-actions+` admits
  `:wake-mutation`; `command-for` gains its fixed argv template:
  `("hngh" "wake-peer" <base-revision> <candidate-paths...>)`. The
  certificate's base-revision names the run; candidate-paths carry the
  pins file and the pinned peer. The kernel's own `wake-peer` CLI
  rechecks the `:federation` admission, strict pins parsing, and the
  wake transport behind its own guarded surface, so the mutation
  adapter stays one fixed command behind an injected transport.
- `src/domain/governance.lisp` — the closed certificate-action set
  (`validate-certificate-action`) admits `:wake-mutation`; without this
  the CLI could name the action but no certificate could bind it.
- `src/main.lisp` — the `issue-cert` / `mutation-check` dispatch checks
  read the closed list and admit the new action with no change.
- `tests/adapter/test-mutation.lisp` — the vocabulary check expects
  `:wake-mutation`; a wake fixture proves the certificate-bound argv
  executes exactly once behind the fake transport (written red first:
  the suite failed on "mutation action set is fixed and enumerable"
  before the src change).
- `tests/domain/test-governance.lisp` — every closed action mints a
  certificate, now including `:wake-mutation`.

Gate: full `make test` green, 2894 checks (baseline 2889 immediately
before the slice); README check-count line updated for the doc-numbers
guard.

## Ceremony

The slice lands only through `scripts/omp-bridge --ceremony`
(flock/timeout wrapper over scripts/ceremony-drive): create-run ->
admit-transport -> propose (deterministic ten-principle verdict) ->
issue-cert + mutation-check prepare-candidate -> issue-cert +
mutation-check commit -> certificate-gated push. The commit message is
the certificate's content hash ("hngh: candidate <hash>"). Ceremony
outputs and the commit hash are in the session report; the git log is
the durable anchor.

## Policy change (this class of stall is retired)

- Doctrine 2a (2026-09-13): a kernel src mutation with a certificate
  path needs no separate operator stall — once authorization exists and
  the ceremony pass is green, the machine lands it. A parked queue item
  with an open certificate path is a routing defect, not a governance
  outcome. Park only actions with no certificate path (credentials,
  payments, provider-key activation beyond a recorded grant, public
  surfaces, deletions, security posture).
- AGENTS.md boundary paragraph generalized from `:wake-mutation` work
  to certificate-bound kernel mutations, with the proceed-on-certificate
  rule.
- Queue routing fix at the source: the wake-mutation-lane row flips to
  done, the `## Next` pointer advances to node-lattice-admission, and
  the research-dispositions row fail-20260909-wake-mutation-lane-src-mutation
  moves from parked to landed — the alert identity
  wake-mutation-lane:src-mutation stops re-occurring because its
  condition no longer exists.

Disclosure: the ceremony commit carries README.md including a
pre-existing auto-generated dispatch-table hunk (machine-generated doc
state, already dirty before this slice). CHANGELOG.md is written but
excluded from this commit by owner decision; the coordinator sweeps it
into a ledger-sync commit.
