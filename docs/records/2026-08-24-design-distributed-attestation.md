# 2026-08-24 — Design paper: distributed attestation & evidence federation

## Status

Design paper for roadmap "Next" item 1. Paper-first: no source, test, gate,
or runtime change lands with this record. This document is written in the
`docs/records/` format so review can land it (likely as
`docs/records/2026-08-24-design-distributed-attestation.md`) as-is or with
edits; it intentionally ships no code.

## Scope

Design groundwork for remote evidence ports and cross-machine certificate
verification: how a Hngh instance may (a) gather evidence claims from another
machine and (b) verify a certificate that was issued on another machine —
without a daemon, without network code in the kernel, without a default
peer, and without admitting a mutation on unattested authority.

Explicit non-goals for this slice:

- No daemon, server, listener, watcher, scheduler, or background pull. Every
  remote read is one bounded, synchronous, operator-invoked request through
  an injected transport, exactly like the existing evidence process
  transport.
- No network code in `hngh.domain`. The kernel gains pure values and
  structural checks only; TLS, sockets, curl, and key stores stay in
  adapters behind injected callbacks.
- No default peer, no default provider, no ambient trust. Without injected
  federation ports, remote operations refuse `no-federation-transport`.
- No remote mutation. A remote machine's certificates are **evidence that a
  certificate exists elsewhere**, never authority to mutate on this machine.
  The mutation executor stays single-machine; the operator's own kernel is
  the only place a mutation is admitted.
- No PKI hierarchy: no CA, no certificate chain trust, no key servers, no
  revocation service. The no-PKI divergence
  (`docs/records/2026-08-24-prior-art-landscape.md`, decision 4 in
  `docs/project/decisions.md` 2026-08-24) was a *single-machine* decision
  with an explicit revisit trigger: multi-machine evidence sharing. This
  design is that revisit, and it resolves it narrowly — see below.

## The trust model: two independent bindings

The recurring mistake in attestation registries is conflating "this is what
machine B claims happened" with "this claim is authorized." Hngh already
splits those; the federation design keeps the split and extends it:

1. **Hash binding (stays, unchanged).** Certificates and evidence are bound
   by content-addressed hashes. The fingerprint IS the value; there is no
   signature over the evidence needed for self-authenticity. A certificate's
   `content-hash`, `evidence-hashes`, and the source manifest entries are the
   machine-independent record.
2. **Attestation binding (new, minimal).** What a hash cannot do is say
   *"the machine whose identity is X issued this certificate, at time T"*.
   In a single machine no one can ask that question; across machines it is
   the entire question. Federation therefore adds one narrow mechanism: an
   **operator-pinned key list**. The issuer of a remote certificate signs an
   authorized and explicit envelope; the verifier accepts the envelope only
   if the signing public key is on the operator's pinned list. This is
   deliberately NOT public-key infrastructure: no CA, no chain, no scope
   delegation, no discovery, no rotation service. It is a closed list of
   named public keys the operator has explicitly admitted, and the kernel
   refuses everything absent from it. (Single-machine hash self-
   certification stays the substrate and the default; pinning is layered
   strictly over it for cross-machine attestation.)

**Why not hash-chain only?** A pure hash chain authenticates
*continuity and content*, not the author. Any machine with a copy of the
chain can replay it; chains prove that a certificate is internally coherent
and derivable from its inputs, not that a particular peer is bound to it.
For cross-machine evidence gathering a hash claim is already sufficient
(and the default), but *cross-machine certificate verification* is precisely
the case where "who" matters, so the minimal signature sits at that seam
and nowhere else.

**Why not PKI?** A CA hierarchy reintroduces exactly the external
authority the design removed, and inverts the fail-closed property at the
first trust-anchor compromise. The pinned list keeps fail-closed: anything
not explicitly pinned lands on the `unknown-peer-key` refusal, and there is
nothing between operator and machine. Key rotation and multi-operator trust
stay as open questions below; this record defines the enumeration, not the
revocation machinery.

## What stays pure kernel vs. adapter

| Concern | Home | Why |
|---|---|---|
| `remote-attestation` value (fields, immutability) | `hngh.domain` | data only; kernel already owns certificate values |
| Structure/expiry checks (shape, duplicate-free, closed vocab, UTC timestamps) | `hngh.domain` (new pure function) | deterministic, side-effect-free, no crypto primitives |
| Mapping remote claims → `evidence-fact`s | `hngh.adapters.federation` | needs the injected fetch transport and strict parser |
| Signature verification | `hngh.adapters.attestation` | crypto primitive behind an injected callback, never in kernel |
| Key pin resolution | `hngh.adapters.attestation` ports | operator-supplied closed list |
| Clock for expiry against `now` | injected callback (like existing `clock-now` / `mutation-evidence-now`) | domain still never reads the wall clock |
| Policy decision (admitted? refused?) | `hngh.domain` evaluator via the existing requirement ledger | "is this valid" never lives in an adapter |

