# 2026-09-18 — Tracked-dash-form slug leak population: remediation plan

Plan: docs/project/plans/2026-09-18-backlog-p0-security-fixes.plan.md
step 7, backlog item gap-slug-tracked-remediation-plan. Doc-only; no
code change in this slice (the fixes themselves landed in prior
slices, cited per family below). Purpose: pin the remediation plan for
the tracked population of dash-mangled credential-shaped ids — the
rows and filenames already committed before the scrub seams existed.

Backlog lineage: "slug family findings" — the population census comes
from docs/records/2026-09-17-dash-mangled-id-scrub-seams.md
(id stems `home-bricker` in research TSVs) plus the accept-plans.py
seam-gap census it cites.

## The 3 id families

1. `fail-<date>-<slug>` — the research/finding subject id. Mint sites
   (all now guarded): `automation/scripts/accept-plans.py:240`,
   `automation/scripts/router-tick.py:431`,
   `automation/lib/causes.sh:134`,
   `automation/cadence/hour/33-research-beat.sh:618`.
   Leak shape: pre-mangled dash-form fragments
   (`fail-20260917-Where-exactly-in-home-bricker-Projects-e`)
   baked the deployment username into a public id.
2. `dev-<slug>` — synthesized development plans minted from adopted
   research subjects (`automation/scripts/overnight-cycle.sh`
   `synthesize_dev_plan`, slug derived at :474 from the research
   ingest). Leak shape identical: unredacted adopted-question text
   minted a `dev-...pathy...` plan slug (and filename). Guarded by
   plan step 3 (redact_home + scrub_truncate at :469-471).
3. Alert-identity slugs — `patrol-<day>-<patrol>-<cause>` rids
   (`automation/jobs/patrol.py queue_repeat_subjects`,
   exposure NIL) and `review-finding:<date>:<slug>` /
   `slugify` alert identities
   (`automation/cadence/day/06-review-disposition.sh`,
   `automation/cadence/day/19-ux-review.sh`). Cured per plan step 4
   (gap-slug-residual-mints): all three mint inputs run the
   redact+scrub seam before the id is composed.

## The 6 tracked surfaces (historical rows, remediation target)

The committed, still-trackable artifacts of the pre-fix seams:

1. `automation/research-lines.tsv` — id-column stems `home-bricker`
   (recorded at :131, :158, :187 in the 2026-09-17 census).
2. `automation/research-subjects.txt` — same leak shape (:149, :185).
3. `automation/research-dispositions.tsv` — densest surface (:136,
   :160, :161, :169, :194, :197).
4. `docs/research/` — filenames derived from the research ids above
   (the dash-mangled stems ride into the doc paths).
5. `docs/project/plans/` — dev- family plan filenames minted from
   pathy adopted-question slugs (the gap this family's cure now
   blocks from recurrence).
6. `automation/STATE.md` breadcrumb rows + journal records — history
   rows that quote the leak-shaped ids as receipts.

## Remediation plan

- Recurrence: DONE. Every mint site in the three families is now
  fail-closed at the source (single-source guard, lib/scrub.py
  PATHY_STEMS + HNGH_ROUTER_PATHY_STEMS env seam; redact_home then
  scrub_truncate(_pathy), empty-output refusal). Contract tests:
  tests/test-scrub-module.py, tests/test-causes.py,
  tests/test-plan-acceptance.py, tests/test-research-beat-ingest-redact.sh,
  tests/test-dev-plan-synth.sh, tests/test-slug-mint-residual.py.
- Historic rows: FORWARD-ONLY by recorded precedent
  (docs/records/2026-09-17-dash-mangled-id-scrub-seams.md
  "Forward-only note"; docs/records/2026-09-17-routed-plan-slug-census-definition.md
  waiver reasoning: redact_home-based back-redaction cannot fix
  dash-form ids, and renaming committed history rows is a history
  rewrite in spirit). No automated back-redaction of the six
  surfaces in this lane.
- Operator lane handoff: the only defensible cure for the tracked
  population is an operator-side one-time rewrite (row rename +
  derived filename rename + reference repair across
  research-surfaces, docs/research filenames, plans feed references),
  deliberately OUT of machine free-commit scope because it rewrites
  kernel-adjacent research data and public plan filenames. If the
  operator wants it, the prerequisite (this census, plus the pinned
  pathy definition) is now in the records.
- Verification posture: repo-root `make test` green at the time of
  writing; the recurrence guard is test-pinned on all three families.

Related: docs/records/2026-09-17-dash-mangled-id-scrub-seams.md,
docs/records/2026-09-17-dash-leak-predicate-discrimination.md,
docs/records/2026-09-18-1password-item-metadata-backfill.md (step-5
sibling record).
