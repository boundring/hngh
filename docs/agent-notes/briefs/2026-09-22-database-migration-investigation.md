# Database migration investigation — hngh plaintext journals (2026-09-22)

Status: investigation complete; advisory pending operator review.
Method: three read-only scouts over the live repo (SurfaceInventory hi-effort,
ConsumerCoupling, PrecedentScan; 8–18 min each). Raw payloads:
`agent://SurfaceInventory`, `agent://ConsumerCoupling`, `agent://PrecedentScan`
(transcripts `history://<name>`).

## Question

Operator framing (2026-09-22): some docs make sense inside the repo, but the
project is approaching the point of needing a database with an appropriate
schema instead of the docs used as journals; most problems with loose docs
would benefit from a standardized schema and database — investigate
thoroughly, supportively and adversarially.

## Headline answer

Tiered hybrid, not a wholesale migration:

1. **Schema-first, storage-second.** The de-facto schemas already exist (TSV
   headers, crumb 4-field vocabulary, report-queue kinds, plan front-matter).
   Formalize them as tests before any row moves storage.
2. **New machine journals start in SQLite WAL** under `~/.hngh/db/` or
   `automation/state/` — the repo already runs `dashboard/telemetry.db`
   (sqlite WAL, additive-only) and beads/Dolt ("ledger of record") this way.
3. **Untracked high-churn journals are the natural first migration targets:**
   STATE.md (15.7MB, 140,639 crumbs), budget.md, agent-handoffs.md, stats/,
   deck-facts/, beat-blockers.tsv — zero git-evidence semantics, ~10+ grep
   consumers each, mtime heuristics map to `created_at`.
4. **Tracked public ledgers and ceremony evidence stay plaintext/git:**
   reports.md, research TSVs, plans, docs/records, decisions.md,
   kernel-slice-ledger.md. The evidence chain is git-blob-shaped end to end
   (candidate hash = sha256 over commit blobs; rehearse-gate = git archive
   HEAD; public-push redaction guarantee). Migrating them deletes the
   artifact the ceremony exists to keep.

## Inventory: ~20 plaintext data surfaces, tiered

### Tier 0 — never move (git-blob-shaped evidence)

| Surface | Why it must stay |
|---|---|
| `docs/project/plans/*.plan.md` | rehearse-gate runs gates against `git archive HEAD` (scripts/rehearse-gate.sh:52); accept-plans clobber check reads `git show HEAD:<plan>` (automation/scripts/accept-plans.py:120-140); plan-feed turns certificate commit messages into graph evidence edges (automation/jobs/plan-feed.py:66-70) |
| candidate hashes | mint hash = sha256(path+NUL+bytes+NUL) recomputed from commit blobs (scripts/verify-candidate.py:129-139; automation/jobs/patrol.py:630-728) — a DB-resident candidate cannot be overlaid or archived |
| `docs/records/`, decisions.md, registries/kernel-slice-ledger.md | "promise the machine made in public"; gate-sha/cert columns are hashes OF file content |
| `docs/journal/`, lessons-index.md | schema-free by design — journal README bans frontmatter; "a lesson without a path is a rumor" (hand-curated) |
| `docs/project/reports.md` + report-bodies/ | ledger rows are committed public evidence; prune needs git to distinguish tracked deletions (automation/cadence/day/02-ledger-prune.sh:49-51); ledger-vs-bodies drift check fails closed on unmeasurable skew (automation/jobs/dashboard-self-review.py:189-193); public-push redaction contract pinned both sides (automation/tests/test-report-queue-redaction.py) |

### Tier 1 — already DB (extend, don't migrate)

| Surface | State |
|---|---|
| `dashboard/telemetry.db` | sqlite WAL, additive-only schema discipline (automation/jobs/telemetry.py:4,42-45); ~14 read-only sqlite3 consumers across jobs/; model.sh quota gates query it via CLI |
| beads/Dolt | ledger of record for work; sync via `refs/dolt/data` on origin; `.beads/issues.jsonl` passive export; hooks wired repo-wide via core.hooksPath |
| `automation/ng/` judgment ledger | JSON events beads cannot hold (verdicts/escalations/spend); one-writer version bump (automation/ng/state_emitter.py:3-5) |

