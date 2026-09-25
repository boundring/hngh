# Foundation consolidation: doctrine layer, constitutional preamble, planned-work trim

Date: 2026-09-24. Tier: docs + planning (free lane). Plan:
foundation-consolidation (operator-approved 2026-09-24).

## The operator ask

"Further consolidation and streamlining for Hngh's documentation, roadmap,
designs, research, and all currently planned work. We're looking to trim and
consolidate any parts that aren't closely aligned with clean architecture,
the US federal government structure, and our annotated chinese classics. Our
pantheon of English authors and their commentary on Taoism and Confucian
thought, they could and should have more influence on the structure and
functionality of Hngh, its self-governance as a system harness (with
interpretation for meaningful findings). Our purpose is settling Hngh's
foundation as thoroughly as possible before we continue our work on the
megastructure it supports."

## The four scope decisions (plan-mode asks, 2026-09-24)

1. Disposition: ARCHIVE + STRIKE. Misaligned current-surface docs fold into
   an archived section; planned-work rows struck with one-line dated causes.
   Nothing deleted from history (git history + records stay the evidence).
2. Scope: DOCS + PLANNING layer now. Kernel self-governance machinery
   changes become named follow-up certified slices, not edits here.
3. Classics influence: DOCTRINE LAYER + STRUCTURAL MAPPING - new
   docs/design/interpretation-doctrine.md, with the federal structural model
   and the clean-architecture dependency rule mapped onto the canon.
4. Authority level: TOWARD A CONSTITUTIONAL PREAMBLE. Canon ethos gains
   preamble-level normative weight at the named interpretive seams;
   placement keeps GOVERNANCE.md sections 1 and 5 verbatim, so the preamble
   is an ordinary section-11 governance change (DCO, 7-day review), NOT an
   N=2 amendment.

## Why a preamble, and how it lands

GOVERNANCE.md is the alignment document: it states recorded decisions and
creates none (decisions.md:694-723). So the operator directive lands FIRST
as a decisions.md entry; GOVERNANCE.md's preamble then catches up, citing
it. The governance commit carries a DCO sign-off
(`Signed-off-by: boundring <boundring@gmail.com>`) and rides the free lane -
the fixed ceremony candidate message cannot carry a DCO trailer, and root
docs have always been free-tier.

The preamble's three boundary sentences (checked together, they hold):
(a) interpretation binds only at the named seams (findings reading, office
vocabulary, structural mapping); (b) the external corpus stays "provenance
of voice and principle only - never law" (GOVERNANCE.md:339-341 - the
preamble is law, the external texts are its cited provenance); (c) no voice
is endorsed - the corpus's own disclaimer ("simulated voices ... the forge,
not the artifact") travels with every citation; the METHOD binds, no voice
does. The closed principle matrix and the certificate path stay mechanical:
interpretation shapes how findings and offices are read, never whether a
mutation is admitted.

## Part 1 - doctrine layer and preamble (landed)

- docs/design/interpretation-doctrine.md (NEW): purpose (interpretation for
  meaningful findings; the mechanical core untouched), the interpretive
  register (six annotated classics + the seventeen-voice pantheon, carrying
  the corpus disclaimer verbatim: "These are simulated voices ... This file
  is the forge, not the artifact"), three named seams (findings reading =
  supportive + adversarial dual pass with convergent synthesis; disagreement
  escalates, never averages; office vocabulary = rectification of names;
  structural mapping), the five-row structural table (Judicial/Legislative/
  Executive/Checks/Federalism x repo component x clean-arch layer x canon
  concept x pantheon use), the NEVER list (interpretation never admits or
  refuses a mutation, overrides a refusal, creates authority, or enters the
  evidence ledger as proof), and the provenance rule (every interpretive
  claim cites a canon unit id or a voice slug).
- The flavor/lexicon docs all mapped - none folded: descent.md (Great
  Learning sequence), bestiary.md (rectification of names applied to
  failure classes), display-register-spec.md (pantheon register discipline),
  writing-register.md (the pantheon's voice bibles as prose law),
  operator-mirror.md (sincerity as correspondence), operating-precepts.md
  ("cooking small fish" as growth policy).
- GOVERNANCE.md: one unnumbered preamble block, 17 lines, inserted after the
  status block before section 1; sections 1-13 byte-identical (git diff:
  1 file changed, 17 insertions(+), 0 deletions(-)). The preamble cites the
  decisions.md 2026-09-24 entry; the entry precedes it (documents catch up
  to records).
- Canon citations in the doctrine use section names, not line numbers (the
  preamble insertion shifts every GOVERNANCE.md line number past 13 - line
  pins would have been stale on landing).

## Front door and CURRENT-surface trim (landed)

- Front door: docs/README.md "How it governs itself" gains the doctrine
  link; the map's repo-merge framing now cites decisions.md:420 ("the P0
  merge is recorded done ... git subtree --squash, 222 files"); the
  HISTORICAL section routes timeline.md / checkin.md / active-work.md as
  point-in-time streams (live streams = reports.md + docs/records/).
  docs/intent.md gains a "What holds it together" subsection (federal
  branches + dependency law + canon ethos, all serving the master plan);
  docs/architecture.md links the charter(s) + doctrine;
  docs/architecture-index.md gains a "Foundation frame" section with
  master-plan.md and interpretation-doctrine.md rows.
- Trim causes landed in place (nothing deleted): repo-merge contradiction
  (clean-reorientation.md, repo-merge-consideration.md superseded by
  decisions.md:420); gate-inventory.md rows 23-25 struck with their exact
  causes (the row-24 note also fixes queue.md's scheduling note to "the
  cadence owns the clock"); hngh-minimal-core-spec.md's self-declared
  false claim struck; governed-fleet.md's stale stage-7 line superseded by
  roadmap.md:25-33; fail-first.md "implemented (lib/failfirst.sh)";
  interface-plan.md "superseded by command-center.md (M1-M7/S1-S7
  duplicated)"; the six point-in-time docs (timeline, checkin, active-work,
  session-notes-2026-08-27, self-funding-scan-2026-08-25,
  market-scope-2026-08-25) carry "point-in-time record; the live streams
  are reports.md + docs/records/"; refactor-assessment.md +
  pivot-synthesis.md "superseded by research-lifecycle-audit.md" (2026-09-16
  audit numbers, one home).
