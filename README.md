# Hngh — Hierarchical Networked Governance Habitat

A side-effect-free Common Lisp kernel and a federal edge: one small,
predictable core decides validity; thin domain kernels do the work —
plugged in at the edges, gated, and always auditable from one register.

Hngh separates powers: every edge either observed or certified, the
core slow by certificate while the edges move fast.

## The three branches

- **Judicial** — the constitution kernel (`src/`, ~3k LOC). Refuses any
  mutation inconsistent with the Charter via `propose` →
  `issue-cert` → `mutation-check`; prior records live in
  `docs/records/`.
- **Legislative** — beads and accepted plans are laws: event-driven
  intake (state emitter files, Jev triage heads sort) plus a deliberate
  track (T1 tiers, roadmap stages), with operator signature required
  only for kernel-surface law.
- **Executive** — the cadence driver and its domain kernels, where Jev
  verdicts stay within certified bounds and Hngh commands the Jcode
  fleet, never the reverse.

Checks are mechanisms: budget-ceiling veto in the cadence beat,
operator override, the gate refusing uncertified mutations,
confirmation audits before new kernels are admitted, operator kill
switch on any process, and amendment through the certificate ceremony.

## The loop

    state change → question set → judgment → bead → slice → gate → record

Every kernel implements the same three verbs: `observe` (read the
ledger), `judge` (Jev seam call or deterministic check), `act` (write
an event, or request a certificate). Kernels never talk to each other
directly — every edge is an event or a certified mutation. That single
rule makes the network loop-proof and auditable.

## Jev — the judgment organ

Small local models answering bounded, slot-and-label questions over
typed state deltas. Jev recommends, never certifies: every verdict is
advisory, the certificate lane stays the only mutation path, and
unreachable or unparseable backends fail closed to escalation. Every
call is logged with its eventual outcome — the ledger is the training
set, and operator-resolved escalations are the curriculum for future
per-domain heads.

## Two homes

- Repo (this repository): kernel, ceremony, automation edge.
- `~/.hngh/` — userspace data (never committed).
- `~/.hngh-automation/` — secrets and kernel stores via the 1Password seam.

## Orientation

- Start: `docs/README.md`
- Roadmap: `docs/project/roadmap.md`
- Charter: `docs/project/plans/2026-09-20-federal-charter.plan.md`
- Ceremony: `python3 scripts/omp-bridge --orient`
- Dashboard: `http://127.0.0.1:8890/`

## Current state (2026-09-20)

The kernel suite is machine-counted: `make test` reports
"past 2,931 checks", and the doc-numbers guard fails when this line
drifts from the live suite.
Full halt maintained after the 2026-09-20 halt review; federal charter
proposed; automation-ng skeleton landing under `automation/ng/`.