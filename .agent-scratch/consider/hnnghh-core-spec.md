# Hnnghh minimal-core spec (design exercise, no fork)

Date: 2026-09-15
Status: DESIGN DOC ONLY. No repository forked, no hngh plan, roadmap row,
or code changed. This document lives in .agent-scratch/consider/ per
synthesis decision D4. It doubles as the strangler retirement plan (D5)
and as the fallback blueprint should the pivot decision hooks (section 5)
ever fire.

Corrections (2026-09-15, factual audit against the working tree): R1/H3
cadence tier count is 8 live tiers, not 9; R4's before-state is restated
(the gate-crumb TTL fix d0bcb477 landed the same morning); section 2.3
and R6 counts re-pinned with exact measurement commands. Detail:
d4-principles-corrections-2026-09-15.md in this directory.

Inputs: d4-principles artifact (26 principles, 5 families, keep/shrink/drop),
refactor-assessment.md (sizing, debt inventory, strangler option),
research-lifecycle.md (pipeline audit, HARVEST proposal),
memory-systems.md (exclusive-writer analysis), synthesis.md (D1-D7 list,
pivot-vs-evolve verdict), git show bdee3708 (expiry+escalation landed).

---

## 1. Base principles (distilled from d4-principles)

Five families, 26 principles. Any Hnnghh capability must satisfy all of
them; the full source-referenced enumeration is in the d4-principles
artifact. Line-level citations below refer to that artifact's sources.

### A. Certificate-gated boundary and mutation
1. Certificate-gated kernel boundary: one certificate grants exactly one
   action, bound to specific files and evidence, re-checked immediately
   before the action.
2. Kernel purity: the core reads no clock, file, network, or process;
   the world plugs in through explicit ports; dependency arrows point
   inward only.
3. Doctrine 2a: a mutation with a certificate path (propose -> issue-cert
   -> mutation-check green) needs no operator stall; only actions with NO
   certificate path (credentials, payments, deletions, public surfaces,
   security posture) park on the operator.
4. A parked item with an open certificate path is a routing defect, not a
   governance outcome; a refusal from a failed fresh-evidence recheck is
   correct behavior, never engineered around.
5. Never-self-granting privilege: exact-command-with-exact-args grants,
   token-only secret entry; the system ships validated templates, it never
   edits its own privilege surface.

### B. Evidence and authority
6. Evidence-before-claim: receipts record what happened; they justify,
   they never grant power. A worker self-report is evidence, never
   acceptance.
7. Fail-closed gates: unknown, malformed, duplicate, or unverified input
   is refused. If the system cannot say yes for certain, the answer is no.
8. Reviewer/model/worker roles advise; a human decides. A worker is a
   tool, never the source of truth.
9. Deterministic policy verdicts: pass-or-refuse computed from evidence;
   missing, unknown, stale, or conflicting evidence refuses.
10. The meta-kernel carries reference signals, not verdicts: it
    distributes setpoints and checks constraints; no design doc may
    describe it as deciding.
11. Emergence is a description of observed certified transactions, never
    the certified thing itself; an emergent property cannot carry a
    content hash.
12. No loop resolves another loop's contradictory setpoints: conflict
    escalates to a certificate, the only locatable resolution.

### C. Data and state
13. Two-home separation: mutable userspace data under ~/.hngh (layout
    contract, never committed); secrets and kernel run stores under
    ~/.hngh-automation; the kernel knows neither home.
14. Exclusive-writer data ownership: one writer per byte range; machine-
    rewritten regions are fenced by fixed sentinels, the rest stays
    hand-edited.
15. Terminal states are permanent: retry means a new run, never a silent
    continuation. Permadeath is containment, not punishment.
16. Append-only honesty: ledger rows are resolved by verdict, never
    deleted.

### D. One admission shape
17. The one pattern: nothing is used that is not declared; nothing is
    declared that is not guarded; nothing declared goes unwatched;
    nothing mutates without a certificate.
