# Publications pipeline --site increment (2026-09-03)

Scope: run `scripts/generate-publication --site` (automation repo) with
`HNGH_PUB_ROOT` at a throwaway temp dir; record what it consumed and the
gap inventory versus the backlog public-surface row
(docs/project/backlog.md:510-528). Build artifacts are never committed;
the temp root was discarded after inventory.

## What the run consumed (grounded)

Command (from /home/bricker/Projects/etc/hngh/automation):

    HNGH_PUB_ROOT=/tmp/hngh-pub-QxQU scripts/generate-publication --site
    -> site index -> /tmp/hngh-pub-QxQU/docs/site/index.html  (exit 0)

Output: one file, `docs/site/index.html`, 27,378 bytes, 7 `<section>`
blocks. No "skipping missing" warnings: all 7 hard-coded sources
existed.

Sources consumed (the script's hard-coded 7-file list):

1. docs/research/2026-09-01-session-cost-model.md (3,676 chars rendered)
2. docs/research/2026-09-01-notification-channel-survey.md (3,538)
3. docs/research/2026-09-01-local-model-benchmark-loop.md (2,699)
4. docs/research/2026-09-01-arbitrary-request-scheduling.md (3,365)
5. docs/research/2026-09-01-roguelike-pattern-design.md (3,464)
6. research-lines.tsv (38 rows; 6,390 chars rendered)
7. research-subjects.txt (3,550 chars rendered)

## Gap inventory versus the research-lines surface / public-surface row

The backlog row's smallest useful outcome is a static+tiny-server site
with four surfaces: journal posts (from journal-daily), a moderated
comment intake, a public readout of the Hngh queue (dashboard), and a
leaderboard-like "instances" page, self-hosted on a budget VPS; review
acceptance = journal + readout served from committed data, moderated
intake, no Hngh store exposed.

The --site output today delivers none of the four surfaces:

1. **Journal posts: absent.** Nothing from journal-daily is consumed;
   no journal source exists in the script's file list.
2. **Moderated comment intake: absent.** Pure static single file; no
   server, no intake path, no moderation, no rate-limits.
3. **Dashboard/queue readout: absent.** No queue data source consumed.
4. **Instances/leaderboard page: absent.**
5. **Hosting: absent.** One flat index.html; no deploy path, no server,
   no budget-scaled hosting plan.
6. **Secrets: none exposed (the one row requirement met)** — sources
   are the public research lines only; the hard-coded list is the sole
   guard keeping internal docs out.

Corpus/rendering gaps before the research-lines surface itself is
publishable:

7. **The hard-coded 7-file list already lags the corpus.**
   docs/research/ holds 7 files; 2 are not consumed:
   2026-09-02-biographic-cadence-design.md and
   2026-09-07-identifier-lint-design.md. The script docstring's claim
   that the list "IS the docs/research/ corpus" is already false; the
   list must become derived (glob) or the corpus grows silent.
8. **Manifests render raw.** research-lines.tsv rows render as
   tab-separated paragraphs (id\tstatus\ttimestamp\tdescription
   verbatim); no table, no TOC, no per-doc navigation, no dates in the
   chrome, one undifferentiated page.
9. **Flat heading hierarchy.** Docs' internal `##` headings (e.g.
   "Scope", "Sources") render as site-level h2 siblings of the doc
   titles; a reader cannot tell document boundaries from section
   boundaries.

## Verdict

The --site increment works: deterministic, exit 0, read-only over
sources, artifacts land only under HNGH_PUB_ROOT. It is a working
first artifact for the self-funding publication lane — but it is
roughly 0/4 of the public-surface row's smallest useful outcome. The
cheap next increments, in order: (a) derive the file list from a
docs/research/ glob so the corpus stops lagging, (b) render the TSV
manifest as a table with a TOC, (c) add the journal-daily feed as a
fourth source class. Moderated intake, readout, hosting, and
rate-limits are the larger, separately-priced public-surface work and
stay behind that backlog row's dependencies.

Artifacts: /tmp/hngh-pub-QxQU (throwaway; never committed). `git
status` in the automation repo shows no publication artifacts.
