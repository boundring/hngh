# Triple kernel — judgment, legislation, execution

Status: draft (2026-10-03, harness-skeleton program Phase D1; operator decision: design + ceremony plan drafts only, no kernel code in this program).

## 1. What exists today

Three kernels are already present in the system's shape; what is missing is their **boundary discipline**.

| Kernel | Intent | Current state |
|---|---|---|
| **Judgment** | Gather evidence, evaluate runs, produce verdicts | `src/adapter/evidence*`, `src/adapter/run-gather*`, `src/adapter/review*`, `src/domain/governance` — alive, but verdicts are **ephemeral**: they exist inside a ceremony run and are not persisted as first-class rows. |
| **Legislation** | Define what is allowed to change and under which proof | `src/domain/attestation` + `src/application/admit-transport` hold certificates-as-admission; plan lifecycle (front-matter status, /HOLD/, principle lines) lives as convention in `docs/project/plans/` + `scripts/omp-bridge`. Not an entry point — a practice. |
| **Execution** | The thing that actually mutates the world | Smeared across `automation/`: cadence tiers, dashboard server (mutations via POST + token), composer, feed rebuilds, installers. It reads kernel state, writes userspace state, and — through the dashboard's POST surface — mutates shared state with only a token as proof. |

The ten principles (closed-authority, least-authority, dependency-direction, fail-closed, evidence-before-claim, atomic-mutation, reversibility, no-hidden-execution, cost-and-route-discipline, source-grounding) are enforced **within** each kernel but the **between-kernel currency is ad hoc**: shell exit codes, JSON files, and human-read plans.

## 2. Design: one currency, three sovereigns

**The certificate is the only cross-kernel currency.** Evidence rows stay in judgment; effect rows stay in execution; the only thing that crosses a kernel boundary is a signed, content-addressed certificate stating: *actor, action, target state, verification, expiry*.

Data contracts:

- **verdict-row** (judgment → legislation): `{run-id, component, verdict, evidence-refs, computed-at, ten-principle-exceptions}`. Persisted (currently ephemeral — stage S1).
- **certificate** (legislation → execution): already exists (`src/domain/attestation`); gains a `grants` clause naming exactly the mutations allowed (no more "certificate covers the session").
- **effect-row** (execution → judgment): `{certificate-ref, effect, files-touched, gate-result, ts}` — what actually happened, fed back as evidence.

Dependency direction stays inward: judgment and execution never call each other; both speak to legislation.

## 3. Migration stages (each its own ceremony plan draft — Phase D2)

- **S1 — Verdict persistence.** Judgment writes verdict-rows to durable storage (run close, not ceremony-time only). No behavior change elsewhere.
- **S2 — Legislation entry point.** Formalize `admit(instrument, state)` as THE path by which anything (transport, plan execution, automation mutation) becomes legitimate. Subsumes today's `scripts/verify-candidate.py` + plan front-matter checks + dashboard token gate into one entry point. Owns plan archival policy (~200 plan files — executed plans move to an archive tier with their certificates attached).
- **S3 — Execution sovereignty.** Automation's self-authored mutations stop being "script with a token" and become "execution kernel holding a certificate minted by legislation". Concretely: automation's stance = read-only consumer of kernel state; the dashboard's POST mutations request certificates through the S2 entry point; self-review enforces the contract. This is where the control-room refactor's verbs (handle/dismiss/park) become certificate-minting operations instead of raw POSTs.

## 4. Non-goals (this program)

- No kernel `src/` code — S1–S3 are design + ceremony-ready plan drafts (D2) only.
- No new IPC layer, no daemons; certificates remain files, verdict-rows remain rows.
- Federation admission (node certificates) reuses the same legislation entry point — see docs/design/federation-two-pc.md.