### Tier 2 — natural first migration targets (untracked machine journals)

| Surface | Size/format | Coupling cost to move |
|---|---|---|
| `automation/STATE.md` crumbs | 15.7MB, 140,639 lines, `ts / job / event / detail`, pinned single-line invariant (automation/tests/test-breadcrumb-single-line.py) | ~10 grep consumers (beat-watchdog, patrol, model.sh, operator-items-feed, bench-trigger); event vocabulary open-ended |
| `automation/logs/budget.md` | `ts slug class model source` rows (lib/launch-session.sh:514-515) | max-sessions greps (overnight-cycle.sh:104, patrol.py:584-598); bench-trigger uses file mtime as quiet-window signal — maps to `created_at` |
| `automation/agent-handoffs.md` | 418L pipe rows | respawn scan, watchdog thresholds, resume-pass tail-25 recovery |
| `automation/stats/*.jsonl`, deck-facts | versioned JSON payloads (`deck-facts/1` schema tag) | feed + bench consumers |
| `automation/state/beat-blockers.tsv`, model-demote.tsv | small 3-col TSVs | beat-watchdog + bench-trigger greps |

### Tier 3 — tracked public ledgers (migrate only with a replacement evidence story)

| Surface | Coupling that breaks |
|---|---|
| research TSVs (lines/dispositions/lessons/subjects) | patrol header-equality + lineage checks (patrol.py:482-538); redact-at-write seam asserted by Makefile:118-121 awk extract; path-sweep gate reads working-tree text and HEAD blobs; opencode.jsonc + MCP read them directly |
| `docs/project/reports.md` | 20 writer callsites through one engine (scripts/report-queue); sha256-of-redacted-text ids; sink-side redaction mirrors lib/scrub.py token family, pinned both sides; graph-data reads the tracked dashboard/ copy |
| cadence-params.tsv, config/*.tsv registries | grep/awk readers; patrol routes assertions; small enough that a DB buys nothing |

## Precedents already in the repo

1. **telemetry.db** — the working example of SQL-beside-git: WAL, additive-only
   schema, fail-open writes, read-only sqlite3 consumers. Extending it (or
   cloning its pattern) costs no new tooling decisions.
2. **beads/Dolt** — proves the hybrid this repo already likes: DB as source of
   truth, passive plaintext export for greppability, git-native versioning
   via `refs/dolt/data`. Dolt is literally a database with git semantics —
   if a public, versioned, schema-constrained research ledger is ever
   wanted, dolt is the in-repo precedent rather than a new architecture.
3. **`~/.hngh/db/`** — the 2026-09-13 layout contract already reserves a dir
   for local databases; userspace data home is never committed.
4. **Schema discipline exists today**: telemetry additive-only; deck-facts/1
   version tag; ng ledger-version bumps; dispositions pad-to-9 as de-facto
   migration shim; patrol header-equality as de-facto schema check.

## The supportive case

- Two SQL stores already operate; feeds already have `--json` and module
  import seams (report-queue --json; context-ratio imports report-queue).
- The weakest-coupled surfaces (Tier 2) are untracked — outside the git
  evidence chain already, so moving them cannot break ceremony semantics.
- STATE.md grep cost grows unboundedly (15.7MB, every cadence job greps it);
  indexed rows would be O(log n) reads and cheap retention windows.
- Loose-file problems observed this month map directly to DB constraints:
  TSV pad-to-9 legacy rows → column types; redact slip-through rows →
  CHECK constraints; header drift → real schema migrations instead of
  fail-closed aborts; duplicate identity windows → UNIQUE indexes.
- mtime heuristics (bench quiet-window, model-demote 24h window) become
  explicit `created_at` columns — more portable, more testable.

## The adversarial case

1. **Git-as-evidence is the core architecture.** Certificate-bound ceremony,
   candidate-hash reconciliation, rehearse-gate git-archive, public-push as
   a security property: these are not accidental file formats, they are the
   tamper-evidence layer. A DB row has no commit blob to hash.
2. **Churn governance would silently go quiet.** oversight-tick whitelists
   are path-regexes over worktree dirt; tree-skew detection and the hourly
   ledger-sync job exist *because* plaintext churns visibly. Moving
   surfaces into a DB makes the tree look clean — monitors whitelist-rot
   rather than error loudly.
3. **Redaction is sized for the current sink.** Emitter-side redact_home +
   sink-side report-queue token family, both fail-closed and pinned by
   tests, exist because the ledger is public. A DB changes the threat
   model (no public push) and invalidates the reason the guards are shaped
   as they are; dedup ids are hashes of redacted text.
4. **~140 tests + feeds + MCP encode file formats.** Fixture harnesses
   (HNGH_REPORT_ROOT / STATE_FILE / HNGH_HOME_DIR) are path-addressable.
   Every migrated surface = reader rewrites across patrol, feeds, digests,
   graph, dashboard + their tests. The repo has been here before: the
   dispositions pad-to-9 shim shows how migration shims accrete.
5. **Single-writer discipline is documented and working.** flock + one-writer
   conventions are explicit (ponytail comments name the ceilings). DB
   transactions would replace them, but every current writer is a bash
   script — each one gains a sqlite client dependency to migrate.

## Decision framework

Move a surface to a DB only when ALL hold:

1. It has no git-evidence semantics (untracked, or export-only).
2. Its readers can query or its format can keep a passive export
   (the beads pattern: DB = source of truth, plaintext = export).
3. The write path is python/sqlite-capable or centralized in one helper
   (crumb/budget/handoff writes all route through lib helpers).
4. A named schema version exists before the first row moves.

Never move: anything the ceremony hashes, anything the public push
redaction contract covers, anything hand-curated prose.

## Recommendation (advisory)

1. **Now — schema-first tests.** Formalize the de-facto schemas as named
   tests: crumb vocabulary, TSV header contracts, report-queue kinds.
   Cheap, zero migration risk, and it is the prerequisite for any later
   move. Rides the existing patrol header checks rather than replacing
   them.
2. **Next slice — Tier 2 journal #1.** Start with `agent-handoffs.md`
   (smallest blast radius: 4 readers, respawn/watchdog/resume) or
   STATE.md crumbs (biggest win, ~10 readers) — NOT both in one slice.
   Pattern: sqlite WAL table + `created_at` + passive plaintext export
   (or keep file as export and DB as source) so grep readers survive
   untouched on day one.
3. **Don't touch Tier 0/Tier 3 until an evidence story exists.** If a
   public schema-constrained versioned ledger is ever wanted for
   research data, evaluate dolt (in-repo precedent via beads) — not a
   new architecture.
4. **New journals start DB-native from day one** under `~/.hngh/db/`
   (userspace) or `automation/state/` (machine, untracked) following
   telemetry.py's additive-only discipline.

## Unknowns (scout-flagged, not yet resolved)

- docs/records/*.md exact count; plan-file original writer script not traced.
- `automation/ng/` ledger tracked status unverified (not in .gitignore, not
  git-checked).
- `refs/dolt/data` existence on origin assumed from docs, not verified.
- sweep-artifacts.sh exact commit list; repo-stats.jsonl readers beyond
  security-check; deck-facts consumers beyond the deck itself.

## Escalation SLA / halt

This brief is advisory: no storage moves without an operator-approved slice.
If adopted, the schema-test slice (rec. 1) carries SLA = one automation-gate
cycle; halt = none (tests only). Tier 2 migration slices each carry SLA =
next patrol cycle confirms readers green; halt = patrol red on the moved
surface for 2 consecutive cycles → revert export switch, park on operator.
