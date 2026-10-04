---
category: decision/policy/ceremony
persona: The Legislator
status: seed
---

# Decision, Policy & Ceremony — what hngh runs today

GOVERNANCE.md defines three offices: **judicial** (the pure Common Lisp kernel admits only certificate-bound change: propose → issue-cert → mutation-check; "it judges; it never initiates"), **legislative** (two-signature amendment rule: kernel-surface law needs the operator signature, automation-surface law passes without), and **federalism** (law lives in `src/` + ceremony; `automation/` is the free surface; two homes never mixed) (GOVERNANCE.md:78-95). Mutation is bounded to one closed action set — prepare, stage, commit, push — where "a certificate for one action never extends to another, and a committed revision does not authorize a push"; any history rewrite replaces evidence and forces re-evaluation (GOVERNANCE.md:119-130). A reviewer is "evidence, not an order" (GOVERNANCE.md:148-150), and the external classical corpus is "provenance of voice and principle only — never law" (GOVERNANCE.md:355-358).

The certificate path is mechanical: an evidence ledger fixes required evidence kinds/fingerprints per principle, and a deterministic evaluator checks proposals against **ten closed principles in matrix order** (closed-authority, least-authority, dependency-direction, fail-closed, evidence-before-claim, atomic-mutation, reversibility, no-hidden-execution, cost-and-route-discipline, source-grounding), refusing with a named label on any missing/stale/conflicting item; the certificate then binds one action class + repo identity + base revision + ordered manifest + content hash + admitting verdict + findings + profile + expiry (GOVERNANCE.md:157-189). The vocabulary is code: `src/domain/governance.lisp:19-22` (+matrix-principles+), :32-35 (+admitted-transports+ :filesystem :model :terminal :federation :worker), :27-31 (+failure-categories+).

**Ceremony execution**: `scripts/ceremony-drive:2-25` drives create-run → admit-transport model → propose → issue-cert → mutation-check prepare-candidate → commit, where the commit message IS the certificate's content hash. A deliberate post-commit push is a separate push-request under its own certificate (scripts/ceremony-drive:402-405,503-505). Review `--findings` ride the certificate as advisory data and "never satisfy an evidence requirement" (:27-32). An identity-seam leak (42 window commits rode ambient `.git/config` identity) produced the explicit commit-identity seam (:49-55). Mint-time receipts stop certificates being ephemeral (scripts/ceremony-drive:431-433, scripts/cert-receipts.lisp). Plan lifecycle law rides front-matter: `status=proposed` at propose (automation/omp-plugin/src/index.ts:6-10), accept flips it after gates, `risk=critical` parks, and a missing `principle:` line blocks acceptance (scripts/accept-plans.py:6-10).

## Open questions for web research

1. Policy-as-code deterministic admission: how do OPA/Rego, AWS Cedar, or Zanzibar-style systems model closed vocabularies and refusal labels?
2. Certificate binding to (action class, base revision, content hash): overlap with in-toto layouts, SLSA provenance, and sigstore signing — what can a single-operator ceremony borrow?
3. Expiring capability tokens with re-check-before-act executors — established nonce/expiry/replay handling.
4. Two-signature amendment rules and small-quorum governance in software projects (constitution-kernel precedents).
5. Evidence-ledger modeling: per-obligation evidence kinds produced exactly-once against a revision — analogues in audit systems.

## Candidate external systems to survey

- in-toto / SLSA provenance
- Open Policy Agent (Rego)
- AWS Cedar
- Sigstore
- TUF (The Update Framework)
