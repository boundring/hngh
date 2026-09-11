# Public face redesign - audit and direction (Nihei/Hayashida)

Audit pass, 2026-09-11. Operator directive: the README and public GitHub
appearance "need a lot of work." This document is the audit + design
pass; a later beat implements it. Baseline findings are cited from
[2026-09-10-peer-standard-review.md](2026-09-10-peer-standard-review.md)
(findings 1, 7, 8) - that review is the adversarial baseline; nothing
here re-argues it, this builds on it.

Method: every public-facing file was read as a stranger with no prior
context. Corpus counts at audit time: 40 design docs, 94 records, 91
research files, 18 journal entries, 167 plan files. `.github/` holds
only issue/PR templates and a 16-line kernel-only CI workflow.

## 1. Stranger's first-90-seconds audit

### What the GitHub landing shows now

The top screenful of [README.md](../../README.md) is the "What Hngh is"
prose block: strong writing, no factual anchor. A stranger's first
screenful contains no badge, no install or verify one-liner, no
transcript, no image, and no link to proof. The first code is `make
test` at line 203. The dashboards the README praises are linked at line
288 - 90 seconds of scrolling away. The honest "what this is NOT" (no
daemon, no release, nothing ambient) sits at line 197, buried under the
status wall it qualifies.

### What is missing (against the peer bar)

1. **No one-screen self-explanation.** The billion-context bar: the
   README explains itself in one screen. Hngh's one-screen equivalent
   exists in prose quality but not in structure - the identity is
   there, the evidence is not.
