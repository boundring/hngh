# Governance

Status: aligned record, 2026-09-23. This revision brings the document
into line with the federal-charter authority model the operator
ratified on 2026-09-20 (docs/project/plans/2026-09-20-federal-charter
.plan.md) and directed into this text on 2026-09-23. Its tone and
authority are informed by the Taoist and Confucian canon
(~/Projects/etc/tao-confucian-canon/docs) held together with the
democratic and humanist ideals of the US federal constitution. Voice
registers follow ~/Projects/etc/tao-confucian-canon/voices as
registers only, never endorsements. Under the golden rule below, the
record wins: where the 2026-08-24 BDFL draft disagreed with the
accepted charter, this text follows the record.

## 1. Whence authority

Authority is delegated and conditional. The people the software
serves are "the most important element"; the sovereign is the
lightest (Mencius). Nothing here is final simply because it is
written: "The Tao that can be trodden is not the enduring and
unchanging Tao" (Tao Te Ching, ch. 1), so every clause below stays
revisable by section 11.

- The operator guides policy, budgets, privileged work, release
  posture, and safety-boundary changes (`CONTRIBUTING.md`, "Scope").
- The operator is the security responder (`SECURITY.md`) and the
  final escalation point for every decision.
- A rule of this project exists only as a recorded decision in
  `docs/project/decisions.md`. This document states those decisions;
  it creates none. When this document and the record disagree, the
  record wins and the document is wrong.
- One operator, no parties and no elections (federal charter).
  Legitimacy is a performance contract, not a possession: office is
  held under the recall and exit terms of section 11.

Roles are contracts, not persons (section 2). Power here is held the
way the canon's three treasures describe: compassion, economy, and
not presuming to go first (Tao Te Ching, ch. 67).

## 2. Names before power: offices and role contracts

Rectification of names first: where names are not correct, language
is not in accordance with the truth of things (Analects) — define
the office before judging the officer. Every office in section 3
carries a role contract: its powers, its refusals, its evidence
duties, and its removal terms. Roles are detachable from persons and
revocable; governance means self-rectification before rectifying
others.

Due process follows the same chain: names, then language, then
affairs, then punishments. Nothing is judged against an undefined
office, and no sanction precedes a correct name.

## 3. Three branches, due degree

Harmony is regulated motion, not stillness. Each branch acts within
its due degree, and each check is conditional and mutual (Analects:
the ruler employs with propriety, the minister serves with
faithfulness — neither duty unconditional).

- **Judicial — the constitution kernel.** The pure Common Lisp
  kernel admits only certificate-bound change: propose →
  issue-cert → mutation-check. It judges; it never initiates. The
  certificate is the only approval token (section 6).
- **Legislative — the bead chamber.** Issues and amends law under
  the two-signature rule: kernel-surface law needs the operator
  signature, automation-surface law passes without. Amendment
  procedure: section 11.
- **Executive — the cadence driver and the domain kernels.**
  Executes admitted work on schedule. A kernel's contract is
  observe, judge, act — nothing else: a kernel needing a fourth
  verb is two kernels. Impeachment is `escalation.filed`.
- **Checks.** Veto, confirmation, impeachment, amendment — each
  held by a different seat, none self-issued.
- **Federalism.** The constitution lives in `src/` and the
  ceremony; `automation/` is the free surface. Userspace data
  lives in `~/.hngh/`, secrets and run stores in
  `~/.hngh-automation/`: two homes, never mixed.

## 4. The minimal kernel

"Governing a great state is like cooking small fish" (Tao Te Ching,
ch. 60): over-handling ruins what is governed. The platform does the
least that suffices. There is no daemon, provider transport, watcher,
scheduler, or background kernel process (never clause 3); every
addition of permanent process justifies itself in writing and is
removed when its justification lapses.

Institutions must not pre-carve people or designs into single uses.
Keep the uncarved block: general mechanisms over special cases, and
the unoptimized protected from metric-driven harvesting (Chuang Tzu's
useless tree survives the axe).

## 5. Never clauses

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

## 6. How decisions are made

### 6.1 The certificate path (default)

The routine path is the policy-certificate path decided on
2026-08-12 and expanded, with the principle order and the
non-mutating candidate certificate, on 2026-08-17. Sincerity is
integrity as correspondence: words answer to things, claims answer
to evidence (Doctrine of the Mean).

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

### 6.2 The human-approval profile

Where a deployment must close the loop with a named human, the
human-approval profile remains available (2026-08-24;
`CONTRIBUTING.md`, "Scope"). The operator guides which profile a
deployment runs. The human gate adds an attested sign-off to the same
evidence and verdict; it is an additional gate, never a shortcut past
the re-verification steps.

### 6.3 Models in the loop

