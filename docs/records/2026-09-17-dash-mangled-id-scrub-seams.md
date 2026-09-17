# Dash-mangled id scrub seams: one stem mechanism for the research id derivation paths

- date: 2026-09-17
- lane: free-commit (automation only; no kernel src/tests/Makefile/hngh.asd)
- gate: wiki-health-wiring-reconcile (adversarial audit)
- status: landed

## The gap

The research id-derivation seams scrub with redact_home ONLY, and
redact_home's token family (automation/lib/scrub.py PATH_TOKEN_RE)
matches slash forms (`/home/...`, `~/...`) but not dash-mangled pathy
fragments (`home-bricker-Projects-e`). A slug arriving pre-mangled
passed redact_home unchanged and baked the deployment username into
the public `fail-<date>-<slug>` id. At assignment, HEAD carried the
leaked stems: research-lines.tsv:131,158,187; research-subjects.txt
:149,185; research-dispositions.tsv:136,160,161,169,194,197 (id stems
`home-bricker`); the leak shape was already named in the
accept-plans.py:197-217 and causes.sh:100-140 seam comments while both
still scrubbed only via redact_home. router-tick solved this class
(GAP E, 6762dcfa + d5f7dc0d) with PATHY_STEMS +
HNGH_ROUTER_PATHY_STEMS, but the research seams had no equivalent.

## The cure: single-source stem family in lib/scrub.py

One mechanism, not a second copy:

- `lib/scrub.py` gains `PATHY_STEMS = ("home", "users", "tmp",
  "root")`, `pathy_stems()` (PATHY_STEMS + comma/space-separated
  HNGH_ROUTER_PATHY_STEMS env stems, env first, case-insensitive; the
  deployment username stays config data, never hardcoded), and
  `scrub_truncate_pathy()`: cut dash-form path-derived text at its
  first pathy-stemmed dash token; "" means the whole input is
  path-derived and the caller refuses (fail closed). Tokens are
  maximal `[\w-]` runs so the cut works on pure slugs and on sentence
  text embedding a pre-mangled fragment; a token directly preceded by
  `~` is the redaction marker itself and is never re-cut.
- `scripts/router-tick.py` re-points to the same module (binds
  PATHY_STEMS/pathy_stems/scrub_truncate_pathy instead of redefining
  the family; its PATH_COMPONENTS heuristic stays router-local). The
  dash-form family is now one definition with one env seam.
- `lib/scrub.sh` exposes `scrub_truncate` for shell seams (same
  fail-closed empty-on-breakage contract as the other wrappers).

Documented tradeoff, matching router-tick's: truncation is lossy by
design. False positives only truncate a subject word; false negatives
would leak. Stem matching is exact-segment (a plain "homework" or
"hermituserish" word passes; a bare stem word dies).

## Seams wired

1. `lib/causes.sh append_research_subject`: after redact_home, both
   question and slug run scrub_truncate; empty -> refuse (return 1),
   never a username-bearing id.
2. `scripts/accept-plans.py append_research_subject`: the python
   mirror applies `_SCRUB.scrub_truncate_pathy` after redact_home;
   empty (or scrub exception) -> refuse the append.
3. `cadence/hour/33-research-beat.sh` slug-cut paths:
   `followon_queue` truncates the question before the slug cut
   (discard on empty); `ensure_lines`' tab-less branch truncates the
   line before the derived id (discard on empty). Explicit-id rows are
   unchanged by design (the id is caller-chosen, the text column is
   still redact_home-guarded).

Red-first: tests/test-scrub-module.py (new PathyStems group),
tests/test-causes.py, tests/test-plan-acceptance.py, and
tests/test-research-beat-ingest-redact.sh (cases e/e2/f) all failed
against the pre-fix seams reproducing the exact audited leak shape
(`fail-20260917-Where-exactly-in-home-bricker-Projects-e` emitted
verbatim), then went green after the cure. Full
`cd automation && make test` green + lint-identifiers clean.

## Enforcement hardening

tests/test-scrub-module.py existed since the 2026-09-16 consolidation
but was never wired into the automation Makefile. Now in `make test`.

## Forward-only note

The already-committed rows with `home-bricker` id stems (research
TSVs, plus the docs/research filenames derived from them) are
historical artifacts of the pre-fix seams; redact_home-based
back-redaction cannot fix dash-form ids (that is the gap this slice
closes). Renaming committed history rows and their derived wiki/
research files is a separate decision for the operator lane; nothing
in this slice rewrites research data.