18. One admission shape at every level: run, transport, peer key, service,
    chain leg, kernel mutation all admitted through the same gates
    (mirror principle one level out).
19. Documented-surface law: every external touchpoint is a declared
    registry row with a budget or health check.

### E. Operating posture
20. No daemon: every tier is an operator-installed single-tick timer; if
    you are not looking, nothing is doing.
21. Research-disposition honesty: every research line ends in one explicit
    verdict (adopted/killed/parked) with named reviewer, evidence path,
    and follow-ons.
22. Named honest losses: consolidations enumerate what they weaken, get
    explicit ratification, and never hide the narrowing.
23. Evidence before demo: done means exit criteria hold under standing
    guards, not a demo.
24. Failing-test-first, fixture-backed behavior; a verified slice commits
    as soon as make test is green, scope-confined, and record-updated.
25. Cost ladder: cheap route by default, expensive route only when named
    and evidenced, unknown cost refuses.
26. Federation horizon: a lattice of small ledgered machines, each guarding
    its own boundary, running the same narrow rulebook.

### 1.1 The admission rule (hard rule of this spec)

Any capability in Hnnghh must be stated as five answers:

- which registry DECLARES it,
- which guard FAILS IT CLOSED,
- which patrol WATCHES it,
- which certificate MUTATES it,
- which disposition ledger RECORDS it.

If any of the five is missing, the capability is not admitted. This one
rule is the compression of families A, B, and D, and it is the test the
retirement plan (section 3) applies to everything that exists today.

---

## 2. Minimal architecture

The smallest form that still supports: certificate-gated kernel mutation,
fail-closed gates, the research lifecycle, memory, and one render surface.
Anything not in this list is accretion by definition.

### 2.1 Kernel (certificate-gated mutation)

- Carried, not rebuilt: the existing ledger spine (src/ 8.5k LOC Lisp,
  tests/ 9.0k LOC, 2,931+ checks) ports nearly verbatim; it is pure,
  self-contained, and is the hardest asset to re-earn. [refactor-assessment.md:5,21]
- Surface: closed lifecycle values, ten-principle verdict, certificate
  minting, refusal taxonomy (exit 0 accepted / 1 refused / 2 malformed /
  3 transport fault). No clock, file, network, or subprocess; exit
  surfaces only.
- Mutation path: create-run -> admit-transport -> ten-principle propose
  -> issue-cert + mutation-check -> certificate-gated push; the commit
  message IS the certificate content hash. This ceremony is kept as-is.
- Only kernel changes ride the ceremony; automation moves on the
  free-commit lane with its guards.

### 2.2 Gates (fail-closed)

- Loop-history guard: machine-checks that behavior changes rode the loop;
  runs on every code-surface commit. Proven, fixture-backed
  (tests/scripts/test-loop-history-guard.py).
- Patrol routes: one TSV of routes; FAIL emits an identity finding
  (patrol:<id>) with a digest finding-class. Alerts carry TTL expiry and
  escalation-on-recurrence (landed 2026-09-15: d0bcb477 gate-crumb
  freshness, bdee3708 routed candidates); the router's within-day dedup
  suppression (routed != resolved) is the surviving suppression state
  that 3/R4 retires.
- Registries: one admission shape, rows pruned to the actual fleet
  (services, packages, credential seams, spawn paths, cadence entries).

### 2.3 Research lifecycle (beat -> crystallize -> review -> disposition -> HARVEST -> knowledge)

