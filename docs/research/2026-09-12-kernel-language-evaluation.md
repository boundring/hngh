# 2026-09-12 — kernel language evaluation (study, not a refactor)

Origin
------
Operator directive: "we've been using sbcl mostly out of aesthetic preference,
so far, and we're open to Hngh considering refactor to other languages on base
principle, for it to evaluate and consider what language makes the most sense
for its kernel as time goes on."

This document evaluates; it proposes no refactor and touches no kernel code.

Question
--------
Which implementation language best serves the hngh kernel (8,275 lines of
Common Lisp under `src/`, 2,889-check test gate) and its OS-harness future
(Rung D system mutations, transaction certificates, reconciliation runs,
federation attestation): SBCL Common Lisp, Rust, Zig, Go, or C?

Evidence read
-------------
- `docs/core/clean-architecture-charter.md` — dependency law, forbidden
  dependencies, promotion ladder, composition rule.
- `docs/architecture.md` — kernel shape, planned outer boundaries, integration
  surfaces (systemd timers, MCP server, omp bridge, dashboard).
- `src/packages.lisp` — the full exported surface: pure domain values
  (mission, run lifecycle, policy verdicts, candidate certificates,
  attestation claims and key pins, course selection, evidence profiles),
  application use cases over port records (`create-run`, `admit-transport`,
  `arm-run`, `start-run`, `checkpoint`, `close-run`, `select-course`), eight
  adapter packages behind injected transports, renderer-only presentation,
  one composition root (`hngh.main`).
- `src/domain/attestation.lisp:41-44` — crypto (rsa-sha256, ed25519) is
  already a closed vocabulary executed through an external process transport
  (openssl), not in-kernel crypto code.
- Gate history: `docs/project/reports.md` — "gate: hngh make test green
  (2889 checks passed)", 2026-09-12.

The design principle that makes this answer stable
---------------------------------------------------
**The PORT architecture means the kernel's VALUES and USE CASES are portable;
the language choice optimizes for the mechanism layer it must talk to.**

The kernel's economic core — validating profiles, advancing a closed
lifecycle, issuing and binding candidate certificates, evaluating policy
proposals under evidence profiles — is mechanism-agnostic. It names no
filesystem, process, clock, crypto, or network; every such contact is an
injected transport (`evidence-ports`, `mutation-ports`, `review-ports`,
attestation and federation ports, worker ports). A language rewrite that
re-expresses the same values and use cases buys no new capability by itself:
it only re-derives the same closed vocabularies in new syntax.

What a language actually decides is the *mechanism layer*: how safely and how
cheaply the kernel can (a) keep the certificate/ledger model honest (hashing,
signatures, canonical serialization), (b) do the Rung D OS-harness work
(syscalls, process supervision, systemd unit state, reconciliation of real
machine state), and (c) stay deployable and operable on the operator's
machines. Therefore the evaluation weights mechanism-layer fit and total
migration cost, not syntax preference.

Criteria matrix
---------------
Scores: 5 = strong fit, 1 = poor. Grounded in the kernel's actual surface and
the OS-harness roadmap; not general language-benchmark folklore.

| Criterion (what it means for hngh)                                    | SBCL  | Rust  | Zig   | Go    | C     |
|-----------------------------------------------------------------------|-------|-------|-------|-------|-------|
| 1. Safety/guarantees for the certificate model (closed types, no UB,   | 4     | 5     | 3     | 4     | 1     |
|    memory safety in code that gates machine mutations)                 |       |       |       |       |       |
| 2. Testability at the 2,889-check scale (REPL-driven TDD, cheap pure   | 5     | 3     | 2     | 4     | 2     |
|    value fixtures, fast gate)                                          |       |       |       |       |       |
| 3. OS-harness fit: syscalls, process control, systemd/D-Bus, static    | 2     | 5     | 5     | 5     | 5     |
|    binaries for Rung D system mutations and reconciliation             |       |       |       |       |       |
| 4. Portability (run everywhere the operator's fleet runs; boring       | 3     | 4     | 3     | 5     | 5     |
|    cross-compilation story)                                            |       |       |       |       |       |
| 5. Ecosystem for the ledger+certificate model (ed25519/rsa signing,    | 3     | 5     | 2     | 4     | 3     |
|    hashing, JSON parsing, attestation envelopes maintained by others)  |       |       |       |       |       |
| 6. Operator familiarity + existing automation surface (bash jobs,      | 5     | 3     | 1     | 4     | 3     |
|    python MCP server, REPL debugging already the working loop)         |       |       |       |       |       |
| 7. Migration cost from SBCL (rewrite risk against a green 2,889-check  | 5     | 2     | 1     | 2     | 1     |
|    gate; certificate history continuity; regression surface)           |       |       |       |       |       |
| **Total**                                                              | **27**| **27**| **17**| **28**| **20**|

