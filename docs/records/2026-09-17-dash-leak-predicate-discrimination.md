# Dash-leak predicate discrimination: stem-then-path-shape + two-phase sweep gate

Date: 2026-09-17. Lane: machine session, automation free-commit + docs.
Supersedes part of
`docs/records/2026-09-17-dash-mangled-id-scrub-seams.md` (the bare-stem
cut and its documented false-positive tradeoff); the seam single-source
mechanism and the env username stem carry forward unchanged.

## The gap

The proposed sweep gate predicate "redact_home delta OR
scrub_truncate_pathy delta" is empirically unusable on real repo
content. Measured over the sweep's own domain (the four research TSVs
plus tracked `docs/research/*.md`, 278 files at measurement time):

- 291 lines flagged; every single one a `scrub_truncate_pathy` delta.
  The `redact_home` fixpoint component contributed ZERO findings: the
  live tree is already at the tilde fixpoint.
- The bare-stem cut fires on any dash token CONTAINING a stem segment,
  so ordinary English prose dies: "root cause: the network-down
  headroom predicate" -> "root cause: the" (`home` inside `headroom`),
  "use tmp dir" -> "use", "users table grows" -> "", and seven whole
  lines die to empty string on a leading "Users ..." sentence
  (docs/research/2026-08-28-logs-known-good-patterns.md:110).
- As speced, --check goes permanently red on the live tree (gate
  useless, merge blocked) or --apply mass-destroys ~291 committed
  research lines (lossy rewrites of correct root-cause dispositions).

The prior record's soundness argument only ever touched synthetic
negative controls ("Which-gate-eats-rc", tilde rows); it never ran the
predicate over real repo content. This node did.

## Candidate discrimination (measured, not argued)

Candidates evaluated against three hard requirements: catch all three
real committed payload ids
(`fail-20260914-Where-exactly-in-home-bricker-Projects-e`,
`fail-20260916-Do-any-files-in-home-bricker-Projects-et`,
`fail-20260915-Does-the-file-structure-at-home-bricker-`), zero corpus
false positives, survive the known prose false-positive classes.

- Router-symmetric two-consecutive PATH_COMPONENTS: MISSES ALL THREE
  payloads (none carries a component pair) and still flags 29 corpus
  lines including `/hngh-docs` prose. Rejected.
- Stem + stems|components|Capitalized successor: catches the payloads
  but Capitalized adds a false positive (`ROOT-CAUSE` in
  research-lessons.tsv:24). Rejected as wider than needed.
- Stem + stems|username successor only: 18 corpus lines, all genuine
  payload carriers; equal to the username-only rule as a set. Sound on
  this corpus but blind to capitalized path components on future data.
- ADOPTED: stem + path-shaped successor, where path-shaped = another
  stem, the deployment username, or a PATHY_COMPONENTS vocabulary
  (mirroring router-tick's PATH_COMPONENTS grammar data):
  projects/etc/hngh/dropbox/documents/downloads/desktop/config/src/
  lib/bin/docs/tests/opt/usr/var. On the real corpus this equals the
  narrow rule (no Capitalized-only hits exist) while admitting the
  `home-<user>-Projects`/`home-<user>-Dropbox` shapes on future data.

Key empirical fact: every real payload id embeds the username
(`home-bricker-...`); the username reaches the predicate through
`HNGH_ROUTER_PATHY_STEMS` (env first, then the committed config.env
default via the same bash-default parse email-digest.py uses, so the
env-less `make test` gate still sees the deployment stem).

## Two-phase check/apply semantics

The dash-form finding class is inherently lossy to rewrite: the
payloads ARE committed research line ids. Rewriting them destroys the
research record. Therefore:

- ACTIONABLE (gates rc, --apply rewrites): redact_home delta only --
  a raw slash-form machine-local token. Already-tilde rows are clean
  by the fixpoint; preserved URLs unchanged.
- REPORT-ONLY (parks for the operator, never gates rc, never
  rewritten): scrub_truncate_pathy delta, printed as
  "N dash-form finding(s) (report-only, parked for the operator)".

## Enforcement

- automation/tests/test-scrub-module.py PathyStems: positive controls
  are the three real payload ids with the expected cut points;
  negative controls are the measured prose classes (bare "root cause:",
  "use tmp dir", "users table", "root-cause-analysis-of-leaks",
  "Users"-leading prose, "/hngh-docs" prose) plus the discriminating
  core (leading stem without path-shaped successor survives;
  stem-then-username refuses whole input) and the component/seam
  vocabulary.
- automation/tests/test-research-tsv-path-sweep.sh section (g): dash-
  only row parks with rc=0; tilde row is the actionable rc=1; --apply
  rewrites the tilde row and leaves the committed dash-only id
  verbatim; parked report persists on re-check; payload-with-raw-token
  row is red while prose-FP rows stay silent.

## Results on the real tree (post-change)

- Sweep domain: 279 files, --check rc=0 (gate green), 18 dash-form
  findings parked, all 18 genuine `home-bricker` payload carriers,
  zero actionable findings.
- Full-repo scrub_truncate_pathy delta audit: 108 lines, all
  stem-then-path-shaped true positives (103 username-bearing
  `home-bricker-...` ids in changelogs/reports/records, literal
  `home-root` path sequences, `root-config` dashboard identities that
  correctly park), zero prose false positives.
- Residual false negatives: none known on the payload class; a
  mangler that drops BOTH the stem and the path-shaped successor
  (e.g. a bare mangled username with no adjacent path segment) remains
  outside this predicate by design -- the router identity grammar and
  the operator park lane are the remaining nets.