Before-state (analysis time, 2026-09-15 morning): the pipeline ended at
dispositions: 165 research lines, 169 disposition rows, and 73 adopted
verdicts with no consumer beyond patrol alert-history.
[research-lifecycle.md:4-10; synthesis.md:11-20]
[CORRECTED 2026-09-15: the live tree measured 2026-09-15T23:36Z shows
169 line rows, 173 disposition data rows (75 adopted verdicts across 72
distinct lines, 32 killed, 65 parked, 1 blocker-ledger "fixed"), and 69
seeded lesson rows; both files grow on every beat, so pin with
`awk 'END{print NR}' automation/research-lines.tsv` (headerless),
`awk 'FNR>1' automation/research-dispositions.tsv | wc -l`,
`awk 'FNR>1' automation/research-lessons.tsv | wc -l`.] Same-day
landings consumed the terminus: d0bcb477 gate-crumb TTL, bdee3708
routed-candidate expiry+escalation, bc40ab6d D1 harvest
(research-harvest.py + research-lessons.tsv), 0bb09044 D6 routes/1 map
(research-routes.py reads the dispositions ledger as the transition
log), and the context-pack adopted-lessons block.

Minimal lifecycle adds the missing organ:

1. BEAT: one bounded run per tick, closed lifecycle (created -> armed ->
   running -> checkpointed -> terminal -> afterlife -> scored ->
   archived); terminal states permanent, retry = new run.
2. CRYSTALLIZE: beat writes docs/research/<date>-<id>.md + digest (exists).
3. REVIEW: two-sided review (exists).
4. DISPOSITION: one row per line, verdict adopted/killed/parked, named
   reviewer, evidence path, follow-ons (exists; append-only honesty).
5. HARVEST (new, small): at review-adopted, append (a) one condensed
   lesson line to research-lessons.tsv and (b) one plain-markdown source
   entry to the llm-wiki project vault in the exact shape its tooling
   expects. No churn states, no topic clustering beyond the id taxonomy
   already in lines.tsv (named honest loss: related-line folding is
   deferred until volume demands it). [Landed 2026-09-15 for (a):
   bc40ab6d research-harvest.py, 69 seeded lesson rows; the (b) wiki
   append is still manual.]
6. KNOWLEDGE: context-pack.sh's research index line gains top-N adopted
   lessons, so every future session and beat re-reads what research
   concluded. This closes the loop that was circular, never cumulative.
   [Landed 2026-09-15: automation/lib/context-pack.sh:90-96 top-5
   newest active rows.]

Admission statement: registry = research-lines.tsv (declares the line);
guard = beat fail-closed on malformed input; patrol = wiki-health +
doc-numbers; certificate = none needed (automation lane, not kernel);
disposition = research-dispositions.tsv + research-lessons.tsv.

### 2.4 Memory (exclusive-writer stores + read bridges)

Findings that shape this: jcode memory (flat entries + garden) and
Mnemopi (SPO triples + episodic layers) are different models; cross-write
would let jcode's garden decay/prune foreign entries and duplicate
Mnemopi's own consolidation. Conflict-freedom comes from exclusive
writers, not shared storage. [memory-systems.md:44-48; synthesis.md:99-110]

Minimal rules:

- Each store has exactly one writer: jcode's own tooling writes
  ~/.jcode/memory; Mnemopi's own agent writes its banks; hngh's
  free-commit lane writes research-lessons.tsv and llm-wiki vault
  appends; docs/records stays the permanent committed truth.
- Bridges are read-only and one-way: a neutral JSON export (Mnemopi ->
  file) read by a hngh context job; hngh reads both stores, writes
  neither except through each store's own agent.
- No unified memory graph across stores (named honest loss: no
  cross-store query; the read bridges cover context assembly).
- Two-home split unchanged: ~/.hngh layout contract via
  automation/lib/hngh_home.py or HNGH_HOME_DIR; secrets and run stores
  stay in ~/.hngh-automation; kernel blind to both.

### 2.5 One render surface

Decision (resolves open question b): the single surface is the read-only
factual renderer over ledger + dispositions + patrol findings, built on
existing dashboard conventions. It shows the current-state table (what is
declared, guarded, watched, certified), plain-language digest items, and
one-word-answerable operator items. The dispatch file is an output
ARTIFACT of this renderer (a second viewer, not a second surface); a
webapp slice is rejected for the minimal core. Game-layer views (research
routes, D6/D7) are later additions inside the same view conventions, not
new surfaces.