Model reviewers are bounded: closed prompts, source-cited findings,
sanitized outputs, one evidence record per finding (component map,
`review` port). They advise; they never decide. Their findings are
evidence like any other, subject to the same evidence rules, and a
reviewer cannot pass a principle that policy does not admit
(decisions 2026-08-12).

## 7. Root before branch: sequenced work

Root before branch, in fixed order (Great Learning): investigate
things, extend knowledge, make thoughts sincere, rectify the heart —
then cultivate the person, regulate, govern. The roadmap's stages
follow the same discipline: each stage starts at its root, and no
stage skips its gate (`docs/project/roadmap.md`). Leadership takes
the low place: rivers and seas lead by being lower (Tao Te Ching,
ch. 66); the office serves the run.

## 8. Trust, intake, and the people's audit

Faith is the irreducible asset: "If the people have no faith in
their rulers, there is no standing for the state" (Analects). Trust
is therefore never assumed; it is re-verified. "All the people say
so, then examine, and only then employ" (Mencius) — agreement is a
claim, examination is the gate.

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
- Intake does not change the no-PKI boundary (section 5, clause 4).
  Identity is weak; evidence is strong. Promotion runs only on
  evidence that was re-verified.
- Malformed or unverifiable submissions, and requests that would
  violate these clauses, are refused, not worked around.

## 9. Care duty and economy

The three treasures govern the use of power: compassion, economy,
and not presuming to go first (Tao Te Ching, ch. 67). For the
machine this means the minimal kernel (section 4); for people it
means an active duty of care — non-assertion is not neglect.
Non-injury is the floor, not the ceiling:

- Users' data, attention, and dignity are held in trust. Privacy by
  default; nothing is harvested that the work does not need.
- Burden stays light: light levies, unhurried seasons (Mencius).
  Compute, cost, and demands on the operator are budgeted and
  disclosed (cost and route discipline, section 6.1).
- The unoptimized is protected: people, code, or land that score
  badly on a metric are not thereby made expendable (the useless
  tree, section 4).

## 10. Instruments and the mirror mind

Power's instruments are disclosed, named, and logged: every hook,
patrol, and automation surface is visible in the repository, and
its telemetry is readable by the operator. There is no hidden
execution (section 6.1) and no secret law.

Custodians keep a mirror mind (Chuang Tzu: the mind "responds but
does not retain"): act on what is in front of the work, without
grudge, without capture, without accumulated interest. Instruments
serve the current fact, never a stored grievance; logs are evidence,
not leverage.
## 11. Governance changes

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
- Amendments — changes to section 5 or the authority model of
  section 1 — additionally run the multiple-approve-N rule: no
  amendment is admitted until at least N = 2 approval findings,
  each from a different person and each with a recorded comment,
  are present. N itself changes by governance change only.
- Until the first outside contribution the operator may still
  self-govern changes alone. That is the single-operator reality;
  it is not a discrepancy in the loop, and it is replaced by the
  window for outside contributions from day one of a contribution's
  review.

These documents state the record. The 2026-09-23 alignment changed
no authority: it brought the text into line with decisions already
recorded (the federal charter, 2026-09-20). It was not governed by
exception.

### Dissolution and succession

No office is personal. A holder serves the standard, not the
reverse: when a ruler or minister can no longer hold the office,
the holder "is changed" (Mencius); out of office, the same person
is "a mere fellow" (Mencius). No holder is the standard; the
standard is. Dissolution or succession follows the same path as
any change: recorded in `docs/project/decisions.md`, evidenced,
never silent. Nothing in these clauses outlives the decision that
replaces them.
## 12. Tensions held openly

Four tensions run through this document. They are held openly, not
resolved by ignoring them:

- Hierarchy of function against equality of persons. Offices
  differ in scope and burden; the persons holding them are equal
  before the law and among the people. Rank is a schedule of
  duties, never a scale of worth.
- Non-assertion against duty of care. The kernel stays minimal and
  does not act where it is not called; toward people, restraint is
  not neglect — the care duty of section 9 governs, and quietism
  excuses no owed care.
- Sage standards against consent. The sage is an office
  specification, not a ruler: the people hold office and recall it
  (Mencius). Competence is a qualification; consent is the
  authority.
- Harmony against dissent. Harmony is equilibrium, not silence;
  petition is the due degree of dissent, and the protected
  channels of section 8 are where it lands. A record that shows no
  dissent is a broken record.

Where the branches disagree, the higher clause wins: the people's
standing (section 1) outranks the efficient branch, and the never
clauses (section 5) outrank any outcome.

## 13. Related documents

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
- `docs/project/plans/2026-09-20-federal-charter.plan.md` — the
  accepted three-branch charter this alignment serves.

External, read-only, provenance of voice and principle only — never
law: the annotated classics at `~/Projects/etc/tao-confucian-canon/docs`
and the author voices at `~/Projects/etc/tao-confucian-canon/voices`.
