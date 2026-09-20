<!-- plan: status=accepted risk=normal accepted=2026-09-20T17:35:00Z -->
# Federal Charter: three-branch operating structure for the Hngh Megastructure

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

## Purpose

Encode the 2026-09-20 reorganization of Hngh as a federal harness: one
constitution kernel, many thin domain kernels below it, powers
separated: every edge observed or certified, the core slow by
certificate while the edges move fast.

Operator authorization: full rewrite authorized 2026-09-20.

## Evidence (why structural, not cosmetic)

The 2026-09-20 halt review found the exact failure modes the federal
design exists to prevent: power concentration (router planned, executed,
and judged — looped), executive overreach (dev-synth deciding validity),
runaway legislation (plan graphs to 940 nodes), bureaucratic sprawl
(70k LOC edge vs 3k LOC kernel), and a no-referee crisis (kernel gate
red 2 days, nothing halted). Separation of powers with checks is the fix.

## Topology: hub-and-spoke, never mesh

One constitution kernel (src/, unchanged, ~3k LOC). All other kernels
are spokes. Load-bearing rule:
kernels never talk directly to each other; every edge is (a) an Event
written to the ledger, or (b) a mutation certified by the constitution
kernel. This makes loops structurally impossible and the whole network
auditable from one register.

## Branches

Judicial (metaphor) — the constitution kernel. Plain terms: the gate
refuses any mutation inconsistent with the Charter. Mechanism:
propose -> issue-cert -> mutation-check. Prior records live in
docs/records/. Appeals terminate at the operator.

Legislative (metaphor) — the bead chamber. Plain terms: beads and
accepted plans are laws. Event-driven intake: the state emitter files
bead.ready events; Jev triage heads sort them. Deliberate track: T1
tiers, roadmap stages, kernel-affecting law under the two-signature
rule (certificate + operator ratification). Kernel-surface law needs
operator signature; automation-surface law passes without. Parked beads
are a deferred queue by design, not a loop.

Executive (metaphor) — the cadence driver and its domain kernels
(publication, manga, research lines, the Jcode fleet). Plain terms: Jev
verdicts operate WITHIN certified bounds, never as new law. Hngh
supervises Jcode, never the reverse. Operator gate on consequential
actions. Impeachment (metaphor; audit trail: escalation.filed): the
operator kill switch on any executive process.

## Checks and balances

- Veto: executive refuses dispatch violating spend ceilings (budget
  ceiling check in cadence beat, sequenced with the Jev hardening fix).
- Override: operator overrule, recorded in the ledger.
- Judicial review: uncertified/unconstitutional mutations refused.
- Confirmation: new kernels/heads admitted only after first audit.
- Impeachment: operator stop, logged as escalation.filed.
- Amendment: certificate ceremony on the Charter itself (this plan).

## Federalism (already standing, now named)

Federal = kernel src/, ceremony, two-home split (secrets in
~/.hngh-automation, userspace data in ~/.hngh). States = domain
kernels. AGENTS.md draws the boundary; everything unlisted is reserved
to the operator. The event bus between kernels is regulated by the
kernel contract. Fail-closed rules: no mutation without certificate,
secrets stay home, evidence before claims, rights not delegated remain
with the operator.

## Registers and guards

The ledger (events.jsonl) is the record of every event. The watch
kernel (sequenced step 1: watch.py) emits audits as audit.finding
events. The budget ceiling check in the cadence beat enforces spend
ceilings with ladder degrade near cap.

## Rules the history teaches

Agent budget caps. Operator authorization required for consequential
actions. Two-home secrets seam (secrets never leave ~/.hngh-automation).
Fail-closed: evidence before claims. Operator sovereignty over all
unlisted powers. No parties, no elections: one operator, total
visibility, no manufactured opposition.

## Kernel contract (three verbs)

Every kernel implements observe / judge / act: read state from the
ledger; answer via the Jev seam or a deterministic check; write an
event or request a certificate. A kernel needing a fourth verb is two
kernels — file a bead to split it.

## Jev seam (the judgment organ)

Input that works: typed event deltas; fixed-slot decision rows mapped
to closed label sets; aggregates over transcripts (never transcripts
themselves); evidence excerpts cited by hash; every verdict bound to
the state_version it judged (stale verdicts invalidatable). What fails:
free prose logs (the firehose), open-ended questions, world knowledge.
Doctrine: Jev recommends, never certifies; verdict entropy per head is
a first-class metric. Training path: every call is logged as (input,
verdict, outcome) — the ledger is the training set; operator-resolved
escalations are the curriculum; ground truth comes from gates, never
from Jev grading itself. Off-the-shelf small models now (unsloth :8888);
per-domain fine-tuned heads when logged outcomes mature.

## Rebrand

New acronym meaning: Hierarchical Networked Governance Habitat. README
rewritten to the federal/megastructure framing (this slice). Fresh-start
option — archive the prior repo, start a new repo with the same name —
is staged as an amendment awaiting operator ratification; NOT executed
by this plan.

## Sequencing

1. automation-ng skeleton (this slice, in flight): contract.py,
   state_emitter.py, watch.py, jev.py, tiering.py, cadence.py.
2. Kernel gate fix (RESTATEMENT SHA orphaned by the 2026-09-20 scrub)
   through its own certificate path.
3. Plan acceptance; port the four weeded T1 beads through the new loop.
4. Jcode guard rails: node cap per graph, staged dispatch, spend
   ceilings. Hngh supervises Jcode, never the reverse.