### 2.6 Cadence

Two or three tiers total: hour (beat + patrol), day (digest + harvest
rebuilds), human (operator-installed timers, no daemon, ever). Everything
sub-hour folds into the hour tier; weekly/monthly folds into day.

### 2.7 The whole system in one sentence

One pure kernel mutated only by certificate, one set of fail-closed gates
and patrol routes with expiry+escalation, one research pipeline that ends
in consumed knowledge, memory as exclusive-writer stores joined by read
bridges, two or three timers, and one read-only renderer, every capability
stated as the five-part admission of 1.1.

---

## 3. Retirement plan for current hngh accretion (strangler D5 list)

Strangler, not fork: land compact replacements as new slices, flip
consumers, then delete the old path and disposition its ledger row. The
pattern is proven in-repo (governed-fleet absorbed stage 4 this way).
[refactor-assessment.md:29-37] Sequence after D1/D2 prove the rhythm
(synthesis D5).

Each item: what retires, the evidence, the retirement shape, and the
honest loss it names.

### R1. Cadence tiers: 8 -> 2-3

- Evidence: 8 live tiers (1m/5m/10m/30m/hour/day/week/month,
  cadence/README.md; refactor-assessment.md:6 misstated this as 9) for
  a one-operator system; every tier is a registry + maintenance surface
  under the no-daemon rule. Pin with
  `ls -d automation/cadence/*/ | wc -l` (measured 8, 2026-09-15).
  [refactor-assessment.md:6,24]
- Shape: fold sub-hour jobs into the hour tier, weekly/monthly into day;
  prune cadence-params registry rows to the surviving timers; each fold
  is one free-commit slice with the loop-history guard green.
- Honest loss named: sub-hour reactivity (1m/5m/10m/30m lanes) disappears;
  anything that genuinely needed minutes-level response must either
  justify an hour-tier route or be an operator action.

### R2. Overnight-lead lane and agent-supervision stack retirement

- Evidence: cause=unknown cancellations is a named real defect in the
  lane; the supervision stack's accounting shrinks to dispositions that
  resolve at the source. [refactor-assessment.md:11,26]
- Shape: root-cause the cancellations first (the defect is real and must
  not be deleted unpinned); then land the disposition-at-source pattern
  on remaining consumers; then remove the lane and its registry rows.
- Honest loss named: overnight autonomous progression pauses until a
  replacement need is demonstrated by harvested lessons, not assumed.

### R3. 84-section backlog triage -> one-file queue

- Evidence: backlog is 1,769 lines / 84 sections with 7 items still
  "queued 2026-08-2x/31"; queue.md holds 1 active item plus dormant
  sections; bridge-operator-host was mounted but never incremented ~19
  days. Governance surface for a one-operator system.
  [refactor-assessment.md:6,10]
- Shape: every section gets an explicit verdict (adopted/killed/parked)
  appended to the dispositions ledger (append-only honesty, nothing
  deleted); live items move into the single one-file queue, which is the
  report-queue ledger (KEEP, proven, dismissals built in) rather than a
  new file; queue.md dormant sections disposition and close.
- Honest loss named: long-horizon idea parking moves from a browsable
  84-section document to ledger rows; discoverability depends on the
  renderer surfacing parked rows.

### R4. Meta-stack replacement by expiry+escalation (PARTIALLY LANDED)

