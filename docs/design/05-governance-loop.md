# 05 — The governance loop

<!-- MERGED 2026-10-13 from the 2026-08-30 doc suite, which lived
     outside version control (handoff §3.3). Provenance snapshot:
     paths and counts are as measured 2026-08-30. In particular
     `hngh-automation/` names a repo that has since merged into this
     one -- read it as `automation/`, and `~/Projects/etc/hngh` as the
     repo root. Facts that moved are fixed in place, not annotated. -->
Doc suite v1.2, 2026-08-30 (revised after adversarial audit) · part of [suite index](../core/README-architecture.md). The kernel's
purpose end-to-end: everything a machine changes must pass a certificate
bound to evidence, re-checked at the moment of action.

## 1. The principle

"Freedom is granted by certificate, measured by evidence, and revoked by
the same hand that gave it" (`docs/design/autonomous-development-control.md`).
The evaluator is deterministic for structural facts; reviewers advise and
never decide; a certificate authorizes exactly one action and is re-verified
at the moment of action. Nothing is treated as approved until a checked,
ruled-on decision says so (`docs/intent.md`).

## 2. The loop, end to end

```mermaid
sequenceDiagram
  participant S as Machine session
  participant C as ceremony-drive
  participant K as kernel (scripts/hngh)
  participant G as git
  S->>S: author change · make test (gate)
  S->>S: ceremony-drive create-run (proposal class, evidence ledger)
  S->>K: evaluate (deterministic, 10/10 principles)
  K-->>S: verdict: admitted | refused(reasons)
  S->>K: request-review (bounded, source-cited — advises only)
  S->>K: issue-cert (binds repo, base rev, paths, content hash, verdicts, expiry)
  S->>G: mutation-check → git add + commit (hash-bound)
  S->>G: push (standing rule; only after green gate)
  Note over G: commit message = certificate content hash
```

Deterministic properties (from the control doc): the evaluator never
inspects a repository, process, provider, clock, environment, or network —
it consumes immutable evidence values only; every requirement kind is
closed and duplicate-free; missing/duplicate/stale/malformed/conflicting
facts refuse. A certificate authorizes exactly one action
(`:none`, `:prepare-candidate`, `:stage`, `:commit`, `:push`), never a push
from a commit cert, and every fact is re-checked at action time. Expired
certificates, stale base revisions, changed content — all refuse.

## 3. Closed vocabularies

- **Proposal classes** (7): `feature`, `scope-broadening`,
  `capability-request`, `failure-disposition`, `review-request`,
  `commit-request`, `push-request`.
- **Evidence requirement kinds** (24, closed): `purpose`, `caller`,
  `input-contract`, `output-contract`, `failure-contract`,
  `capability-set`, `capability-diff`, `static-source`,
  `closed-failure-disposition`, `claim-proof`, `base-revision`,
  `candidate-manifest`, `content-hash`, `reversion-or-containment`,
  `component-import`, `route`, `budget`, `token-limit`, `expiry`,
  `source-manifest`, `conclusion-link`, `review`, `remote-attestation`,
  `federated-claim`. A requirement passes only when
  every required fingerprint is supplied exactly once by a `:current`
  fact — duplicates, gaps, and cross-principle reuse all refuse.
- **Certificate actions**: `:none`, `:prepare-candidate`, `:stage`,
  `:commit`, `:push` — one action per certificate; a commit certificate
  never authorizes a push.
- **Failure dispositions**: closed category → default disposition table;
  unknown categories refuse (`docs/core/component-map.md` governance row;
  `docs/design/autonomous-development-control.md` §Failure disposition).
- **Policy profiles** (promotion rung 16): operator evidence profiles
  constrain which evidence kinds may satisfy which principles
  (`evidence-profile` in `src/domain/governance.lisp`).

## 4. The principle matrix

Every proposal is evaluated before implementation and again before
mutation; a missing principle result is a refusal. Ten principles,
deterministic verdicts; landed ceremonies admit 10/10 (kernel
`docs/records/2026-08-25-r14`…`r18` rows: "admitted 10/10, certificate
bound to real evidence"). The evaluator never inspects the repository,
network, clock, or environment — pure function of the evidence ledger.

## 5. Landing rules in practice

| Surface | Landing mechanism | Gate |
|---|---|---|
| hngh docs/records | certificate ceremony (`ceremony-drive`), push to `git@github.com:boundring/hngh.git` after green | `make test` (2,855 checks) |
| hngh kernel src/tests/Makefile/hngh.asd | **forbidden to unattended machine sessions** (standing autonomy rule) — parks with operator alert | operator session, failing-test-first |
| hngh-automation | plain gated commits, each requiring green `make test` (lint-identifiers + bash -n) | local-only repo (no remote) |
| Tracked deletions | outside 48h prune = forbidden; the ceremony structurally cannot express deletions — manual `docs:` commit fallback with disclosure (hngh `c0c0bd5` precedent) | |

Dogfood history: the loop has landed every code-affecting kernel commit
since 2026-08-24 — 168 certificate-bound commits (`git log
--since=2026-08-24`: 208 commits, of which 40 are plain docs/chore/merge
using the documented manual `docs:` fallback), including its own
governance-doc changes
(`docs/records/2026-08-24-first-self-governed-commit.md`,
`2026-08-24-second-self-governed-commit.md`, loop-history guard 08-25).

## 6. Ceremony-loop lessons (in force)

From `docs/design/autonomous-development-control.md` §Ceremony-loop lessons
(2026-08-28) and `docs/records/2026-08-28-lessons-consolidation.md`:

- **Timeout-split ceremonies hand off through a runbook** — three overnight
  runs died at the 1,800s cap before the runbook closed it on the next
  loop; long ceremonies must stage their handoff, not die with it.
- **Expected-dirty ledger paths are not skew** — machine-maintained append
  paths are whitelisted in the tree-skew probe (`jobs/oversight-tick.sh:114`,
  extended 2026-08-30 commit `1113810`).
- **Refusal surfaces carry the refusal reason** — an alert that names no
  cause parks untriageable work (alert `a1fde252` lesson; sharpening is a
  kernel-src change and parks for the operator).
- **Ledger appends are structure-bound** — single-header invariant on
  `reports.md`; the inserting-writer bug class is guarded by the
  append-invariant bullet in `docs/design/ledger-and-records-spec.md` §3.
- **Gate on lint before running**; **two counters disagreeing is a signal**;
  **breadcrumbs settle attribution** (append-only crumbs beat recalled
  timelines).

## 7. Where authority sits

Human: policy authoring, acceptance of critical-risk classes, credential
placement, kernel-src sessions. Machine (normal-risk, pre-authorized):
plan execution, gated commits (plain in automation, certificate in kernel),
research beats, surface evolution. Critical class — provider/credential
config, systemd unit lifecycle, non-prune deletions, security posture —
parks with operator-facing alerts; research lines keep the machine from
idling on a human.

Cross-links: [03-kernel.md](../core/03-kernel.md) (component table) ·
[06-observability.md](06-observability.md) ·
`docs/design/autonomous-development-control.md` (the law) ·
`docs/records/2026-08-28-lessons-consolidation.md` (lessons with evidence).
