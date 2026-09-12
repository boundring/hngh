# Research pipeline yield audit — 2026-09-12

Operator questions: (a) meaningful knowledge-base additions or churn?
(b) why does part of the research await ANY operator actions? (c) should
the hourly ledger-sync own research commits, or should review + commit +
sync become part of every research operation?

Method: read-only census of `docs/research/`, `research-dispositions.tsv`,
the beat (`automation/cadence/hour/33-research-beat.sh`), the overnight
cycle (`automation/scripts/overnight-cycle.sh`), `accept-plans.py`, the
plans README, and the git log. All numbers below are from the tree.

## 1. Yield census

Corpus: 116 crystallized docs (2026-08-11 .. 2026-09-12). Sampled 8
across the range; grading: substantial / thin / loss-marked.

| doc | lines | grade |
|---|---|---|
| 2026-08-11 clean-architecture-roguelike-run-review | 166 | substantial — contradictions with file:line anchors into the source bundle, guardrails, verdict |
| 2026-08-28 log-presentation-patterns | 134 | substantial — contracted thesis, slice-first design, actionable for logging work (adopted) |
| 2026-08-29 unattended-session-budgets | 216 | substantial — budget envelope + external enforcement design; explicitly scoped to implementation |
| 2026-08-31 unattended-plan-authoring-safety | 17 | thin — header + evidence boundary, body truncated |
| 2026-09-08 cistern-architecture-review | 77 | substantial — 5-layer transfer analysis vs core/edge doctrine (adopted) |
| 2026-09-10 synth-2026-09-10-1 | 74 | substantial — Bernstein pattern non-transfer analysis, state-binding guardrail (adopted) |
| 2026-09-12 gdelt-gkg-trends | 71 | substantial — three candidate signals, honest truncation caveat (re-seeded wave) |
| 2026-09-12 os-harness-systemd-integration | 80 | substantial — coexistence decision at which-manager layer, needs-verification discipline (re-seeded wave) |

Verdict: not churn. ~7 of 8 sampled docs carry real findings; the one
thin doc is from the 2026-08-31 capture-loss era. The re-seeded
2026-09-11/12 wave (fixed writer, c220dbf/820db0c) is honest about
verification boundaries and reconstructs rather than fabricates.
### Conversion funnel

- 62 disposition rows: 34 adopted, 18 parked, 10 killed
  (automation/research-dispositions.tsv, 2026-09-12).
- 116 crystallized docs, 62 dispositioned — 44 crystallized/reviewed
  backlog remains in research-lines.tsv.
- ADOPTED -> implemented: exactly 1 line (fail-20260911-system-network-down,
  dd2e64c: WAN-probe fix + tests/test-system-awareness.sh regression).
- synthesize_dev_plan (overnight-cycle.sh:369) consumes adopted rows
  from the last 7 days — the wiring is correct — but it has NEVER fired:
  `grep -l "synthesized from adopted research" docs/project/plans/*.md`
  returns nothing, and no SYNTH-PLAN/DRAFT-PLAN files exist in digest/.
- Why it never fires: the synthesizer runs only when "the accepted-plans
  queue is dry" (overnight-cycle.sh). 34 plans currently sit
  status=accepted with unchecked steps — the queue is never dry, so the
  adopted findings never get synthesized into development plans.

Conversion: 116 crystallized -> 34 adopted -> 1 implemented (~1% adopted
to code). The docs are good; the drain from adoption to implementation
is the bottleneck, not research quality.

### Loss incident

2026-09-11 corpus-loss: 8 docs landed with junk bodies (model tool-call
syntax became "prose"). Cure: lib/docfilter.py capture-side filter wired
into the beat's crystallize write (33-research-beat.sh:565 — the doc
body comes from docfilter-filtered `$body`, truncation explicit, empty
capture alerts and writes nothing, state held for retry). Verified in
the beat source; 7 lost lines re-seeded (820db0c).

## 2. Operator-action gate inventory

"Part of the research awaits ANY operator actions" — the phrase surfaces
in the daily digest (`email-digest.py:390 operator_items`) and
`resume-pass.sh:109`. Four gates park work on the operator:

| # | gate | where | why it exists | operator-owned? keep/automate |
|---|---|---|---|---|
| G1 | digest DRAFT-PLAN review | overnight-cycle.sh plan-drafted -> digest/DRAFT-PLAN-*.md, surfaced by email-digest.py + resume-pass.sh:109 ("awaits operator review (never machine-executed)") | the digest-draft plan lane predates the machine admission contract; drafted plans are exempt from accept-plans.py by construction | AUTOMATE-ABLE: synthesize_dev_plan already writes status=proposed which accept-plans.py machine-admits (runnable verification + both gates green). The G1 lane is redundant with the dev-synth lane and should be retired or routed through the same proposed->accepted path. |
| G2 | critical-class park | plans/README.md contract: risk=critical parks automatically; autonomy reference forbids kernel src/tests/Makefile/hngh.asd, credentials, systemd lifecycle, secrets to machine sessions | governance boundary against the highest-blast-radius surfaces | KEEP operator-owned. This is the correct human gate. |
| G3 | plan-identity drift / blocked acceptance | accept-plans.py: plan-file clobber suspicion, red gates -> blocked + alert row | 2026-08-31 lesson: two blocked cycles were silent; now they alert | KEEP — it is an evidence gate, not a rubber-stamp; it resolves itself once gates go green (no operator action needed, just visibility). |
| G4 | supervision awaiting-operator | agent-supervision.py: a delegated session whose transcript ends asking a question is marked STALLED (awaiting-operator), never terminal | a machine session must not answer its own operator-directed question | KEEP — but the surface should make the question itself readable (operator feedback 2026-09-11: report queue shows counts, not content). |

