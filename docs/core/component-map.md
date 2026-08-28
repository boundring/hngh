# Component map

Every component is a guest with a named seat; nothing sits down
uninvited.

The map names the public boundaries Hngh may add. A component is admitted only
when it has its stated reason to change, public API, allowed dependencies, and
deployment form.

| Component | Reason to change | Public API | Allowed dependencies | Deployment form | Owner / reviewer role |
|---|---|---|---|---|---|
| `hngh.domain` | Run policy and immutable values change | Domain values and pure policy functions | Common Lisp | Library | Domain builder / boundary reviewer |
| `hngh.application` | A named use case or port changes | Use-case input and output records; ports | `hngh.domain` | Library | Use-case builder / boundary reviewer |
| `hngh.adapters.evidence` | The fixed read-only evidence command set or its closed output mapping changes | `gather-evidence` over a fixed command set: `:repository-revision`, `:working-tree-status`, `:file-sha256` | Domain evidence values and an injected process transport | Library, manually composed | Adapter builder / boundary reviewer |
| `hngh.adapters.mutation` | Certificate-bound repository mutation commands or refusal mapping change | `execute-mutation` over one current candidate certificate and fresh evidence | Domain certificate/evidence values and injected evidence/process transports | Library, manually composed | Adapter builder / boundary reviewer |
| `hngh.adapters.review` | The review request contract or the closed structured-output mapping changes | `request-review` over a closed review request (candidate paths, content hash, policy-context labels) returning sanitized findings and one review evidence fact | Domain evidence values and an injected reviewer transport | Library, manually composed | Adapter builder / boundary reviewer |
| `hngh.adapters.filesystem` | Restricted local record transport changes | Application port implementations | Application ports and Common Lisp I/O | Library, manually composed | Adapter builder / fixture reviewer |
| `hngh.adapters.git` | Repository fact collection changes | Repository-inspection port implementation | Application ports and Git transport detail | Library, manually composed | Adapter builder / fixture reviewer |
| `hngh.adapters.model.*` | A model transport changes | `make-model-transports` completion factory returning the transport callback shape consumed by `hngh.adapters.review` | Application ports and transport detail | Library, manually composed (active behind loadout admission) | Adapter builder / cost reviewer |
| `hngh.adapters.terminal` | Bounded operator statement input changes | `capture-operator-statement` over `make-operator-ports`, returning `operator-result` values and `:terminal` evidence facts | Domain evidence values and an injected read callback | Library, manually composed (active behind loadout admission) | Adapter builder / safety reviewer |
| `hngh.presentation` | Operator-facing rendering changes | Render functions over application output | Application output and renderer resources | Manual CLI or report library | Presentation builder / factual-status reviewer |
| `hngh.main` | Composition and explicit entry behavior change | One operator command entry | All outer components | Executable entrypoint | Integrator / release reviewer |
| `hngh.test-support` | Fakes and deterministic fixtures change | Fixture constructors and fake ports | Public inward APIs | Test-only library | Test builder / independent reviewer |

## Existing API

`hngh.domain` is active. Its public API validates profile, mission, role,
loadout, run, governance, and evidence values, plus the closed run transition
policy and `+admitted-transports+`. `hngh.application` is active with
`create-run`, `admit-transport`, `arm-run`, `start-run`, `checkpoint`, and
`close-run`, capability-specific ports, and closed application and evidence
results. `hngh.adapters.evidence` is active with the fixed read-only evidence
command set and `gather-evidence` through an injected process transport.
`hngh.adapters.mutation` is active with `execute-mutation`: it rechecks every
certificate fact and emits only the certificate-bound fixed Git command through
an injected process transport. `hngh.adapters.review` is active with
`request-review`: it sends one closed review request through an injected
reviewer transport and maps the structured output into sanitized findings and
one deterministic review evidence fact; reviewers advise but never decide.
`hngh.adapters.filesystem` is active: it records canonical run-and-receipt
lines under an explicit root path and reports store refusals and transport
faults without importing domain types.
`hngh.adapters.model` is active as a manually composed library: the
`make-model-transports` completion factory returns the transport callback
shape every consumer uses so it can wrap as `make-review-ports` and drive
`hngh.main:request-run-review`; it is admitted behind a run loadout with a
non-`local` route and the `model-review` network label, and no default
provider transport exists.
`hngh.adapters.terminal` is a manually composed library: `make-operator-ports`
captures one bounded operator statement through an injected `read-statement`
callback and binds it only as a `:terminal` evidence fact with an in-process
SHA-256 fingerprint; it is admitted behind a run loadout carrying the
`terminal-input` tool label, and no default input source exists.
`hngh.adapters.federation` is active: `gather-federated-evidence` collects
carrier-bundle claims into evidence facts (`fetch-evidence`), attestation
envelopes are verified through `resolve-pinned-key` and `verify-signature`
ports (`verify-attestation`), the operator pinned-key registry is parsed
strictly and rendered (`list-pins`), and `:federation` is admitted behind
the `remote-evidence`/`carrier-bundle` labels with no default transport.
`hngh:validate-profile` is a compatibility facade over the domain validator.
`hngh.presentation` is active with pure render functions over admission
results, run and governance values, and installed adapter results; it
renders plain factual strings, keeps refusals literal, applies the optional
reference lexicon only as display copy at a named surface, and imports no
adapter. `hngh.main` is active as the composition root and CLI entry point:
`make-run-harness` composes the use cases over injected or default port
adapters, coordinator functions wire installed adapters through injected
transports, `dispatch-command` processes the closed CLI operation set
(19 commands across the run lifecycle, evidence, review, governance,
federation, and attestation — enumerated in the root README), and
`scripts/hngh` provides an executable SBCL wrapper. No default model or
terminal transport exists in active source: both routes are composed
manually and only serve runs holding the matching admission receipt.
## Dependency and deployment rules

- Component dependencies follow
  [the charter](clean-architecture-charter.md#dependency-law).
- A package export is public only when a test uses it through its named
  component boundary.
- An adapter remains a library until a use case, fake-backed fixture, and
  operator-visible composition rule justify it.
- Deployment form is not a right to run. In particular, a model or terminal
  transport is only composed manually behind a run loadout that carries the
  required route and labels; no default provider or input exists by import
  or in plain `scripts/hngh` invocations.
