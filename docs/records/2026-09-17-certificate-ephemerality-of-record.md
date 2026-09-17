# 2026-09-17 — certificate ephemerality of record: the kernel certificate
# is single-use by construction, and no decision ever made it so

## The finding (confirmed gap, upgraded from caveat)

Every kernel ceremony mints an authorization certificate and then
destroys it. `scripts/hngh issue-cert` mints the certificate in
memory (`src/main.lisp:1441` `real-issue-cert` -> `real-certificate`
-> `hngh.domain:issue-candidate-certificate`) and returns the rendered
form as the command's stdout string (`src/main.lisp:1459-1461`; render
template `src/presentation/render.lisp:97-113`). Nothing in kernel
`src/` writes a certificate to any store: the only store writes are
run receipts (CREATION/ADMISSION/START/CLOSE/CHECKPOINT), and a census
of `~/.hngh-automation/store` (932 record.lisp files) found zero
64-hex tokens and zero certificate-kind receipts
(docs/records/2026-09-17-candidate-reconciliation-closure.md). The
certificate render line — `certificate action=... repository=... base=...
paths=... content-hash=... evidence-hashes=... verdicts=... findings=...
manifest=... policy-profile=... expiry=...` — exists only for the
moment a human or wrapper reads the terminal.

Consequences, restated as facts of the record:

- The commit subject `hngh: candidate <64hex>` is the certificate's
  only durable trace. There are 299 such labeled commits on `main`
  (`git log --grep='^hngh: candidate ' --format=%h | wc -l`).
- Post-hoc verification of any labeled commit against its certificate
  is structurally impossible: there is no artifact to verify against.
- The kernel loop-history guard's candidate acceptance is format-only:
  `CANDIDATE = re.compile(r"^hngh: candidate [0-9a-f]{64}$")`
  (tests/scripts/test-loop-history-guard.py:193), accepted at :285
  with nothing consulted. A subject matching the regex passes history
  surveillance regardless of whether a certificate was ever minted,
  and cannot be distinguished from a real mint by any active gate.
- Side captures are accidental, not systemic: of 8 sampled window
  content-hashes, exactly 2 appear anywhere outside git commit
  subjects — one quoted in a hand-written record
  (docs/records/2026-09-16-progress-kind-path-redaction.md:37, the
  `79eb4733` ceremony narrative), one in an opencode transcript log
  (automation/logs/overnight-2026-09-09-rehearsal-lane-dream-
  20260916T050440.log.json). The other 6 (including window label
  `695e32c9...`, commit `6e5d9f7b`) have zero non-git occurrences.
  Grep for the full 64-hex forms across docs/, docs/records/, and the
  working tree returns nothing for them.

## Open question 1 resolved: design gap, not known limitation

Searched for an explicit design decision on certificate
persistence/ephemerality across roadmap.md, decisions.md, design/,
and records/. Result: no such decision exists anywhere.

- `decisions.md` 2026-08-24 "No PKI; hash self-certification is a
  single-machine decision" (lines 62-76) addresses signing authority,
  not artifact lifetime. It is the closest decision and it is silent
  on persistence.
- `docs/design/autonomous-development-control.md` specifies what a
  certificate records (Authorization certificate section) and its
  explicit non-goals exclude "filesystem persistence ... in this
  design task" — a scope boundary for the 2026-08-12 design task, not
  a lifetime decision about the artifact.
