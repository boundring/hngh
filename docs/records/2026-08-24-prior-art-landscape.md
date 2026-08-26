# Task: prior-art landscape and strategy record

## Scope

Documentation-only record of a 2026-08-24 research session: a four-lane
parallel sprint over attestation frameworks, agent-harness landscape,
agent-security models, and CA/authorization theory. Web-search providers
bot-blocked mid-sprint; direct primary-source fetches (arXiv abstracts,
spec repos) were used instead. No source, test, gate, or runtime change.

## Closest prior art

- **Progent (arXiv:2504.11703) is the closest prior art.** Deterministic
  privilege control for LLM agents: SMT-checked policies over tool calls;
  the LLM proposes policy updates and the solver decides. Its monotonic
  confinement (privilege-narrowing updates auto-apply, expansions require
  human approval) is the nearest existing analogue to Hngh's matrix. It
  lacks Hngh's hash-binding of an action to repository identity plus base
  revision, ordered candidate manifest, content hash, evidence hashes, and
  the recheck of all facts at moment-of-action.
- **CaMeL (arXiv:2503.18813)** proves isolation from prompt injection via
  control/data-plane separation (capabilities plus policies over data
  flows). Complementary, not rival: CaMeL proves isolation; Hngh proves
  authorization binding. Hngh does not claim CaMeL-style provability.
- **AgentSpec (arXiv:2503.18666)** is a runtime enforcement DSL
  (trigger → predicate → enforcement) that monitors agent runs. It does
  not authorize effects.

## Deliberate divergences from in-toto / SLSA / DSSE

Hngh certificates are structurally the same document grammar as in-toto
(policy proposal ≙ layout; current facts ≙ link metadata). Four deliberate
divergences:

1. **No PKI; hash self-certification instead.** Content-addressed hashes
   bind the certificate; there is no external key hierarchy.
2. **Duplicate facts refuse.** Fail-closed on any repeated evidence fact.
3. **Moment-of-action freshness recheck is novel.** No attestation
   ecosystem models re-validating evidence at execution time; Hngh
   rechecks every certificate fact against fresh evidence immediately
   before the named action.
4. **No multi-party machinery.** The certificate is single-machine.

## Adopted invariants from this lane

- Monotonicity: ignoring evidence must never flip DENY → ALLOW. Taken from
  in-toto's monotonic principle; held as an invariant and a property test.
- Deny with a structured reason, and totality over closed kinds (OPA/Cedar
  idioms).
- DSSE envelope as the future export grammar, YAGNI-gated until interop is
  needed.

## Agent-harness landscape positioning

- **Claude Code** (hooks + OTel + auto-classifier permissions) is
  logging-plus-classifier, not tamper-evident governance.
- **Codex CLI** (sandbox × approval) has the best boundary enforcement
  among harnesses but no hash binding.
- **mini-swe-agent** (~100 lines, bash-only, >74% SWE-bench Verified) is
  the anti-governance refutation: the sharpest skeptic attack on Hngh's
  machinery.
- **Aider** is the git-is-enough-audit thesis.
- **OpenHands / ACP** are the architecturally nearest integration surfaces;
  neither issues certificates.

Hngh's position is bounded-trust-lane: for changes with external
answerability (deploys, security-sensitive changes, multi-party review),
not a daily driver.

## The governance-benchmark gap

No public benchmark measures governance properties (tamper-evidence,
approved ≡ executed, reconstruction-from-record). Building one would be a
first. Existing agent-safety evals to study for the lane:
AgentDojo (github.com/ethz-spylab/agentdojo), InjecAgent, and R-Judge.

## Theory anchors

- Parnas (1972/1978) plus OS policy-vs-mechanism separation is Clean
  Architecture's true ancestry.
- Capability security / POLA lineage: E, Waterken, Monte, Capsicum, seL4.
  Hngh's expiry plus hash-binding plus recheck deviates from classic
  unrevoked ocaps, justified because Hngh authorizes effects against
  mutable world state, not in-memory object references.
- Mixed-initiative HITL (Horvitz): Hngh's operator-perception-is-not-a
  routine-approval-mechanism principle is policy-delegation HITL and should
  be argued as such.

## Strategy sequencing

1. Now: the operator-facing command surface (roadmap Next) plus real
   transport admission.
2. Next: a dogfood loop (future rung candidate): Hngh proposes → evaluates
   → commits changes to itself via its own harness, exercising
   evidence/review/certification/mutation against its own repository.
3. Then: the remote-evidence port shape on paper (transport-injected,
   fail-closed; monotonicity must survive non-local facts).
4. Much later: a second instance; federation enters as a scope-broadening
   proposal class.

Federation breaks the single-machine no-PKI stance (Sybil resistance,
stale-replica conflicts, who-attests-the-attestor). No-PKI thus stands as a
single-machine decision with an explicit revisit trigger: multi-machine
evidence sharing. Hash content-addressing stays the right substrate (git
provides ~90%). That revisit trigger is recorded in
`docs/project/decisions.md`.

## Evidence

- Primary-source fetches this session: arXiv abstracts for Progent,
  CaMeL, and AgentSpec; the in-toto / SLSA / DSSE specs; the harness
  projects and evals listed above.
- `make test` reports no change; this record is documentation only.

## Remaining unknowns

- No public governance benchmark exists; architecting one is an open
  research lane, not current work.
- Full-source bootstrap / reproducible builds and evaluator-cannot-verify-
  its-own-verifier remain research targets for the self-refactoring rung.