- Evidence (restated honestly, 2026-09-15): the false red-gate class
  was real, but its cause is fixed in-tree. Pre-d0bcb477, patrol
  check_gate_crumbs decided on the newest gate crumb with only a 26h
  absence check, so a stale gate-red crumb held the automation-gate
  label red for hours after recovery (the "red gate all day" incident
  was stale crumbs: a hygiene defect, not a red gate). d0bcb477
  (2026-09-15 13:29 EDT, 7 hermetic tests red-then-green) added the
  freshness TTL: automation/jobs/patrol.py:58 GATE_CRUMB_TTL_S=86400
  with PATROL_GATE_CRUMB_TTL_S override, and check_gate_crumbs
  (:271-287) degrades stale crumbs to one dedupable gate-stale fail
  (absent evidence fails closed) instead of letting them decide. The
  earlier claim that gate crumbs run "newest-crumbs-wins, no TTL" was
  a superseded-state description and is false of the current tree.
  Still real: suppression-as-fix routing (router-tick.py:20-22 and
  :442-468, dedup suppresses candidates within the day, routed !=
  resolved, escalation only at >=3 dedups) and meta-loop weight
  (patrol -> gate-cure -> router -> dedup; check_gate_cure
  patrol.py:636-696 runs the guard directly and self-handles red
  gates post-hoc). [refactor-assessment.md:11,13,25]
- Already landed (both 2026-09-15): d0bcb477 gate-crumb TTL (above);
  and bdee3708 (14:06 EDT) put TTL expiry + escalation-on-recurrence into the routed-candidate lifecycle in
  automation/scripts/router-tick.py (+142 lines) with
  automation/tests/test-alert-lifecycle.py (+221 lines, 9 hermetic tests,
  red-first): expired candidates rewrite status=expired atomically, and
  refire after expiry escalates to a fresh immediate re-route with
  count/oldest-ts. The replacement pattern now exists and is proven
  in-repo.
- Remaining: retire the cure/dedup double-probing legs and the
  within-day dedup suppression path, flip their consumers to
  expiry+escalation semantics, delete the old legs.
- Honest loss named: alerts are never held down by a cure loop anymore;
  a recurring failing finding escalates visibly instead of being
  auto-suppressed, which trades silence for operator-visible recurrence.

### R5. Stage/plan governance sprawl

- Evidence: stages 2, 3, 5 all nominally open; stage 2 "landing" since
  08-26; stage-5 exit criteria unwired; stage-3 ten-invariants show no
  evidence of running. [refactor-assessment.md:12]
- Shape: retire unwired exit criteria; keep only invariants that hold
  under standing guards; an open stage without a wired check is closed
  with a disposition row, not left nominally open.
- Honest loss named: long-range stage narratives end; the roadmap becomes
  the disposition ledger plus standing invariants.

### R6. Research churn states

- Evidence: planned rows churning without crystallizing; most lines sit
  reviewed at terminus; the pipeline was circular, never cumulative.
  Pinned 2026-09-15T23:36Z:
  `awk -F'\t' '{print $2}' automation/research-lines.tsv | sort | uniq -c`
  = 144 reviewed / 20 planned / 4 crystallized / 1 expanding over 169
  rows (analysis-time figures 21 planned / 141 of 165 reviewed were
  close but drifted; re-measure, never hard-code).
  [refactor-assessment.md:11; research-lifecycle.md:4-10]
- Shape: R2.3's HARVEST step lands (D1) so adoption feeds knowledge; then
  the "planned" pool is triaged to one-line/one-disposition semantics;
  churn states (expanding/contracting without crystallize) are refused at
  the beat gate.
- Honest loss named: exploratory expanding lanes without a crystallize
  deadline are gone; a line that cannot crystallize gets killed or parked
  explicitly.

### Sequencing and verification

Order: R4-remainder and R6 first (both unblock the rhythm), then R1, R3,
R5, and R2 last (it carries the real defect to root-cause). Every slice:
failing test first, make test green, scope-confined, disposition rows
written, commit message matching the slice. The retirement is complete
when the five-part admission of 1.1 holds for every capability that
remains, and the measured hooks of section 5 read green.

---

## 4. Pivot feasibility numbers

