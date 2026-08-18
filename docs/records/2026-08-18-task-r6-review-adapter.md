# Task R6 model-review adapter record

## Scope

Implements roadmap promotion rung 6: the bounded model-review adapter. It
adds `hngh.adapters.review`, fixture-backed tests, and no daemon, service,
watcher, scheduler, provider call, network route, or default model transport.
The kernel domain and application packages remain free of adapter dependencies.

## Decision

`request-review` accepts a closed `review-request` — candidate paths (safe,
duplicate-free, bounded), a content hash, and policy-context labels — and a
`review-ports` transport carrying one injected `invoke-reviewer` callback. The
adapter builds one fixed JSON prompt from those fields (no caller-supplied
free text), hands it to the callback, and receives `(values exit-code stdout
stderr)` exactly like the evidence and mutation transports.

A zero exit parses stdout as a strict JSON envelope:

```json
{"findings":[{"label": string, "citation": string}, ...]}
```

Only that shape is accepted: exactly one top-level `findings` key; each
finding is an object with exactly `label` and `citation` string fields; both
are nonempty printable strings bounded to 200 characters; a maximum of 32
findings; numeric, boolean, null, duplicate-key, nested, or trailing-garbage
output refuses. Duplicate labels, unsafe findings labels/citations, and
oversized model output refuse with closed labels (`unsafe-finding`,
`duplicate-finding`, `too-many-findings`, `output-too-large`,
`malformed-output`). A failed review call (nonzero exit) yields a complete
bundle with a single `:review` evidence fact at state `:unverifiable` and
fingerprint `"unavailable"`. A thrown or malformed transport return yields a
`transport-fault` refusal.

On success the result is `:complete` with sanitized findings and one
deterministic `evidence-fact`: kind `:review`, state `:current`, fingerprint
`<content-hash>|<sorted-labels>`, so identical reviews of identical content
produce identical evidence and certificates can bind the labels. Findings are
immutable `review-finding` values (label + citation) whose labels feed
`candidate-certificate` review-findings; the adapter itself decides nothing,
issues nothing, and executes nothing.

The adapter has no default transport, performs no network or subprocess
access, and lives entirely behind the injected callback, keeping the kernel
pure and `make test` network-free.

## Evidence

- `src/adapter/review.lisp` supplies `review-request`, `review-finding`,
  `review-ports`, `review-result`, the strict JSON envelope reader, the fixed
  prompt builder, and `request-review`.
- `src/packages.lisp`, `hngh.asd`, and `tests/run.lisp` register the adapter.
- `tests/support/fakes.lisp` supplies the review transport fake recording every
  prompt; `tests/adapter/test-review.lisp` covers closed request construction,
  escaping paths, prompt hygiene, deterministic fingerprints, valid and empty
  findings, reviewer failure to `:unverifiable`, transport faults, malformed
  JSON, schema violations, duplicate and unsafe findings, and the finding-set
  and response-size bounds.
- `docs/project/roadmap.md`, `docs/core/component-map.md`, `docs/architecture.md`,
  `docs/core/clean-architecture-charter.md`, `docs/core/test-boundary.md`,
  `README.md`, and `CHANGELOG.md` record rung 6 as complete and explicit
  composition as next.
- `make test` reports 8 reader-guard checks, 1059 Common Lisp checks, and a
  successful ASDF `hngh` load. Tests invoke only fakes and never contact a
  provider, subprocess, or network.

## Remaining unknowns

Explicit composition, operator-visible presentation, and real model or
terminal transports remain future rungs. Real review transports must be
separately approved and stay disabled until a run loadout admits them; the
kernel does not supply one now.