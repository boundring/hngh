# 2026-09-15 - Consideration: research lifecycle, memory, game-feel, and the pivot question

Status: CONSIDERATION ONLY. Nothing here is folded into hngh's plans,
roadmap, or code. This document exists so the operator can decide
where/how/when (and whether) any of it proceeds. Inputs: four read-only
analyst artifacts (.agent-scratch/consider/), live verification, and
external research (Mnemopi, OSS game-design resources).

## 1. Verified findings that reframe the questions

### 1a. The research pipeline provably has no exit (lion)
- 165 research lines: 141 reviewed, 21 planned, 2 crystallized. 169
  dispositions: 73 adopted, 64 parked, 31 killed.
- 124 RESEARCH-BEAT digests archived; 217 crystallized docs in
  docs/research/.
- **0 of 73 adopted dispositions feed any runtime decision.** The only
  consumer of dispositions.tsv is patrol.py, as alert-history. The
  pipeline is beat -> crystallize -> review -> dispositions ->
  TERMINUS. Circular, never cumulative. The operator's "sitting and
  dormant" observation is exact and measurable.

### 1b. The email reply capability already exists (horse)
- hngh has an IMAP reply leg: automation/scripts/imap-poll.py +
  cadence/30m/56-imap-poll.sh. UNSEEN replies -> operator-items,
  fail-closed, never deletes. What is missing vs jcode ambient is ONLY
  structured parsing (subject-carried report ids -> annotations, a
  small directive grammar). This is a small automation slice, not a
  new capability and not a jcode dependency.

### 1c. Mnemopi is installed and live on this machine (wolf + verification)
- ~/.omp/agent/memories/mnemopi/mnemopi.db (SQLite WAL): working_memory,
  SPO facts + FTS5 (657 fact rows), episodic memory, gists, graph_edges,
  memory_embeddings. Rich schema (importance, veracity, trust_tier,
  validator, corrected_by). MIT-licensed, CLI + MCP tool surface,
  banks/scoping, 384-dim local embeddings (fastembed BAAI/bge-small-en-v1.5).
- jcode's store: ~/.jcode/memory/global.json + projects/<hash>.json
  (the hngh project store alone holds 191 memories) with the garden
  (boost/decay/links/clusters/prune) acting on it.