So: nothing in the research yield chain itself waits on the operator.
The "awaits" items are (G1) a legacy draft-plan lane, (G2) critical-class
parks, (G4) supervision of sessions that asked questions. The research
pipeline's review->disposition->adopted steps are already fully
machine-owned; what stalls is adoption draining into work, per section 1.

## 3. Commit gap (pre-fix)

- The research beat wrote three artifact classes and committed NONE:
  kernel doc (docs/research/<date>-<id>.md), digest beat file
  (digest/RESEARCH-BEAT-*), and the TSV state files
  (research-lines.tsv, research-dispositions.tsv).
- Kernel doc: hourly 30-kernel-ledger-sync stages docs/ (incl.
  docs/research) and commits "docs: machine ledger sync" — lag from
  crystallize to commit <= 1 hour. Acceptable but batched.
- TSVs: NOT in the ledger-sync path list (docs/ only). Measured commit
  gap for research-dispositions.tsv: 2026-09-08 00:23 -> 2026-09-09
  19:13 -> 2026-09-11 00:10 -> 2026-09-12 04:33 — gaps of ~1.8 days and
  ~1.3 days. Dispositions (the adoption record) sat uncommitted for
  days, invisible to clean-tree preconditions and push.

## 4. Commit-per-op — IMPLEMENTED (this audit)

Change (33-research-beat.sh, free-commit lane; overflow beat shares the
body so the 15-minute cadence is covered by the same code):

- `research_commit <id> <state> <path...>`: commits exactly the named
  paths via `git add <path>` + `git commit -- <path>` with message
  `research: <id> <state>`. Fail-closed: non-repo kernel, operator
  staged work (mirrors 30-kernel-ledger-sync's staged-guard), or any
  path outside the repo (hermetic sandboxes) -> quiet no-op. No push
  (the sweep tier owns push).
- Crystallize transition commits the kernel doc + digest beat file +
  research-lines.tsv in the same beat.
- Review transition commits research-dispositions.tsv +
  research-lines.tsv in the same beat.
- Intermediate transitions (planned -> expanding -> contracting) stay
  uncommitted until crystallize: transient state, no value to preserve.

Collision with the hourly ledger-sync: both refuse when the kernel repo
has staged changes, so they never entangle; a ledger-sync that stages
just before the beat's commit can absorb the research files into its
dated sync commit — harmless (still committed, different message).
Post-fix the hourly sync normally carries nothing research-owned and
remains the backstop.

Validity gate: docfilter capture-side filter already runs on the same
write path (33-research-beat.sh:565), so preserved bodies are filtered
before both the write and the commit. The operator's proposal —
validate, preserve (commit), else continue the line — is now the actual
behavior: empty/junk capture alerts and holds state; a crystallized or
reviewed transition commits its artifacts immediately.

Proof: automation/tests/test-research-commit-per-op.sh (hermetic, ALL
OK): crystallize commit message + doc committed + docs/research clean;
staged operator work untouched; review disposition row lands; non-repo
kernel no-op. `make test` green (2026-09-12) and `env -i` hermetic run
green.

## 5. Recommendations (not implemented, specified)

1. Retire or unify G1: route digest DRAFT-PLANs through the
   status=proposed -> accept-plans.py machine-admission path (or drop
   the lane; synthesize_dev_plan already covers it).
2. Un-dry the synthesizer's precondition: with 34 accepted plans
   perpetually open, "accepted-plans queue is dry" never fires. Either
   cap the rotation (run the N oldest accepted plans) or let dev-synth
   append synthesized plans to the same rotation instead of requiring
   an empty queue.
3. Housekeeping: mark the 4 known duplicate pairs + stale parked rows
   killed so the disposition TSV converges (review beat already has the
   duplicate-pointer list).

## 6. Verdict on the operator's three questions

(a) Meaningful: yes at the document level (substantial, evidence-
anchored, honest about gaps), weak at the last mile — 1 adopted finding
became code because the synthesizer's precondition never fires.
(b) The "awaits operator" items are the legacy draft-plan lane, the
critical-class park, and supervision of question-asking sessions —
not the research chain itself.
(c) Commit-per-op is now implemented (section 4); the hourly sync stays
as backstop only.
