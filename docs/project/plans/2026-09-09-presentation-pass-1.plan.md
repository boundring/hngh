<!-- plan: status=accepted risk=normal accepted=2026-09-09T20:01:16Z -->
# 2026-09-09 — presentation pass 1: front door, docs spine, flavor layer

Authorization: operator-directed 2026-09-09 (presentation as
first-class acceleration work; doctrine §3). North star:
docs/design/presentation-direction.md — classy, dry, witty; Nihei
architecture and Hayashida grime-warmth as texture, never cosplay.
This plan ships rungs 1–2 (front door + navigable docs) and plants the
flavor layer; rungs 3–7 are horizon, not this plan.

## Steps

- [x] 1. README front-door pass. Rewrite the root README's opening
      screen: two-sentence identity (what hngh is, including the live
      automation tier and omp direction), truthful status block,
      navigation table that mirrors docs/README.md's read-order, the
      dry voice per the direction doc's binding rules. Keep every
      existing factual claim; change register and structure, not
      truth. No badges except ones generated from real repo state.
      Verification: relative-link checker passes on README (the
      ceremony enforces this); a read-through shows zero marketing
      register; `make test` green.
- [x] 2. Docs spine promotion. Make the navigable path the entry
      point: docs/README.md read-order gains a visual structure
      (sections: Start here / How it governs itself / The live machine
      / Records and history), each entry one descriptive line, every
      listed doc cross-linked both ways where sensible. Promote
      docs/publication/book.md to a linked "the long-form record"
      entry.
      Verification: link checker over docs/ passes (zero
      broken relative links); the read-order reaches every anchor
      record from 2026-09-09 within two hops; `make test` green.