Reading the matrix honestly
---------------------------
- The totals are close (Go 28, SBCL 27, Rust 27) precisely because the criteria
  pull in opposite directions: SBCL wins everything inward of the ports; the
  compiled languages win the mechanism layer. That tension is the finding, not
  a scoring failure.
- Go's nominal total hides a model mismatch: hngh's domain is a web of closed
  discriminated values (policy-verdict, candidate-certificate, attestation
  claims) and refusal-or-result contracts. Go has no sum types; every closed
  vocabulary becomes interface{} + type switches, which is exactly the class
  of bug the certificate governance exists to refuse. Its systemd ecosystem
  (go-systemd, sdjournal) is the best of the four, and it compiles to one
  static binary — real Rung D advantages.
- C is disqualified on criterion 1 alone: code that binds machine mutations to
  certificates must not be memory-unsafe, full stop. Zig fixes C's safety
  partially but its ecosystem (criterion 5) and stability-under-churn make it
  a poor steward for a governance ledger that must stay readable for years.
- Rust and SBCL tie on total for opposite reasons. Rust's enums + exhaustive
  match are a near-perfect encoding of hngh's closed values, and its crypto
  and syscall ecosystems are the strongest; its costs are compile-time
  ceremony around the port records and a much heavier rewrite.
- The kernel already gets the best of both worlds where it matters: crypto and
  hashing are process transports (openssl, sha256sum) behind ports. The
  mechanism layer is already swappable without touching the values.

Recommendation
--------------
**Stay on SBCL for the kernel's values and use cases; adopt Rust (not Go, not
Zig, not C) as the designated language for NEW mechanism-layer adapters when
Rung D arrives — behind the existing port seams, as process transports or
separate binaries, never as a kernel rewrite.**

One-liner: the ports already bought us the freedom the operator is asking
about; spend it at the adapter layer (Rust for syscall/crypto-heavy Rung D
transports) rather than paying a full-kernel rewrite that would risk the
2,889-check green gate to re-derive identical closed vocabularies.

Honest tradeoffs of this position
---------------------------------
- We forgo Rust's exhaustiveness checking inside the kernel itself; the
  discipline stays conventional (fixtures + the dependency fixture guard +
  the check suite) rather than compiler-enforced. That is a real, permanent
  tax paid for REPL-driven development speed and zero migration risk.
- SBCL's deployment story (image-based, per-implementation quirks) stays a
  known cost; if hngh ever needs to ship as a single static binary to peers
  for federation, the *peer daemon* is a better Rust target than the kernel
  is an SBCL one — same port-seam answer, one layer out.
- The evaluation should be re-run, not assumed: the trigger conditions to
  revisit are (a) a Rung D system mutation that needs in-process syscall
  authority the process-transport shape cannot express, (b) federation
  peers that require a statically-linked attestation verifier, (c) an
  operator-visible maintenance wall in SBCL (implementation lock-in biting
  a real feature). Absent those, revisit nothing.

Disposition
-----------
Study only. No kernel change, no plan, no refactor. Filed for the operator's
"as time goes on" clause: the framework above is the standing criterion set;
any future language proposal must argue against this matrix, not against
aesthetics.
