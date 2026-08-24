# Launch checklist: public readiness

Status legend: `[x]` done, `[~]` in progress, `[ ]` open. Nothing flips
until every item is `[x]` with the evidence cited. Each item states the
criterion (what must be true and verifiable), the current state with one
line of evidence, and the go/flip action when green.

Sources: `docs/project/decisions.md` (2026-08-24 decisions),
`docs/records/2026-08-24-prior-art-landscape.md`, public-face and
tooling memos (2026-08-24), repo state on `wip-public-readiness` at
`dafe3e3e` (main, origin/main at `1626228`).

## 1. Legal & posture

- [x] License: `LICENSE` is AGPL-3.0-or-later full text at repo root.
      Criterion: the license file at root is the AGPL-3.0 full text; the
      license choice is recorded as deliberate, not defaulted.
      Evidence: `LICENSE` (34 KB) is GNU AGPL v3 full text; decisions.md
      "License: AGPL-3.0-or-later affirmed" (2026-08-24) records the
      deliberate stance — strong copyleft for the failed-close authority
      and network-service disclosure; re-license closes before external
      contribution.
      Go/Flip: none; decision is final and recorded.

- [x] **CONTRIBUTORS are bound to AGPL-3.0-or-later (inbound = outbound).**
      Criterion: contribution path states the inbound license explicitly.
      Evidence: `CONTRIBUTING.md` ("License") says "Contributions are
      licensed under AGPL-3.0-or-later"; no CLA text exists.
      Go/Flip: none; keep the same sentence when `CONTRIBUTING` gains
      DCO (below).

- [~] **DCO sign-off added to `CONTRIBUTING` (DCO)**.
      Criterion: contributing commits must carry a signed-off-by line
      (DCO); docs describe DCO for contributors.
      Evidence: in flight — the wip public-readiness branch carries the
      governance/contribution/security doc drafts (dogfood slice); DCO
      is in the public-fiac emo, not yet merged on main.
      Go/Flip: when the `CONTRIBUTING` DCO amendment lands and is
      dogfood-committed, mark [x] with its commit hash.

## 2. Repository hygiene

- [ ] **Full-history secret scan (git) clean.**
      Criterion: scanning every ref in `.git` (gitleaks/truffehog over
      all commits, all reflogs included) finds zero credentials, zero
      private transcripts, zero provider keys; HEAD is equally clean.
      Evidence: no scan has been run yet. `.gitignore` covers `.omp/`
      (session state), `*.log`, `.cache`, `.codegraph`. Historical
      pre-clean-sl te commit (2026-08-24) code names include
      `src/plugins/secrets-manager.lisp`; nothing indicates real secrets
      in history, but the scan is the criterion and it has not run.
      Go/Flip: run a full scan (all refs incl. reflogs), redact if
      needed, archive the scan report here; then [x] is safe. Add the
      report path to this item.

- [~] **No retired/dead branches on the remote.**
      Criterion: `origin` shows only `main` (+ PR refs once open).
      Evidence: `git branch -a` today: local lane branches
      `lane-hngh-day-queue-a3`, `lane-hngh-queue-v3`,
      `lane-hngh-task-b-luna` exist locally; remote lists only
      `origin/HEAD -> origin/main` and `origin/main`.
      Go/Flip: before flipping public, delete or archive the local
      lane/retired branches and re-check `git branch -r` = `main`
      only. Remote is already clean; local hygiene is the action.