- Path corrections vs the plan's guesses (recorded): interface-plan.md
  lives in docs/project/ (not docs/design/); refactor-assessment.md and
  pivot-synthesis.md live in docs/design/consider/.

## Verification

1. Structure: `git diff GOVERNANCE.md` = 1 file, 17 insertions, 0
   deletions - the preamble block only, before section 1; sections 1-13
   byte-identical. The commit carries the DCO sign-off trailer
   (`Signed-off-by: boundring <boundring@gmail.com>`); the fixed ceremony
   candidate message cannot carry one, so the governance change rides the
   free lane by design (decisions.md 2026-09-23 execution pattern).
2. Cross-links and paths: relative-link check across the doctrine, the
   front-door docs, and the trim targets = broken relative links: NONE;
   `python3 automation/scripts/lint-home-paths.py` = "lint-home-paths:
   clean".
3. Mapping-table grounding (3 spot-checks, all grounded): "words answer to
   things" (Doctrine of the Mean, sincerity as correspondence) at
   GOVERNANCE.md:162; "Governing a great state is like cooking small fish"
   (Tao Te Ching ch. 60) at GOVERNANCE.md:99; the mirror mind "responds but
   does not retain" (Chuang Tzu) at GOVERNANCE.md:268-269 (line-wrapped -
   a single-line grep misses it). Voice slugs orwell/leonard/adams all
   exist in voices/pantheon.md (13 hits).
4. Preamble coherence: the three boundary sentences (interpretation binds
   at named seams / the corpus is provenance, never direct law / no voice
   is endorsed) were read as a set and hold together; the "Meaning is read;
   the evaluator decides." close of the doctrine's NEVER section is the
   same claim in one line.

## Planned-work reshape (landed)

- queue.md: the TSV region is byte-identical to HEAD (33 lines = header +
  32 rows; 16 done / 16 queued on disk - the plan's 15/17 was a stale scout
  count); 2 rows struck in a new "Struck rows (2026-09-24)" section
  (self-funding-plan, ebook-book-inputs, exact misaligned cause); 16 done
  rows' prose folded to one line each under "Completed rotations (folded
  2026-09-24)"; the scheduling note now reads "The cadence owns the clock".
- backlog.md: 23 duplicate-pair sections struck ("absorbed by queue row
  <id>, 2026-09-24"), 9 misaligned strikes (content/commercial, social, and
  OSS lanes), 3 COMPLETED sections folded ("completed; history in git +
  records (folded 2026-09-24)"), and the vault stale-prose paragraph folded
  to a one-line State bullet (the 92-pages-vs-registry note carried). 5 new
  follow-up rows landed: Router re-route policy, Adopted-disposition
  adoption wire, Cadence-tier collapse, Write-only artifact classes,
  Interpretation seam for findings. Structure: 85 section headers preserved
  + 5 = 90; the admission rule at :3-9 is byte-intact.
- roadmap.md: social-surfaces policy + OSS contribution policy struck
  (:80-81, exact cause). master-plan.md: Immediate-next-actions item 1
  struck as landed (:138).
- charter.md does not exist in-tree (the rider lives only in docs/records/
  2026-09-22-wiki-boundary-verdict.md:36-40,56-57); no stub was created -
  the rider is absorbed into the doctrine's structural mapping, so there is
  no file to strike (recorded deviation, operator-decided mid-slice).
- 3 of the 4 stale-prose fold targets (backlog.md:294 doc-sync "queued
  2026-08-25", :1734-1735 "Risk: low - deferred", :1791-1792 review
  trigger) live inside sections struck whole - each fold is carried
  verbatim inside its section's strike line.

5. Disposition proof: cause-string counts on disk = 23 absorbed / 13
   no-aligned-purpose (9 backlog + 2 queue + 2 roadmap) / 3 completed
   folds / 1 master-plan landed strike; no planned-work row disappeared
   without a strike note; the queue TSV carries all 32 rows' state.

## Landing shape

Two free-lane docs commits (GOVERNANCE.md is docs tier and the fixed
ceremony candidate message cannot carry a DCO trailer): (1) "docs:
foundation consolidation - doctrine layer and constitutional preamble" =
Part 1 + Step D + all docs/README.md edits; (2) "docs: foundation
consolidation - trim and planned-work reshape" = Steps E/F + this record +
CHANGELOG.md. Both carry the `Signed-off-by: boundring
<boundring@gmail.com>` trailer. Machine-cadence churn lands first as its
own ledger-sync commit.