- "Jcode memories mostly the same as Mnemopi": they are NOT the same
  model (flat entries vs SPO triples/layered), but both are local,
  both use 384-dim model-tagged embeddings, and mnemopi is the closer
  to superset. The workable relationship is **exclusive writers per
  store + a one-way sync bridge over a neutral superset** — never
  cross-writing (jcode's garden would decay/prune foreign entries and
  duplicate mnemopi's own consolidation).
- "Without conflicting information": conflicts arise only on
  cross-write. Read-through bridges (hngh reads both, writes neither
  except via each store's own agent) have no conflict surface.

### 1d. Tech debt is process accretion around healthy code (koala)
- Kernel 8.5k src + 9.0k test LOC (2,931 checks); automation 36k py +
  21k sh + 6.3k dashboard; 9 cadence tiers; backlog 84 sections.
- Vestigial sampling found every sampled automation file load-bearing.
- Hard-won assets NOT worth rewriting: ceremony loop, loop-history
  guard, patrol routes, report-queue, dashboard conventions, kernel
  ledger spine.
- Accretion to retire: patrol/cure/router/dedup meta-stack (superseded
  by today's expiry+escalation fold), overnight-lead lane, 84-section
  backlog governance, 9 cadence tiers (collapsible to 2-3).
- Strangler precedent exists in-repo: governed-fleet absorbed stage 4.

## 2. The pivot-vs-evolve verdict (evidence, not preference)

A from-scratch "Hnnghh" would re-earn the ceremony loop, the gates, and
the patrol fabric at full cost — these are hngh's most valuable, least
portable assets, and the 2,931-check suite is the proof they work. The
debt is concentrated in governance WEIGHT (meta-loops, dormant plans,
tier sprawl), which is exactly what a strangler refactor retires
without a fork. The intended features (research lifecycle, memory,
game-feel presentation) are ADDITIVE layers, not kernel changes — they
argue for evolving hngh, not pivoting.

Recommendation: **evolve inside hngh via the strangler pattern**;
additionally write the "Hnnghh minimal-core spec" as a pure design
exercise (one document, no fork) because compacting the base principles
to their smallest form is the best way to find what to retire. If that
spec reveals the minimal core is small enough to rebuild cheaply, the
pivot option reopens with real numbers.

## 3. Proposed architecture (layers, seams, no new builds)

### L1 - Research lifecycle harvest (the missing organ)
Today: beat -> crystallize -> review -> dispositions -> terminus.
Proposed: add a HARVEST step at review-adopted:
- a condensed lesson line per adopted item -> research-lessons.tsv
  (new, tiny) AND -> llm-wiki project vault (paths already known to the
  wiki-health patrol: ~/.llm-wiki and ~/Projects/etc/llm-wiki/.llm-wiki;
  ingestion is currently manual — automate the append in the exact
  shape its tooling expects).
- topic folding: group adopted lines by backlog section / dispatch
  theme (no NLP needed initially — the lines.tsv already carries
  subject taxonomy in the id).
- surface: context-pack.sh's research index line gains "top adopted
  lessons", so every session and beat re-reads what research concluded.
Missing (genuinely new): related-line clustering beyond id taxonomy;
re-disposition dedupe/refresh rule. Both are small.

### L2 - Memory unification
- Keep mnemopi (pi's) and jcode's stores each with exclusive writers.
- hngh's research->memory destination: jcode project memories for
  operational facts (the ambient garden already maintains them, cycle 2
  just ran a cosine dedup over 172 with zero dup pairs — the hygiene
  works), llm-wiki for durable catalog, docs/records for permanent
  committed truth.
- Bridge (when wanted): one-way mnemopi -> neutral JSON export read by
  a hngh context job; and hngh writes operational memories via jcode's
  own session/memory tooling (already demonstrated: ambient extracted
  the operator's claude/codex policy into a linked memory today).
- Do NOT build a unified memory graph across stores. Conflict-freedom
  comes from exclusive writers, not shared storage.

### L3 - Email reply feedback (small)
- Extend imap-poll.py: subject carries report id `[hngh <id>]`;
  replies append an annotation to that report's body sidecar and flip
  operator-item status; a tiny directive grammar (`approve:`, `deny:`,
  `note:`) mapped to operator-item status transitions. Everything else
  (IMAP, fail-closed, operator-item contract) already exists and is
  tested.

### L4 - Game-feel presentation (the megastructure map)
- The bones exist: megastructure 3D graph view, gantt time axis, story
  view, report ledger, telemetry, the research line ledger. The game
  layer is a RENDER + SCHEMA mapping over existing feeds, not new
  systems:
  - quest system ~= queue items + research lines (state machines
    already exist: queued/active/done; planned/expanding/contracting/
    reviewed). OSS reference shapes (Godot quest-system data schemas)
    are portable as JSON conventions, not code.
  - event tracking ~= report-queue + crumbs (exists; needs the expiry/
    escalation semantics landed today).
  - journal ~= research digests + journal/ (exists).
  - procedural maps = NEW: render research lines as ROUTES across the
    megastructure graph (lines.tsv transitions are edges; dispatch
    themes are sectors). This is a dashboard view family addition in
    the established view conventions (story/graph/history patterns),
    reusing graph-data.py's builder discipline. Procedural gen
    libraries (noise4j etc.) are reference algorithms; the layout
    already has a fibonacci-sphere engine.
  - stats-based interactions ~= telemetry.db + context-ratio patrols
    (exists); NPCs would be the swarm workers themselves (they already
    have names, roles, and lifecycle states).
- Honest scope note: this is the largest new surface (a view family +
  a stats schema). It should start as ONE map view (research routes)
  before any trope systemization.

## 4. Decision points for the operator

| # | Decision | Effort | Recommendation |
|---|---|---|---|
| D1 | Research harvest step (adopted -> lessons.tsv + llm-wiki + context-pack surface) | small automation slice, extend 33-research-beat | do first; directly ends the "dormant research" problem |
| D2 | Email reply parsing (report-id subjects + directive grammar on imap-poll) | small automation slice | do alongside D1; completes the operator feedback loop |
| D3 | Memory bridge design (one-way mnemopi export; hngh->jcode via existing tooling) | design now, build later | write the neutral-superset shape into the Hnnghh spec |
| D4 | Hnnghh minimal-core SPEC (design doc, no fork) | one document | do early; it doubles as the retirement plan for accretion |
| D5 | Strangler retirement list (cadence tiers 9->3, overnight-lead lane, backlog triage, meta-stack) | several slices | sequence after D1/D2 prove the strangler rhythm |
| D6 | Research-routes map view (first game-layer view) | medium dashboard slice | after D1 (needs the harvest to have content worth routing) |
| D7 | Trope systemization (quests/events/stats/NPC formalization) | large, phased | defer until D6 exists and is used |

## 5. What we deliberately did NOT do
- No hngh plans, roadmap rows, or code changed for any of this.
- No Hnnghh repository or scaffold created.
- No memory bridge built; no llm-wiki writes automated yet.
- All evidence lives in .agent-scratch/consider/ (4 analyst artifacts)
  plus this synthesis.

## 6. Ambient verification note
Cycle 2 verified clean at 20:02Z: executed both scheduled queue items
with evidence (cosine duplicate scan over 172 project memories, zero
pairs above 0.85), 2 memories modified, next wake 23:20Z. The garden is
doing real, evidenced maintenance.