Sizing basis: kernel 8.5k src + 9.0k test LOC Lisp (2,931+ checks);
automation 36.0k Python (138 files) + 20.7k shell (170 files) + 6.3k
dashboard; current total ~80.5k LOC. [refactor-assessment.md:3-6]

### 4.1 Rebuild cost: minimal Hnnghh from (near) zero

| Component | Disposition | Est. LOC |
|---|---|---|
| Kernel ledger spine | carry verbatim | 8,500 |
| Kernel tests (2,931 checks) | carry verbatim | 9,000 |
| Ceremony loop (cert mint, mutation-check, push gate) | extract minimal | ~1,500 |
| Fail-closed gates + loop-history guard | extract | ~800 |
| Patrol: routes + findings + expiry/escalation | extract + new (bdee3708 pattern) | ~1,000 |
| One-file queue (report-queue ledger) | carry | ~300 |
| Research beat -> disposition -> HARVEST | rewrite small | ~1,000 |
| Memory: two-home lib + read bridge | carry lib + thin bridge | ~400 |
| One render surface (factual renderer) | rewrite small | ~1,500 |
| Cadence: 2-3 timers + pruned registries | rewrite tiny | ~200 |
| Total | | ~24,200 |

Range: 22k-26k LOC, i.e. roughly 30% of today's 80.5k. Of that, 17.5k
(72%) is a verbatim carry of the kernel and its test suite; only ~5-8k is
genuinely new or extracted code.

Contested part, stated honestly: the extraction numbers assume the
ceremony/gate/patrol code comes out of the 36k+20.7k automation with low
entanglement tax. Nobody has measured that tax; per-script LOC for those
subsystems was not taken. If extraction costs more than ~2x the rewrite
estimate, the "carry" column is optimistic and the true rebuild cost
rises toward rewriting the ceremony from scratch, which re-earns the
discipline at full cost.

Non-LOC capital a fresh repo must re-earn (not in the table): the 2,931-
check suite re-validated on a new harness; ceremony discipline
re-established; patrol fabric re-proven against real findings; and the
named mid-pivot loss, the evidence-ledger continuity fork plus a pause of
dispatch/newspaper/manga userspace outputs. [refactor-assessment.md:31-33;
synthesis.md:62-71]

### 4.2 Remaining hngh evolution cost (strangler to steady state)

- Retirement slices R1-R6: 6 slices, mostly deletions. Estimated net
  automation delta: -20k to -30k LOC over the series (meta-stack legs,
  overnight-lead + supervision stack, backlog governance surface, 6 of 8
  cadence tiers, dormant queue sections, churn states). Soft estimate;
  deletion size per leg unmeasured.
- Additive layers (synthesis D1 harvest, D2 email reply parsing, D3
  memory bridge, D6 first map view): +2k to +4k LOC.
- Steady state: kernel 17.5k (untouched) + automation ~33-45k = roughly
  50k-62k total, still 2x-2.5x the minimal core, but every line of it
  already proven under standing guards with zero re-earning cost and no
  ledger fork.

### 4.3 Verdict the numbers support

The minimal core is genuinely small: about a quarter of the current tree,
three quarters of it carried verbatim. The pivot is therefore FEASIBLE,
not a fantasy. But the LOC comparison is the wrong axis: the fresh build buys
-55k LOC and pays with re-earned ceremony, re-validated checks, and a
forked evidence ledger, while the strangler buys a 50k-62k steady state
at slice-sized cost with continuity intact. The rational default remains
strangler in-repo, which is why section 5 defines measured conditions,
not vibes, for reopening the pivot.

---

## 5. Decision hooks (measured conditions that reopen the pivot)

The pivot reopens when any hook fires with its measurement source. Until
one fires, evolve in-repo.

- H1 Strangler stall: two or more R-slices fail to land within 30 days of
  start, or any slice is reverted twice by gate refusal. Source: git log
  + ceremony records (check: R-slice landing commits and their
  reverts/refactors in git log plus the ceremony ledger).