The kernel gains exactly two new pure pieces: a `remote-attestation` value
and a structural checker (`verify-attestation-shape`, working on supplied
values only: closed fields, bounded sizes, valid UTC strings, duplicate-free
claims). Everything touching bytes from the wire, keys, or time lives in the
two adapters.

## Port shapes (mirroring existing adapter patterns)

The existing vocabulary is `make-<name>-ports` returning a struct of
read-only callbacks; a `transport-response` wrapper normalizes
`(values exit-code stdout stderr)` to `(values t ...)` or a closed fault;
refusals carry stable string labels; results are closed structs; and all
process/network access sits behind the injected callback. (See
`hngh.adapters.evidence`, `hngh.adapters.mutation`, `hngh.adapters.review`,
and `hngh.adapters.model`.) The federation design keeps that exact shape.

```lisp
;; hngh.adapters.federation — remote evidence gather (mirrors hngh.adapters.evidence)

(defparameter +federation-methods+
  '(:http-claim :ssh-claim :carrier-bundle))
       ;; closed method set; unknown method refuses

(defstruct (federation-ports
            (:constructor %make-federation-ports (fetch-remote))
            (:conc-name %federation-ports-))
  (fetch-remote nil :read-only t))
;; fetch-remote: (lambda (request) => (values exit-code stdout stderr))
;; the ONLY network touchpoint; nil-injected means no-federation-transport

(defstruct (federation-request
            (:constructor %make-federation-request
                (peer method time-window max-facts))
            (:conc-name %federation-request-))
  (peer nil :read-only t)          ;; validated plain identifier string (no URL)
  (method nil :read-only t)        ;; member of +federation-methods+
  (time-window nil :read-only t)   ;; UTC [start,end] bound for fetched claims
  (max-facts nil :read-only t))    ;; bound on the returned claim set

;; result mirrors hngh.adapters.evidence:evidence-result
(defstruct (federation-result
            (:constructor %make-federation-result
                (status evidence manifest refusal-labels))
            (:conc-name %federation-result-))
  (status nil :read-only t)        ;; :complete | :refused
  (evidence nil :read-only t)      ;; list of domain evidence-facts
  (manifest nil :read-only t)      ;; domain source-manifest-entry; NIL allowed
  (refusal-labels nil :read-only t))
```

`gather-federated-evidence` is the entry point, mirroring
`hngh.adapters.evidence:gather-evidence`: one closed request through the
injected `fetch-remote`, strict document parsing into domain facts with
closed states (`:current` when locally re-hashable, `:unverifiable` when
not, `:malformed` / `:missing` / `:conflicting` under the existing
evidence-state vocabulary). Remote facts never bypass the evidence route:
they feed the proposal ledger as facts, and the deterministic evaluator
decides.

```lisp
;; hngh.adapters.attestation — cross-machine certificate verification

(defstruct (attestation-ports
            (:constructor %make-attestation-ports
                (verify-signature resolve-pinned-key))
            (:conc-name %attestation-ports-))
  (verify-signature nil :read-only t)   ; (lambda (payload signature key-id)
                                        ;   => (values exit-code stdout stderr))
  (resolve-pinned-key nil :read-only t)) ; (lambda (key-id) => key-or-nil)

(defstruct (attestation-result
            (:constructor %make-attestation-result
                (status verified key-id refusal-labels))
            (:conc-name %attestation-result-))
  (status nil :read-only t)        ;; :verified | :refused | :fault
  (verified nil :read-only t)      ;; payload+sig verified against a pinned key
  (key-id nil :read-only t)        ;; which pinned key, when verified
  (refusal-labels nil :read-only t))
```

`verify-remote-certificate` takes a `remote-attestation` envelope (domain
value), a `now` timestamp string, and `attestation-ports`; it:

1. runs the kernel's `verify-attestation-shape` (pure: expiry strings,
   duplicate-free, closed vocabulary, bounded sizes) — any failure is a
   typed refusal labeled `malformed-attestation`;
2. resolves the key via `resolve-pinned-key` — an unknown key is a
   `:refused` result labeled `unknown-peer-key`, fail-closed (also covers
   the empty-pin-in-list case);
3. calls `verify-signature` on the frozen payload bytes — a nonzero,
   timed-out, or malformed return is `signature-fault`, and only a verified
   signature yields the `:verified` status;
4. checks the envelope's `not-before` / `not-after` against the injected
   `now` with a bounded skew window supplied in the envelope;
   out-of-window is `expired-attestation` (or `attestation-clock-skew`).

The attestation **adapter result is evidence, not authority**: a `:verified`
attestation binds a `:remote-attestation` domain fact (state `:current`
only when signature, pin, shape, and expiry all hold; otherwise `:refused`
or the fact is marked `:unverifiable`) — it never admits a mutation. The
result feeds the same proposal-evaluator ledger as every other fact, and a
proposal that relies on remote evidence still refuses unless the operator's
policy explicitly requires the corresponding requirement kind.

