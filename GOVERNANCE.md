# Governance

Status: draft for review, 2026-08-24, branch `wip-public-readiness`.
This document and `SECURITY.md` are the first changes planned to run
end-to-end through the self-governed loop once the real evidence chain
lands (decision 2026-08-24: governance documents are the first
dogfood-loop mutation). Until then they are drafts of record.

## 1. Purpose and authority

Hngh is operated as a single-maintainer project under a
benevolent-dictator-for-now (BDFL) model until a recorded decision
changes that.

- The operator guides policy, budgets, privileged work, release
  posture, and safety-boundary changes (`CONTRIBUTING.md`, "Scope").
- The operator is the security responder (`SECURITY.md`) and the
  final escalation point for every decision.
- A rule of this project exists only as a recorded decision in
  `docs/project/decisions.md`. This document states those decisions;
  it creates none. When this document and the record disagree, the
  record wins and the document is wrong.

This model is not fixed. It may be shared, transferred, or ended by a
governance change (section 4). The first contribution from outside
the project opens the review window of section 4 — the same window,
not a stronger or weaker one, because it is the first.

## 2. Never clauses

The following clauses are unconditional. No workflow, profile,
adapter, model, or operator instruction overrides them. They are
"never" because the project fails closed: an unverifiable claim is
refused, never guessed at, and these clauses hold in every profile,
including the human-approval profile.

1. Never unbounded mutation. One admitted action, from the closed
   set prepare, stage, commit, push. A certificate for one action
   never extends to another, and a committed revision does not
   authorize a push. The executor re-checks current facts and
   expiry immediately before every admitted action (decisions
   2026-08-12, 2026-08-17).

2. Never rewrite history around a review. No force-push and no
   history rewrite (amend, rebase, filter) replaces the evidence
   and review pass. A rewritten history is a rewritten record: it
   must be re-evaluated, and earlier approvals do not travel with
   it.

3. Never ambient execution. There is no daemon, provider transport,
   watcher, scheduler, or background process at this stage.
   Importing the harness starts no work; the kernel has no side
   effects (decisions 2026-08-11, 2026-08-18; `docs/project/
   roadmap.md`).

4. Never take submitted material as verified. Public intake
   contributions are claims, not attestations. Nothing is admitted
   until the operator's machine re-verifies it against source,
   hashes, and reproduced runs (decisions 2026-08-24). The no-PKI
   boundary holds until a recorded decision reaches the
   distributed-attestation rung; it is not triggered by the intake
   lane opening.

5. Never let a reviewer decide. Reviewers — model providers and
   people — advise; they never decide. A review finding is
   evidence, not an order: a reviewer cannot override a
   deterministic refusal, cannot issue a certificate, and cannot
   mutate the repository (decisions 2026-08-12).

The human-approval profile adds a human gate inside this frame; it
suspends none of the clauses.

## 3. How decisions are made

### 3.1 The self-governed path (default)

The routine path is the policy-certificate path decided on 2026-08-12
and expanded, with the principle order and the non-mutating candidate
certificate, on 2026-08-17.

1. A proposal states one named change: the behavior or smallest
   outcome intended, its closed mutation class, and the purpose
   contract it must keep.
2. An evidence ledger fixes, for every principle, exactly which
   evidence kinds and fingerprints are required, and each evidence
   fact must be produced once and only once against the current
   repository revision.
3. A deterministic evaluator checks the proposal against the ten
   closed principles in matrix order: closed authority, least
   authority, dependency direction, fail closed, evidence before
   claim, atomic mutation, reversibility, no hidden execution, cost
   and route discipline, source grounding. A missing, stale,
   conflicting, malformed, or unverifiable item refuses the proposal
   with a named label; the verdict is admit only if every principle
   passes.
4. A certificate is then minted, binding one action class, the
   repository identity and base revision, the ordered candidate
   manifest and content hash, the evidence hashes, the admitting
   verdict, review findings, the profile, and the expiry.
5. The executor re-checks the current facts and the expiry
   immediately before executing the single certified action. Commit
   never implies push.

Policy-authorized self-approval is the intended path (2026-08-24);
the certificate is the only approval token.

### 3.2 The human-approval profile

Where a deployment must close the loop with a named human, the
human-approval profile remains available (2026-08-24; `CONTRIBUTING
.md`, "Scope"). The operator guides which profile a deployment runs.
The human gate adds an attested sign-off to the same evidence and
verdict; it is an additional gate, never a shortcut past the
re-verification steps.

### 3.3 Models in the loop

Model reviewers are bounded: closed prompts, source-cited findings,
sanitized outputs, one evidence record per finding (component map,
`review` port). They advise; they never decide. Their findings are
evidence like any other, subject to the same evidence rules, and a
reviewer cannot pass a principle that policy does not admit
(decisions 2026-08-12).

## 4. Governance changes

The governance documents are `GOVERNANCE.md`, `SECURITY.md`, and the
contributor commitments in `CONTRIBUTING.md`. A change to them runs
like any other evidenced pull request: it names the problem, the
decision record it relies on, and the acceptance evidence, and every
commit carries a DCO sign-off (`CONTRIBUTING.md`).

- The review window is 7 consecutive days. The PR stays open at
  least that long and the record shows the exchange, not just a
  merge. The window opens the same way for the first contribution
  from outside the project — it is judged on the same evidence, no
  faster because it is first.
- Substantive objections raised in the window are answered in the
  thread, and the answer is part of the record. At window end the
  operator decides; the window is a minimum, not a vote.
- Amendments — changes to section 2 or to the authority model of
  section 1 — additionally run the multiple-approve-N rule: no
  amendment is admitted until at least N = 2 approval findings,
  each from a different person and each with a recorded comment,
  are present. N itself changes by governance change only.
- Until the first outside contribution the operator may still
  self-govern changes alone. That is the BDFL reality; it is not a
  discrepancy in the loop, and it is replaced by the window for
  outside contributions from day one of a contribution's review.

The governance documents are the first planned self-governed
mutation (status line above); they are not governed by exception.

## 5. Intake policy

There is no open public intake today. When channels open (tracker,
form, email), the policy is fixed in advance:

- Every submission is a claim with a declared entry level, and the
  default is E0 — reported, not verified (decisions 2026-08-24).
  A claim becomes evidence only after the operator's machine
  re-verifies it locally: recomputed hashes, reproduced runs,
  current source.
- Nothing is auto-adopted. The review queue is public, adoptions
  and refusals are evidenced, and refusals carry a reason. A claim
  that does not verify is refused, never guessed at.
- Intake does not change the no-PKI boundary (section 2, clause 4).
  Identity is weak; evidence is strong. Promotion runs only on
  evidence that was re-verified.
- Malformed or unverifiable submissions, and requests that would
  violate these clauses, are refused, not worked around.

## 6. Related documents

- `docs/project/decisions.md` — the authoritative record this
  document states and defers to.
- `CONTRIBUTING.md` — scope, workflow, boundaries, DCO sign-off.
- `SECURITY.md` — the vulnerability response runbook.
- `docs/project/roadmap.md` — the stage plan and the no-daemon
  frontier.
- `docs/core/clean-architecture-charter.md` — architecture
  constraints a governance change must not violate.
- `docs/records/2026-08-24-prior-art-landscape.md` — the compared
  prior art and the recorded divergences.