- H2 Meta-stack regrowth: after R4 completes, router/cure/dedup script
  LOC or patrol route count grows >10% over the post-R4 baseline at a
  +60 or +90 day check, or any suppression path (routed != resolved)
  reappears. Source: LOC sampling + patrol-routes.tsv diff. Baseline
  measured 2026-09-15T23:36Z, re-pin at R4 completion:
  `wc -l automation/scripts/router-tick.py automation/jobs/patrol.py`
  = 564 + 1795, `grep -cv '^#' automation/config/patrol-routes.tsv`
  = 26 non-comment route rows.
- H3 Cadence convergence miss: tier count still >4 sixty days after R1
  lands (baseline 8 live tiers, not the misstated 9). Source:
  `ls -d automation/cadence/*/ | wc -l` over cadence registry rows.
- H4 Operator ratifies the fork: the named mid-pivot loss (evidence-ledger
  fork + userspace output pause) is explicitly accepted by the operator in
  a record. This converts the pivot from ruled-out to cost-feasible.
- H5 False-finding rate persists: after expiry+escalation is the only
  alert semantics, stale-crumbs-class false findings still exceed 2/month
  over a 60-day window. The slimmed architecture did not fix the class;
  structural rebuild is back on the table. Source: patrol findings
  history (count gate-stale/gate-red identities in report-queue history
  or dispositions over the window; d0bcb477 already degrades stale
  crumbs to one gate-stale identity, so the hook measures residual
  false alerts, not raw reds).
- H6 Kernel expressiveness wall: a required capability needs kernel
  lifecycle changes the closed lifecycle cannot express without breaking
  the check contract. Two such cases validates a fresh-kernel evaluation,
  the only genuinely from-zero component. Source: ceremony records.
- H7 Backlog triage failure: the 84 sections are not all dispositioned
  into the one-file queue within 45 days of R3 start. Source:
  `grep -c '^## ' docs/project/backlog.md` (= 84 sections, 1,769 lines,
  7 items still "queued 2026-08" as measured 2026-09-15) vs backlog
  disposition rows appended.

Numeric flip condition on the sizing itself: if measured extraction tax
on ceremony/gates exceeds ~2x the rewrite estimate (4.1), or D5 net
reduction stalls above -10k LOC after R1-R4, the evolve-is-cheaper claim
weakens and H1/H2 should be evaluated even if their clocks have not
expired.

---

## 6. Resolved open questions (from d4-principles)

- (a) Queue convergence: YES. The one-file queue that replaces the
  84-section backlog is the report-queue ledger (KEEP, proven, dismissal
  semantics built in); queue.md's dormant sections are dispositioned into
  it, not migrated as a second ledger.
- (b) Render surface: the read-only factual renderer on existing
  dashboard conventions (2.5). Dispatch file = renderer output artifact;
  webapp rejected for the minimal core.
- (c) Doctrine section 3 conflict: none. The standing meta-optimization
  authorization MANDATES improving the meta layer; replacement of
  suppression by expiry+escalation IS meta-optimization, it preserves the
  fail-first function (failures surface immediately and escalate on
  recurrence), and the retirement slices themselves ride the normal
  certificate/free-commit lanes like any mutation.
- (d) Migration boundary: NAMED. Strangler in-repo, effective now;
  fresh-repo Hnnghh remains a documented fallback whose blueprint is this
  spec, gated by the section 5 hooks. No fork exists today.

---

## 7. What this spec deliberately does not do

No fork or scaffold created; no hngh plan, roadmap row, or queue item
changed; no code written; no memory bridge built; no llm-wiki writes
automated. All claims trace to the four analyst artifacts, the synthesis,
commit bdee3708, and the source files those artifacts cite. The next
concrete actions, if the operator ratifies, are synthesis D1 and D2 (the
small slices that prove the strangler rhythm), then the R4 remainder.