- [x] **CI is green on push.**
      Criterion: `.github/workflows/ci.yml` run `make test` (laden +
      tests) and it passes; README "make test" runs 8 reader guards +
      1137 checks.
      Evidence: `make test` local run on `wip-public-readiness` passes
      (8 reader guard checks, 1290 checks; `ci.yml` installs sbcl and
      runs `make test` on main/PR. Worklow runs on push to `main` +
      PR, so a public push runs the same gate.
      Go/Flip: nothing extra; keep it as is.

- [ ] **Pinfile (.pinignore) pinned**.
      Not asked / not in repository today: `.pinignore` does not exist
      (no pinignored tooling — the dossier says "pinned `.pinignore`"
      as a go-creen for the first public stage; the file needs to be
      added and committed with the pinning decision (which files are
      not pinned) before public.
      Go/Flip: add `.pinignore` or pin the list, with a one-line
      rationale, during the public prep — see §10 flips order.

## 3. Governance surface

- [~] **`GOVERNANCE.md` exists and is dogfood-committed.**
      Evidence: not present on main yet — the branch
      `wip-public-readiness` (draft in flight, first dogfood mutation).
      Criterion: the file exists in the tree; it names the
      fail-closed invariant never-list, authority (operator; later a
      documented process), and the 7-day change window.
      Go/Flip: land `GOVERNANCE.md` (and SEcurity/contributing
      amendments) together as the first mutation that goes through the
      real evidence chain (proposal -> verdict -> c. etificate ->
      -> execuited commit), so the docs are not paper but evidence-gated.
  goat: "no public merge authority off-operator" clause in text.

- [ ] **`SECURITY.md` exists** with CVD: report channel, 48h ack,
     45-day unresponser-vendor disclosure rule (public-fac emo).
      Evidence: not committed yet (same in-flight doc batch).
      Go/flid: same as governance item; the SECURITY doc lands and
     is committed; channel-must-be-live check is in §10.

- [ ] **`CONTRIBUTING` DCO amendment (item above)** lands in the same
      first mutation batch; and not on main.

## 4. Real evidence chain

- [ ] **The first self-governed commit is real and reverifiable**.
      Criterion: the first commit governed by Hngh (the dogfood loop's
      propos/evidence cue, the doc batch) is executed — not fixtured —
      and its evidence (proposal, verdict, certificate, commit hash)
      is reverifiable from the repo alone by a third party.
      Evidence: the `mutation-ports` helper for the real run is the
      piece in flight (RealEvidenceChain current state on the wip);
      today `mutation-check` can run in-process with fixtures
      (CHANGELOG 2026-08-24 governance command surface record), so
      "real" is currently [ ].
      Go/Flip: wire the real git evidence (rev-parse, tree status,
      hash) into `mutation-check` and record the run; this is the
      baseline on which every other governance-item [x] rests.

## 5. Public communication

- [x] **README position covers its own status honestly.**
      Criterion: README describes Hngh as a kernel library +
      governance, not a mature application; it does not overclaim.
      Evidence: "today the kernel is a pure library with fixture tests"
      and "Not yet: persistence, CLI, clock/environment access in the
      kernel, daemon, real model or provider transport, or Pi worker"
      (README Status); the hard "not finished" language is already
      there.
      Go/Flip: none; re-read once before flipping (write: README gets
      the governance/nete pointers too — flips list).

- [ ] **docs README read order / outsiders** path — check the doc-
      README, slated to link the three governance docs once they exist
      (the "ovo" pointer); commit that as part of the batch.

## 6. Public intake (future surface, not an authority)

- [x] **Intake claims are not attestations.**
      Evidence: decisions entry (2026-08-24) — public intake carries
      E0 candidate records (claim; operator re-verify: recompute
      saves, repros), never a fork; no-PKI (sigle-machine) stays.
      Go/Flip: the intake-lane design must state this up front on
      the public surface.

- [ ] **Intake lane is designed but not flipped.**
      The public face memo: "flip the intake lane only at public
      launch"; intake sketch (identity-graded, E0-ED, reproducible
      evidence mandatory, operator review queue, never auto-accept)
      is written; today no intake code/config exists.
      Go/Flip: written design (in the public-face memo) + explicit
      "not yet" on the public surface; don't flip before §1-4 green.

## 7. Governance-change cadence

- [ ] **7-day window documented + who-amends + never-clauses.**
      Evidence: the "evidenced PR + 7-day review window" (em o) and
      "never clauses: never- fail-closed (point 1), never- elevate
      (see list)" are copied into GOV ERNANCE; the amendment path is
      written.
      Go/Flip: land with GOV ERNANCE (§3) — same commit, same chain.

## 8. Metrics / teleetry

- [x] **No telemetry ships, by default; stays optional-off.**
      The mem o's CHOS-like funnel plan (intake -> verified -> lesson
      latency, reviewer throughput, helpful-votes) is optional and
      off by default; nothing is implemented; no beacon.
      Go/Flip: none now; keep off-by-default; if added later it is
      optional/off and the plan (CHAOSS-like, not vanity) is in the
      record.

## 9. Legal identity

- [x] **No foundation/formal entity until money appears** — recorded
      in the public-faci em o; the rule (only for money, opensource.
      guide) is in the doc; there is no entity today.
      Go/Flip: none; wait for a propos.

## 10. Flips at launch (order)

1. [ ] Repo public: requires §1-§4 closed (`git remote`, the
   visibility flip itself is a recorded decision).
2. [ ] Issues/PR template + editor + CODEOWNERS on the public repo
   (kernel-critical paths: crypto, fail-closed gates, ledger) —
   shepard backing, never merges off-operator at first.
3. [ ] Discussion/governance channel live only after GOV ERNANCE has
   the 7-day window and never-clauses written and committed.
4. [ ] Intake lane stays off until the intake design (state up front
   in §6 is written.
5. [ ] Telemetry stays off; all such is off by default and re-openable   without touching authority.
6. [ ] The governance docs, README links, and .pinignore are part of
   the flip commit (or the commit that opens the repo has all of them).

## Evidence & inputs

- Repo facts anchored where possible in `docs/project/decisions.md` and
  `docs/records/*`; the public-face emo and tooling-design emo are the
  strategy record; CI gate = `.github/workflows/ci.yml`.