- `src/application/close-run.lisp:16-17` ("No certificate is issued
  here: the hash-bound certificate vocabulary serves the future
  mutation executor") hints at deferral, but it scopes certificate
  use, not certificate storage.
- The prior-art record (docs/records/2026-08-24-prior-art-landscape.md)
  adopts in-toto's evidence monotonicity as an invariant with property
  tests, and explicitly names "tamper-evident governance" as the
  unmeasured property (lines 56, 72). Ephemerality is in tension with
  the project's own adopted monotonicity principle: a one-action
  certificate that leaves no trace cannot be re-verified, so evidence
  cannot accumulate across the certificate's use.

Classification: **design gap**. The ephemerality is an emergent
side effect of rung-by-rung promotion (the certificate issuer was
promoted pure, per the promotion ladder, and no rung ever carried the
storage responsibility), not a decision anyone made or recorded. The
post-hoc surveillance consequence was surfaced only on 2026-09-17 by
the automation-side reconciliation beat.

## Open question 2 resolved: records quote the label, not the render

Ceremony records cite the candidate hash, but never by quoting a
certificate render line at issue time. The one exception proves the
shape of the gap: docs/records/2026-09-16-progress-kind-path-redaction.md
reconstructs the hash from the commit subject ("content hash
`ebd74640...`") in prose after the fact — the author had the subject,
not the render. No record quotes the full render line (action=,
base=, paths=, evidence-hashes=, verdicts=, manifest=,
policy-profile=, expiry=); grep for `content-hash=` across docs/
returns only unrelated command-option references (task-r10/r13
review-transport CLI syntax), and the store contains zero
`content-hash=` rows. A render line quoted in a record today would be
testimony, not evidence — nothing distinguishes it from a paste of
the commit subject.

## What this record lands

Documentation only (machine free-commit lane; kernel `src/` untouched):

1. This record: the confirmed gap and its evidence, replacing the
   caveat-level state with an of-record classification.
2. Cross-links: gate-inventory row (the guard's format-only limit is
   now stated on the gate itself), decisions.md entry (the gap's
   summary and the chosen remediation direction), CHANGELOG.md entry
   (record of the landing).
3. Adoption of the remediation direction already proposed on the
   automation side — the record that did the mechanism work is
   docs/records/2026-09-17-candidate-reconciliation-closure.md, which
   landed the feasible rung (label-to-content reconciliation patrol
   check, commit c2bda901) and proposed the strong rung (mint-time
   certificate receipt written to the run's store record.lisp at
   `real-issue-cert`, plus a `label-unbacked` checker phase). This
   record adopts that proposal as the direction and adds the
   cost/benefit statement the automation record left implicit.

## Remediation options, with cost/benefit

- **Option A — persist certificates at mint time (adopted direction).**
  At `real-issue-cert`, append a `:certificate` receipt (content-hash,
  action, base, paths count) to the minting run's store record.lisp;
  extend the automation reconciliation check with a ledger phase
  (`label-unbacked` FAIL when a labeled commit has no row). Cost: one
  kernel ceremony slice (src/ mutation, certificate path) plus a
  free-commit checker extension; both seams already exist. Benefit:
  closes both directions — forged self-consistent labels fail within
  one patrol day, and every historical label becomes verifiable
  forward from adoption. Respects the two-home split (store is
  machine state, never repo surface).
- **Option B — kernel guard reads the ledger.** Promote the ledger
  requirement into tests/scripts/test-loop-history-guard.py itself.
  Cost: another kernel slice; higher blast radius on the gate the
  machine depends on. Benefit: enforcement at commit time rather than
  patrol time. Defer until Option A has operated for a window.
- **Option C — accept and document (status quo plus this record).**
  Cost: zero engineering; fabricated labels pass history surveillance
  indefinitely, and the guard's "ceremony law" verdict in
  gate-inventory overstates what it checks. Rejected as a steady
  state: it contradicts the adopted monotonicity principle; kept only
  as the fallback if the operator declines Option A.

## Not done / follow-ups

- No kernel src/ change was made; Option A needs a ceremony slice and
  is proposed, not implemented (staging boundary, 2026-09-03).
- The two pre-closure stragglers (`331fc633`, `117d463f`) remain
  declared-exempt rows; their original certificates are unrecoverable
  and stay unrecoverable.
- The 42-window guard surface and the CANDIDATE regex line numbers
  were taken from the assignment's probe and re-verified at :193/:285;
  the enforcement-path promotion (Option B) is unscoped beyond this
  record's sketch.
- `automation/docs/records/` (the free-commit tree's own records
  directory) was not appended to; the kernel-side records tree is the
  correct home for an architecture-relevant finding, and the
  automation record is already linked both ways.

Back to the [records index](README.md).