## Transport admission (mirrors r8/r10)

- The closed set `+admitted-transports+` grows one kind, `:federation`,
  admitted only through the existing `admit-transport` use case, with a
  loadout gate like `:model`: a non-`local` route label **and** the
  `remote-evidence` network label. Without that admission, the `fetch` and
  `verify` operations refuse `loadout-refuses-transport`.
- `hngh.main:dispatch-command` threads `&key federation-ports
  attestation-ports` with no defaults: un-injected, the operations return
  `no-federation-transport` / `no-attestation-transport` (refusal), and
  plain `scripts/hngh` never touches a wire.

## Cross-machine certificate verification: signature, keys, expiry

- **Signature.** Envelope signing is per-machine, one long-lived key; the
  signing key id and the exact payload bytes are what get signed. A hash of
  the payload is not a signature: a recipient never derives attestation from
  a hash alone, the hash says *which* bytes, not *who* signed.
- **Key distribution.** Operator-pinned list — a flat list of
  `(key-id public-key)` pairs supplied at composition. Absent or empty
  list: `unknown-peer-key` refusal. No first-seen/warm-trust fallback and no
  auto-discovery; the pin list is a trust root owned by the operator, and it
  only grows or rotates by explicit operator action. No provider key is ever
  a trust anchor.
- **Expiry.** Every certificate already carries an ISO-8601 expiry string
  and the mutation executor rechecks it at moment of action. The remote
  attestation envelope adds issuer-supplied `not-before` / `not-after`; the
  pure shape checker validates the UTC strings, the adapter compares them
  against the injected `now` with a fixed, small skew window, and the
  evaluator separately declines stale facts (`:stale`), so a remote machine
  can never extend an expired local certificate.

## Failure taxonomy (fail-closed cases)

New refusal labels, mapped onto the existing closed vocabulary
(`docs/records/2026-08-17-task-c2-failure-disposition.md`):

| Case | Closing label/status | Existing category |
|---|---|---|
| Transport not injected | `no-federation-transport` / `no-attestation-transport` | `:refuse` |
| Unknown / empty peer | `unknown-peer` | `:refuse` |
| Unadmitted transport kind | `unknown-transport` (reuse) | `:refuse` |
| Loadout gate fails | `loadout-refuses-transport` (reuse) | `:refuse` |
| Fetch/verify callback throws or returns a malformed value | `transport-fault` (reuse) | `:port-callback-fault-or-malformed-return` |
| Malformed envelope / unknown fields / duplicates / oversized | `malformed-attestation` / `output-too-large` | `:port-...` |
| Key not on the pinned list | `unknown-peer-key` | `:refuse` |
| Bad / timed-out / unverifiable signature | `bad-signature` / `signature-fault` | `:tool-or-environment-fault` |
| Missing or malformed expiry; expired; outside skew | `malformed-expiry` / `expired-attestation` / `attestation-clock-skew` | `:refuse` (stale evidence) |
| Remote claim not locally re-hashable | `:unverifiable` fact (never an authority) | `:insufficient-or-stale-evidence` |

Rule: any failure, unknown, or absent remote fact keeps the verdict
`:refused`; monotonicity (ignoring evidence must never flip DENY → ALLOW,
taken from the prior-art lane) is preserved structurally. A remote fact is
`:current` only when it was fetched through the transport, parsed by the
strict parser, and either locally re-hashed or signed by a pinned key and
within the expiry window — nothing weaker ever passes a policy requirement.

---

# Remaining unknowns / open questions for the operator

1. **Key rotation.** No revocation machinery: what happens when a pinned key
   is replaced — immediate refusal of all old attestations, or a one-window
   grace? Track this in a decisions record before implementation.
2. **Remote re-verification vs remote evidence.** Does the operator want a
   fresh remote run on the other machine (reproduced source) or only claims
   already produced? Both fit the same ports; which is admitted first is a
   policy choice.
3. **Multi-hop chains** (A → B → C). This paper covers the two-party case
   only; chaining attestations through intermediate machines is deliberately
   out of scope.
4. **Envelope format.** The frictionless option is JSON parsed by the
   adapter's own strict reader (like the review adapter); an alternative
   (e.g. a line protocol) is fixed later, and the adapter owns it — never
   the kernel.
5. **Requirement-kind admission.** Should remote evidence requirement kinds
   join the ledger vocabulary (`+evidence-requirement-kinds+`, suggestion:
   yes), or stay in a new closed vocabulary only for remote requirements?
6. **Pull direction.** This design has no server, so no push. Whether "B
   pulls from A" (network methods) and "A ships a bundle in as
   `:carrier-bundle`" (manual method) are both admitted from day one, and
   whether the carrier bundle is the only variant that ever leaves a
   machine.

This record names scope, design decisions, port shapes, and remaining
unknowns; it does not authorize code. Landing it in `docs/records/` is the
review step for the roadmap "Next" item before any implementation slice.