- [x] 3. Flavor layer, guarded. Add the texture layer: short
      epigraphs (Nihei-architecture register) at the heads of the
      major docs (README, docs/README, architecture.md, the plans
      contract), and dry asides in section spines where the material
      earns them. Budget: one epigraph or aside per document, no
      more. Sweep for marketing register and emoji in all public
      docs; delete on sight.
      Verification: grep for exclamation marks and emoji in docs/*.md,
      README.md, CHANGELOG.md returns zero (code comments exempt); the
      voice reads as one author; `make test` green.
- [x] 4. Publication spine surfacing. Extend
      scripts/generate-publication's ebook mode to include the 2026-09-09
      records and the presentation direction doc in the spine, and
      regenerate docs/publication/book.md + EPUB.
      Verification: the generated book lists the new records; --check
      passes against the real git/timeline records.
- [x] 5. Records: CHANGELOG entry for the presentation pass, and a
      docs/records/ entry recording the direction adoption (linking
      docs/design/presentation-direction.md).
      Verification: `make test` green; record cross-linked from
      CHANGELOG.

## Execution notes

- The direction doc is the arbiter of voice; if a step's output reads
  like a product launch, it fails its own verification.
- Rung 3+ (dashboard character, node-graph navigator, WebGL
  environmental surface, hot-swap GUI wrapper, the CachyOS-based
  distribution) are recorded ambitions in
  docs/design/presentation-direction.md — future plans pick them up;
  this plan does not attempt them.
- All slices are docs/publication surfaces: normal risk, no kernel
  changes, fail-first queue applies.
- BLOCKED 2026-09-13T04:55Z, step 5 staged but not committed: the
  `make test` gate is red for a cause outside this step. A machine
  rehearsal-lane session (2026-09-13 ~00:00-00:05,
  ses_f6712c054ffe92sjP3sN6CSXvc, see the overnight rehearsal-log) ran
  probe commits directly in the real repo (ba6b390 'fixture' deleting
  the Makefile/README, d2d8f51 the revert, e7dbaaa the agent-stall
  close, all authored as Fixture <fixture@example.invalid>). The
  loop-history guard correctly refuses them: "every code-surface commit
  must be 'hngh: candidate <hash>' or a labeled rule-based exemption".
  The refusal pre-dates this session (16-remote-push push-refused rows
  53942/53957/53971 in automation STATE.md at 04:04-04:05). The cure
  named by the guard is a labeled exemption declaration in
  tests/scripts/test-loop-history-guard.py (wake-mutation lane, not
  this plan). Step-5 artifacts staged in the working tree:
  docs/records/2026-09-13-presentation-pass-1-adoption.md,
  CHANGELOG.md 2026-09-13 section. A later wake-mutation session
  declares the exemption through the ceremony; then this plan's last
  step commits under a green gate.
- Re-verified 2026-09-13T07:10Z (step-5 session): the gate is red on
  exactly two commits -- ba6b390 (patch-id
  a46ed8ae5a64949d7e5dbe8917902e125586d5d3) and d2d8f51 (patch-id
  cef31fa5a3ea871522e0a3ea3e537088c9a8952b), both authored as Fixture;
  e7dbaaa is docs-only and never trips the guard. `make test` fails
  only at test-loop-history-guard.py; all upstream suites green.
  The ceremony was walked to its wall: propose admitted 10/10
  principles on the step-5 evidence, issue-cert refused with
  "candidate evidence failed" because verify-candidate.py runs
  `make test` -- the gate verdict itself, working as designed. No
  exemption entry exists in test-loop-history-guard.py KNOWN_EXEMPTIONS
  for the fixture pair; the cure (declare both patch-ids there,
  wake-mutation lane, kernel tests/ surface -- forbidden to this
  session) is unchanged and now carries the exact patch-ids needed.
  Step-5 artifacts remain in the working tree, unmodified.
- Re-verified 2026-09-13T10:05Z (step-5 session, third check): state
  unchanged. The gate is still red on exactly ba6b390 + d2d8f51
  (patch-ids a46ed8ae5a64949d7e5dbe8917902e125586d5d3 /
  cef31fa5a3ea871522e0a3ea3e537088c9a8952b); no KNOWN_EXEMPTIONS entry
  for the fixture pair exists yet; the wake-mutation lane is still the
  named cure and kernel tests/ remains forbidden to plan sessions.
  Step-5 artifacts (docs/records/2026-09-13-presentation-pass-1-adoption.md,
  CHANGELOG.md 2026-09-13 section) remain staged in the working tree,
  unmodified. No further plan session should re-run this check until a
  wake-mutation session lands the exemption: the handoff row at 07:15Z
  and this note carry everything needed.
- Fourth check 2026-09-13T13:00Z (step-5 session, no gate re-run): a
  grep over tests/scripts/test-loop-history-guard.py confirms neither
  fixture patch-id (a46ed8ae... / cef31fa5...)
  has a KNOWN_EXEMPTIONS entry yet. The wake-mutation lane remains the
  sole named cure; step 5 stays held. Working tree also carries many
  unrelated modified files from parallel automation lanes -- plan
  sessions should not stage or commit anything beyond the two step-5
  artifacts when the exemption lands.
- Fifth check 2026-09-13T18:40Z (step-5 session, dream-brief bounded
  verify-first): the exemption HAS landed -- both fixture patch-ids
  (a46ed8ae5a64949d7e5dbe8917902e125586d5d3 /
  cef31fa5a3ea871522e0a3ea3e537088c9a8952b) are in KNOWN_EXEMPTIONS at
  tests/scripts/test-loop-history-guard.py:122,126, and the guard now
  reports 105 commits / 10 exemptions / 0 violations (this supersedes
  the 13:00Z note). But `make test` is still red on a NEW cause: the
  userspace-home lane's in-flight test-first slice --
  tests/scripts/test-generate-publication.py (working-tree, mtime
  14:36Z) has test_telemetry_reads_hngh_home expecting telemetry via
  HNGH_HOME_DIR (~/.hngh/db/telemetry.db, 2026-09-13 userspace-home
  directive), while scripts/generate-publication at HEAD (line 140)
  still reads automation/dashboard/telemetry.db; the lane's
  implementation has not landed (no userspace-home plan file exists
  yet; staged automation/lib/hngh_home.py + staged record are its
  artifacts). Cure: the userspace-home lane lands its
  generate-publication HNGH_HOME_DIR implementation through its own
  certificate ceremony; then this plan's step 5 commits the two
  already-authored artifacts (staged CHANGELOG.md 2026-09-13 section,
  untracked docs/records/2026-09-13-presentation-pass-1-adoption.md,
  both intact and cross-linked, verified 18:40Z) under a green gate,
  staging exactly those two files. Kernel scripts/ and tests/ remain
  forbidden to plan sessions; no further step-5 session should re-run
  the gate until the userspace-home slice lands.

- LANDS 2026-09-13T21:12Z (step-5 session, final): both blockers had
  cleared in the working tree per the 18:40Z note's terms -- the
  userspace-home GNGH_HOME_DIR implementation had landed at HEAD
  (committed via ceremony fd4ccbd/6bb8e66; CHANGELOG 2026-09-13
  section including the step-5 entry landed with it, cross-linked to
  this record), and the loop-history-guard exemptions were in (guard:
  108 commits / 12 exemptions / 0 violations). `make test` re-verified
  green (rc=0) before and after the commit. Both former test-first-red
  suites pass standalone. The ceremony ran through
  scripts/ceremony-drive with all 10 principles passing twice
  (commit + push legs): docs/records/2026-09-13-presentation-pass-1-adoption.md
  committed as 4b28c58 (hngh: candidate 054fff154a16f93f...) and
  pushed to origin. Plan complete (steps 1-5 all checked).