2. **No proof of life.** No dashboard screenshot or ASCII render link
   above the fold (peer finding 7: "no create-run-to-close-run
   transcript, no scripts/hngh example output, no screenshot of the
   dashboard it praises"). The renders already exist on disk
   (docs/media/linear.txt, spiral.txt, circular.txt, wave.txt) and are
   never surfaced early.
3. **No install/verify honesty above the fold.** Peer finding 1: "no
   stranger can install hngh." The README's Verify section implies
   `make test` is the path; it needs SBCL, a clone, and admits nowhere
   that the live machine requires one operator's desktop. The no-
   daemon/no-secrets boundary is stated - but 190 lines in.
4. **No release posture.** CHANGELOG.md opens with "Nothing has been
   released yet"; zero git tags (peer finding 8). This is honest and
   should be stated as a fact, not left to be discovered.
5. **No badges or shields.** None exist. Repo structure on first view
   is a 36-entry directory listing (peer review, finding 1 method note).
### The three highest drop-off points

1. **Fold 1 to fold 2: philosophy, then a 126-line wall.** "Why" (the
   furnace/ledger essay - the best prose in the repo, per peer finding
   7) hands directly into "Status" (lines 71-196): 19 promotion rungs,
   each a multi-line bullet, zero sub-headers, zero hierarchy. A
   stranger cannot tell rung 4 from rung 18 or why the order matters.
   Most readers stop here.
2. **The install gap.** Every concrete path (clone, SBCL, make test,
   operator environment, systemd units) requires reading automation/
   README plus two records. Peer finding 1: peers install in one
   command; hngh needs a personal desktop. Until bootstrap exists, the
   README must say so in one honest paragraph - readers forgive
   difficulty, not concealment.
3. **The proof gap.** The reader is asked to believe a machine hall
   exists and is shown no window into it until line 288. The journal
   (docs/journal/2026-08-25.md), the ASCII dashboards, and the digests
   are the proof, and they are all below the fold.

## 2. Reading-flow audit across docs/

### Where the corpus loses a stranger

- **README.md:71-196, the status wall.** One flat list, 126 lines, 19
  rungs. Directive: split into 4-5 sub-headed groups of max ~7 bullets
  (Core, Governance, Outer adapters, Operator surface, Live machine)
  and move the rung-by-rung inventory to a features ledger
  (docs/core/component-map.md already exists and owns responsibility
  detail); the README keeps a five-bullet "what exists" summary with
  links.
- **docs/README.md:54-114, the 30-link flat list.** "Interface and
  research reads" is one undifferentiated block. Directive: cluster
  into four named groups (Operator interfaces; Governance and loop
  designs; Machine-hall operations; Research and roadmap), each with a
  one-line cluster caption in the margin-caption style of section 4.
- **docs/records/ (94 files).** No current-vs-historical banner (peer
  finding 8's "current vs historical" split is prescribed, not landed).
  Directive: records/README.md gets a two-shelf banner - "current
  contract" files at top, everything else citable archive - with dates
  in every row.
- **docs/research/ (91 files).** No index of verdicts. A stranger
  cannot tell settled research from open lines. Directive: research/
  README gains a verdict column (adopted / open / retired) per line.
- **Paragraph discipline.** intent.md is the model (short paragraphs,
  one idea each). The worse offenders are the plan files' repeated
  autonomy paragraph (peer finding 5: 15 copies) - docs-level fix is
  the single reference the inventory already prescribed.

### Information architecture: porch, foyer, parlor, archive

- **Porch - README.md.** Identity in one screen: what it is, why it is
  different (one paragraph, not an essay), one mermaid architecture
  diagram, one worked-example pointer, Verify, honest NOT-block,
  release posture, then the door to docs/. Philosophy moves after
  proof, not before it.
- **Foyer - docs/README.md.** Tiered read-order: "five minutes"
  (STATE-OF-PROJECT.md, intent.md, architecture.md), "thirty minutes"
  (contracts 1-5), "deep" (design/ + research clusters). The foyer
  routes; it never duplicates room content.
- **Parlor - docs/intent.md.** The vision read. Keep as-is; it is the
  strongest stranger-facing prose in the corpus. Add one cross-link to
  the worked example so vision readers meet a transcript.
- **Rooms - docs/core/, docs/design/.** One page owns one contract;
  hub-and-spoke from the foyer. No content duplication between rooms.
- **Archive shelf - docs/records/ + superseded research.** Citable,
  dated, bannered current-vs-historical. Nothing is deleted; the
  retirement archive pattern already established in records/ is the
  template.

## 3. Architecture explanation plan

### The clean-architecture story for strangers

Three sentences, then the diagrams. (1) The kernel
(hngh.domain + hngh.application) is a pure Common Lisp spine: it reads
no clock, no file, no network, no subprocess, and refuses anything
unknown or unverified - fail-closed is a property, not a policy.
(2) The world plugs in at explicit ports through adapters; the
dependency arrow points inward only, and no adapter ever decides
whether something is valid. (3) Authority is a certificate: permission
for exactly one action, bound to evidence, rechecked at the moment of
action. The lifecycle diagram in docs/architecture.md (created ->
armed -> running -> checkpointed -> terminal -> afterlife) is already
correct and compact; it stays as the canonical text form.

### Diagrams needed (mermaid is available in-repo)

1. **P0, one diagram: the kernel and its ports.** Center: domain +
   application. Ring: the six use cases. Outward: evidence, review,
   mutation, federation/attestation, worker adapters, presentation,
   composition root. Caption names the dependency law: arrows point
   inward only; transports are injected.
2. **P0, one diagram: the machine hall (integration).** See below.
3. **P1, optional: the run lifecycle as a mermaid stateDiagram** for
   docs/core/run-contract.md, with the ASCII form kept alongside as
   the canonical text.

### The "how it integrates with what it manages" section

One integration diagram, then one short prose block per surface (each
block: what it is, how it touches hngh, what stays outside). Surfaces,
all landed per CHANGELOG and records - cite, do not paraphrase into
invention:

- **Git.** The mutation executor executes only certificate-bound fixed
  git verbs, rechecked against fresh evidence
  (docs/core/component-map.md; src/adapter/mutation.lisp).
- **Models and quotas.** Bounded review adapter (one closed request,
  no default provider); automation legs (kimi/lobehub history,
  congestion ladder) in automation/lib/model.sh under the spend
  governor (automation/cadence-params.tsv). The lobehub leg was
  dropped 2026-09-11 (commit 5b2ab55) - the integration section must
  describe legs as a set, not enumerate brands as permanent facts.
- **Systemd timers.** Every cadence tier is an operator-installed
  single-tick unit (automation/systemd/); no daemon, ever. Install is
  `make enable` in automation/.
- **Dashboard and TUI.** Nerve-center webapp (Schedule, Sessions,
  System, Research, Logs) and scripts/dashboard-tui, both fed by the
  read-only renderer over the operator store.
- **MCP.** automation/mcp/hngh_mcp_server.py - five read-only tools,
  landed with the omp integration 2026-09-11
  (docs/records/2026-09-11-omp-integration.md). Peer finding 6's
  "designed but empty" is now false; the docs must say so with the
  record citation.
- **omp / opencode executors.** scripts/omp-bridge gates delegated
  sessions through create-run/admit-transport (2026-08-26 record); the
  opencode branch is wired but dormant-until-armed
  (docs/records/2026-09-11-opencode-executor.md) - row EMPTY, default
  stays omp. Say the dormant state explicitly; do not imply live use.

## 4. The Nihei/Hayashida design language

Flavor first, law second: [display-register-spec.md](../design/display-register-spec.md)
already fixes the register - flavor is perceptual, never canonical,
never enters a record. Everything below is presentation-scoped (README,
docs layout, future web surface); canonical text stays plain.

### (a) Typography and spacing = immense structures

- **Narrow panels.** Prose columns max ~72 characters in source, ~40rem
  in any rendered CSS. Wide text is a corridor with no walls.
- **Panel gutters.** Full blank-line breaks between ideas; one blank
  line inside an idea. A section is a Nihei panel: small figures of
  text surrounded by silence. Rule of thumb: if a paragraph exceeds
  six lines, it is a wall, and walls get doors (sub-headings).
- **Tech annotations.** Nihei's tiny margin captions become inline
  code spans carrying provenance: `record: 2026-09-09-omp-integration`,
  `rung 14`, `gate: 03-gate-check`. Every claim annotated where it
  stands, not footnoted away from it.
- **Vertical rhythm.** Header, blank, body, blank, rule - never two
  rules or two headers touching.

### (b) Section headers as monument plates

A monument plate is a rule, a mono caption, then the title:

    ---

    `[ I. THE KERNEL ]`

    ## A spine that refuses

The caption is the engraved label at the base of a structure; the
title is the structure. Apply to README top-level sections and to the
foyer's read-order clusters. Not every header - monuments mark
movements, not paragraphs.

### (c) Motif vocabulary mapped to doc sections

- **Skeleton = the kernel.** docs/architecture.md, the charter, the
  run contract. Bare structure, no flesh: pure values, closed
  lifecycles, refusals. The lifecycle diagram is literally a skeleton.
- **Moss = accumulated records.** docs/records/, the journal, the
  ledger sections. Growth that proves age and stays honest - records
  are the moss line on the wall: every layer a dated fact.
- **Mushrooms = research lines.** docs/research/ and the research
  beat. Dorohedoro's mushrooms: things that sprout in the dark where
  something failed, and some of them are food. The research README's
  verdict column is the forager's field guide.
- **Vast dark structures = the machine hall.** The automation tier,
  cadence tiers, systemd units, the dashboard. Immense, quiet,
  mostly unseen - which is why the proof section exists.
- **Bone white = evidence.** Certificates, receipts, digests. White on
  dark stone: the only thing that carries light.
- **The figure = the operator.** One human, small in frame, holding
  final say. Appears wherever the human's say is the point (governance,
  intent's "human keeps the final say").

### (d) Color palette (dark stone / moss / bone)

Scoped to web/GitHub rendering (shields, future CSS, mermaid themes) -
the display register's "no invented hexes" law governs the operative
and terminal surfaces and is not overridden here; this is a separate
surface with separate authority:

| Role | Hex | Use |
| --- | --- | --- |
| Void (background) | `#171B17` | page/backdrop |
| Panel | `#232823` | raised surfaces, mermaid nodes |
| Basalt (rules) | `#39413A` | borders, dividers |
| Moss (accent) | `#7FA05E` | primary accent, links, mermaid lines |
| Deep moss | `#4A6142` | secondary accent, fills |
| Bone (text) | `#E7E2D3` | primary text |
| Ash (muted) | `#9B9889` | captions, annotations |
| Slit (signal) | `#F4F1E6` | the eye-slit: one point of highest signal per view |

Shields.io takes hex colors directly, e.g.
` shields/badge/passing-7FA05E ` (dark: `#171B17` background, bone
text). Mermaid themeVariables map one-to-one: background `#171B17`,
primaryColor `#232823`, primaryTextColor `#E7E2D3`, lineColor
`#7FA05E`, edgeLabelBackground `#232823`.

### (e) ASCII and mermaid styling directions (no images required)

- **ASCII only where the repo is ASCII.** Box-drawing unicode is
  banned by the language rule; diagrams use plain `+ - | > = v ^` and
  blank space. The existing lifecycle form in architecture.md is the
  register: lowercase arrows, one fact per line.
- **Machine-hall diagrams are elevations, not flowcharts**, where
  possible: vertical stacks with the kernel at the base (the
  foundation never moves) and surfaces stacked above it. Example
  register, not final art:

        [ webapp | tui | osd ]        observation deck
        ------- read-only renderer -------
        [ cadence ticks | watchdog ]   service levels
        ------- injected transports -----
        [ evidence | review | mutation ]  adapter ring
        ================================
              hngh.domain / .application   bedrock

  (Render in real indentation in the final docs; plain ASCII rules
  only.)
- **Mermaid carries connectivity** (adapters, ports, integration
  surfaces) in the section-4 palette; **ASCII carries mass** (the
  elevation, the lifecycle). Never duplicate the same diagram in both.

### (f) Where generated art slots in (P2, after the image workstream)

Describe the shots; do not fake them before the workstream delivers.
All shots in the register of section (c), palette of (d):

1. **Hero banner (README top).** 1600x400 or wider, thin: a horizon
   rule at the lower third, a machine-hall silhouette rising out of
   frame, one moss-lit pylon, a single figure 1/12 of frame height
   with a bone-white eye-slit. No text baked in - the README supplies
   it.
2. **Section spacers.** 1600x80 strips: a corridor vanishing point, a
   pipe run, a moss-climbed pylon base. Four, one per monument
   movement (kernel, machine, records, route).
3. **Intent-doc vignettes.** Three, small: the camp (one tick of work,
   one pause - a lit square in darkness), the evacuation (figures
   leaving a structure, carrying light), the lattice horizon (many
   small structures, one shared ledger line). intent.md keeps its
   prose; vignettes sit between movements as plates.
4. **Character/environment set for the long read** (book.md and the
   public site): the operative generation-5 figure in the hall,
   rendered at the measured constants of operative-frames.md.

Art placement rule: art never carries facts. A missing image degrades
gracefully to the ASCII elevation; every alt text states the section
it adorns.

## 5. Implementation plan

### P0 - the porch (README rewrite)

Files:

- README.md - restructure: identity block (one screen), badges row
  (build: CI kernel badge; license: AGPL-3.0-or-later; status: pre-
  release honest badge), one mermaid kernel/ports diagram, worked-
  example pointer, Verify with SBCL requirement stated, the honest
  NOT-block (no daemon, no release, live machine needs this operator's
  desktop per peer finding 1), monument-plate headers, status wall
  split into grouped subsections, philosophy moved after proof.
- docs/core/worked-example.md (new): the create-run-to-close-run
  transcript plus one automation beat walkthrough - the peer finding 7
  fix, the single highest-leverage addition.
- README badges: shields only, palette hexes from section (d).

Editing conventions (all phases): max ~7 bullets per list, hierarchical
numbering when parts belong together (1.1 under 1), one idea per
paragraph, blank line between ideas, provenance annotations as inline
code spans, ASCII-only.

Verification: render README on GitHub (or `glow`/pandoc locally) and
walk the first 90 seconds as the stranger test: identity, proof,
install honesty, door onward - each within the first screenful. Peer
finding 7's checklist is the acceptance gate.

### P1 - the foyer and the rooms

Files:

- docs/README.md: tiered read-order (five minutes / thirty / deep),
  four-cluster research-and-interface list, margin-caption style.
- docs/records/README.md: current-vs-historical two-shelf banner.
- docs/research/README.md: verdict column (adopted / open / retired).
- docs/architecture.md: integration section + machine-hall diagram;
  mermaid kernel diagram mirrors the README one (same facts, more
  detail).
- Formatting pass over the worst paragraph-grouping offenders found by
  `grep -c` for 15+ consecutive bullet lines in docs/ (concrete list
  generated at implementation time, not guessed now).

Verification: a stranger path test - start at README, reach the run
contract without dead links; every cited record resolves; corpus
counts on the foyer match reality.

### P2 - the art and the long read

Files: README hero slot, four spacer slots, intent vignettes, book.md
cover. Blocked on the image-gen workstream; the slot descriptions in
section 4(f) are the brief. Before any image lands: alt text written,
ASCII fallback in place, palette agreement with section (d).

Verification: visual check on GitHub dark and light themes; degrade-
to-ASCII confirmed by rendering without images.

## 6. Constraints honored

- English/ASCII only in-repo text; the flavor lives in structure,
  spacing, naming, and palette - not unicode decoration (this document
  itself obeys it: no box-drawing, no en-dashes in any new repo text).
- The kernel is pure Common Lisp and pre-release; docs say "pre-
  release, not production ready" as fact, never overclaim. Check
  counts are cited as "past N", never frozen.
- The no-daemon/no-secrets boundary is stated wherever install is
  described; the live machine's operator-dependence is admitted, not
  implied away (peer finding 1 fix direction).
- Never invent history: every landed fact cites its record file or
  CHANGELOG entry; dormant and empty states are labeled dormant and
  empty (opencode executor, MCP adoption).
- The display register's boundary law holds: flavor is perceptual
  display, never canonical, never governance input.

---

Back to the [documentation index](../README.md).
