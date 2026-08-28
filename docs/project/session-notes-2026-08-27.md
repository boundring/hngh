# Session notes — operator session, 2026-08-27

Dated: 2026-08-27. Status: draft harvested from the day's operator session for
Main's ceremony; nothing here authorizes a future action (records rule).

Sources: [records 2026-08-27](../records/README.md) (five records),
[backlog](backlog.md) (the 2026-08-27 rungs),
[display-register-spec](../design/display-register-spec.md),
[CHANGELOG](../../CHANGELOG.md) (2026-08-27 section), and the session's
directives. Tags: `[landed]` = verified in a record/CHANGELOG entry;
`[queued]` = forward work, not built; `[decision-pending]` = awaiting the
operator.

## 1. Direction & intent

What the operator repeatedly asks for, across the whole session:

- **Self-optimizing, self-testing, self-evident.** Hngh should check its own
  operations procedurally, not wait for a human to notice slowness — the
  time-ledger rung exists because "excessive delays … should be noticed
  procedurally"; the dashboard self-review drop-in makes the dashboard inspect
  itself hourly; every finding must classify itself
  (`unacceptable-now` / `acceptable-for-now`). [landed]
- **Interface plurality, OMP/Konsole primary.** The operator's primary working
  surface is an OMP session in Konsole; the dashboard hands off to real
  surfaces (spawn proven live) rather than replacing them. [landed first
  slice; per-surface presets queued]
- **Hand-holding plus attention to detail.** The operator wants orientation
  and onboarding affordances (observatory legend, human receipt sentences,
  launcher documentation) AND catches the smallest defects — an off-canvas
  gantt bar, a raw `transport-fault` render, glued headers, jargon. [landed]
- **Compact + clean + rich.** Verdict-first surfaces (one honest verdict
  before the numbers), dense panes, no emoji, dark-coat register; richness
  comes from sourced estimates and connectors, not chrome. [landed]
- **Winamp-style skeuomorphism** for dashboard theming — desired, explicitly
  deferred to later theme work; not built this wave. [queued]
- **Low-resource graphics: WebGL / procedural textures / music-reactive
  "dancing".** The dancing-ui rung (music runs the room) is the operator's
  "deliberately weird" favorite; probe-first, must never obscure the data,
  toggleable off. [queued]
- **Emacs-style configurability.** Declarative, layered user config
  (`~/.config/hngh/ui-config.*`) over display preferences only — never a
  second authority carrying governance fields. [queued rung; the ui-config
  defaults file exists via /spawn] [landed partial]
- **System config + package management harnessing.** Config manager and
  security manager rungs (rollouts, secret hygiene, key rotation, patch
  state) as the harness lane; config-backup lanes are the first slice.
  [landed partial; rungs queued]
- **Host orientation on install.** Any system Hngh lands on gets an
  orientation pass — packages, install sources (pacman/AUR, npm/bun/uv),
  agent-tool config surfaces — before interfacing; redacted archive, scan
  classes only. [landed partial via the CachyOS archive + gbd subsumption
  inventory; rung queued]

## 2. Designs landed today

One line per design, with where it lives (per the five records):

- **git-back-dots retired** — 11 units disabled, history archived verified at
  `~/Projects/back/git-back-dots/`, lanes subsumed by
  `jobs/config-backup.sh` (parity proven). [landed]
  ([record](../records/2026-08-27-dashboard-evolution-gbd-retirement.md))
- **Operator-item lifecycle** — open → handled (evidence line) →
  dismissed-as-viewed, persisted per item. [landed]
  ([record](../records/2026-08-27-operator-items-closeout.md))
- **Dashboard server endpoints** — `POST /operator-item/dismiss` and
  `POST /spawn` (ui-config launchers, key-only client access), Konsole spawn
  proven live. [landed]
- **Session-per-column observatory** — one column per session, live
  transcript tail, `#run-<id>` deep links, receipt sentences; 7 adversarial
  findings fixed. [landed]
- **Cascading gantt** — ESTIMATE-labelled bars (ledger p50 → loadout → 30m),
  connectors, zoom/pan, relative starts; the off-canvas `.glines` defect fixed
  and the lesson written down: verify rendered geometry, not DOM counts.
  [landed]
- **Dashboard self-review** — `jobs/dashboard-self-review.py`, hourly;
  feed freshness vs tiers, validity, served-marker regression, ledger drift.
  [landed]
- **Roguelike delegation wrap** — `scripts/omp-bridge --run-start/--run-end`,
  hngh-governed spawn and close of delegated sessions. [landed]
  ([record](../records/2026-08-27-acceleration-wave.md))
- **S3 status verb** — `scripts/hngh status`: verdict-first spine read,
  fail-closed `unavailable` panes. [landed]
- **S1 truth-telling dashboard** — verdict-first hero, state legend,
  `ETA` → `Depends on` display-only rename, `stale (Nm)` labels. [landed]
- **Display register spec** — one Nihei-register law for every future
  surface ([docs/design/display-register-spec.md](../design/display-register-spec.md)).
  [landed]
- **P2 DESIGN contracts** — command-center, system-awareness-map,
  buddy-menu-spec, gamified-runs; ceremony-ready, indexed.
  ([record](../records/2026-08-27-p2-design-contracts.md)) [landed]
- **P1 #1.5 course selection** — extracted from the service tick into the
  pure kernel (`src/domain/course.lisp` + application use case + CLI).
  ([record](../records/2026-08-27-task-1.5-select-course.md)) [landed]
- **Kernel + automation papercuts** — missing-store refusal exit 2 (+4
  checks), wake-store timestamped stores, MiniMax-H3 bench drop,
  provision_card prose-evidence wedge fix, report-queue dedup widened.
  ([record](../records/2026-08-27-operator-items-closeout.md)) [landed]

## 3. Sufficient / insufficient recognition

- **The two-tier vocabulary.** The operator grades shipped work in two
  tiers — *sufficient* (acceptable-for-now, ships and stays) vs
  *insufficient* (unacceptable-now, must be reworked). The vocabulary is
  already executable: the dashboard self-review classifies every finding
  `acceptable-for-now` / `unacceptable-now`, with the planned improvement
  named in the second case. [landed]
- **Self-review rung.** Recognition must be procedural, not remembered: the
  self-optimization-continuum rung (backlog) stands a self-review that emits
  `optimize: <suggestion>` breadcrumbs, and the hourly dashboard self-review
  is its first landed leg — the system noticing its own delays and
  regressions before the operator does. [landed first leg; rung queued]
- **The framing.** The operator's words for treating findings as fuel, not
  failures: *"problems are opportunities, delays are optimizations."* A
  wedged autonomy tick became the time-ledger rung; a 6,312-row git scan
  became the untracked-artifact fix (porcelain rows 6,312 → 25, ceremonies
  40 s → ~3 s); the off-canvas gantt bars became the rendered-geometry
  verification standard. [landed as practice]

## 4. Schedule & timetable decisions

- **Time-ledger levels.** One rolling ledger artifact with per-unit
  last/p50/max wall seconds and per-ceremony-step milliseconds; an
  oversight check flags any operation exceeding max(2× its trailing median,
  floor) as a flap-suppressed alert. [queued rung — the ledger is the
  gantt's estimate source]
- **Cadence tiers now live.** The cadence continuum runs month/week/day/
  hour/10m/5m/1m + ad-hoc as systemd user units over single-tick scripts
  (`docs/project/activity-matrix.md`); activity cadence maps routine
  project work onto those tiers with skip conditions (file a report
  instead of acting). [landed]
- **Anything weekly is never — daily minimum.** The operator's rule for
  cadence assignments: a weekly tier is too slow to count as attention;
  anything period-worthy must run at least daily. Weekly+ rows in the
  activity matrix get re-examined against this rule. [decision-pending on
  matrix rewrite; rule itself is operator-set this session]
- **QoL beat cyclical.** Quality-of-life surface work is a "regular,
  cyclical research and development concern" — the widget-grid rung pairs
  moveable widgets with a scheduled surface-evolution beat landing one
  graded QoL improvement per cycle. [queued]

## 5. Open decisions pending operator

- **gbd unit-file deletion** — the 11 retired units are disabled but their
  files remain on disk; deletion was not requested and awaits an explicit
  call. [decision-pending]
- **Cursor baseline** — which point the report-cursor baseline should be
  set to (retention/`--prune` and unread-signal semantics both depend on
  it). [decision-pending]
- **Per-lane medians (gantt)** — estimate bars need a lane→unit mapping
  before per-lane medians can replace the p50→loadout→30m fallback;
  requires wrapped sessions to name lanes in their missions. [decision-pending]
- **Report cursor adoption** — whether the observatory/notification paths
  adopt the report-queue read cursor as their baseline marker. [decision-pending]
- **(Also open from the closeout record)** — the `~/.hermes/config.yaml`
  token: remove from the tracked set or ignore-list it
  (`gbd-agent-configs` re-fails on its next tick until then).
  [decision-pending]

## 6. New from the evening's directive — forward work (not built)

Captured as the operator's evening unification directive; all [queued].

- **Nerve-center unification** — index/sessions/gantt collapse into ONE
  dashboard page with formal tabs (Sessions, Schedule alongside existing
  panels); one state system for activation; lazy-init per tab; five
  parallel owners, Main integrates. [queued]
- **Full-transcript observatory** — parsed conversation entries beyond
  receipt tails: thinking blocks, tool calls, collapsible sections,
  searchable; omp session jsonl format is the source (specimens exist). [queued]
- **Unified Schedule including system-ops compaction** — a single schedule
  view absorbing the gantt, plus a new system-ops metadata feed. [queued]
- **Window auto-tiling** — spawn places windows automatically; click or
  verbal command + confirmation; tiling profiles in ui-config defaults. [queued]
- **Phi proportions** — split layouts on the golden ratio (~38:62
  sidebar:detail), alongside the Nihei register as the composition base. [queued]
- **Formal tabs** — real tablist semantics (aria-selected, hash
  `#tab-<name>`, sessionStorage restore) replacing the broken fold-only
  panel toggling. [queued]
- **Winamp skeuomorphism theme** — queued skin work over the Nihei base. [queued]
- **WebGL / procedural textures** — low-resource generated surfaces for the
  unified page (probe-first per the dancing-ui rung). [queued]
- **Music-reactive "dancing"** — the dashboard breathes with the system
  audio beat; toggleable, never obscures data. [queued]
- **RPG-style agent stat scoring from the time ledger** — ledger-derived
  per-agent/per-lane stats (speed, reliability, cost) rendered as game
  stats under the `perceptual:true` honesty leash. [queued]
- **Single-source diagnostics (S2)** — wire the real `system.json` sources
  so the status verb's verdict rule and the dashboard's use one source
  (closes the verdict-rule-drift lesson). [queued]
- **Methods-documentation cadence** — a scheduled beat that documents how
  surfaces were built (the "how" alongside the records' "what"), riding
  the activity-matrix tiers. [queued]

## Cross-check log

Spot-checked claims against sources (2026-08-27, this harvest):

1. `jobs/dashboard-self-review.py` + hourly drop-in — CHANGELOG 2026-08-27
   "Added" and the gbd-retirement record §6.
2. `POST /spawn` Konsole launch proven live — gbd-retirement record §3 and
   the interface-plurality rung ("first slice LANDED 2026-08-27").
3. Gantt off-canvas root cause (`.glines` ~965px flow, ~1000px below fold) —
   gbd-retirement record §5 ("geometry, not DOM presence, is the
   verification standard").
4. Missing-store refusal exit 2, +4 checks (suite past 2,855) —
   operator-items-closeout record §1 and CHANGELOG 2026-08-27.
5. Cadence tiers 1m–month live — master-plan "cadence tiers 1m–month",
   `docs/project/activity-matrix.md` tier schedule (1m/5m/day/week/month
   drop-ins).

## 7. Evening addendum — unification wave + new directives

Captured live during the nerve-center unification wave:

- **Session naming + density QoL.** Session ids (`run-20260827T140151Z-2449044`)
  are nearly unreadable and truncation cutoffs are too aggressive. Target:
  common-sense density everywhere — rich and compact, legible, use all
  available space, small and reasonable margins. [queued]
- **System + Research are the first user-control surfaces.** Add new lines
  of research (optimized for Hngh, Hngh-on-system, other projects); add
  practical notes and steering commentary — affecting and non-affecting —
  to existing, active, completed, or in-proposal research lines. [queued]
- **Startup flow.** Dashboard visible at startup; immediately fire up an
  agentic session continuing Hngh work and system work. [queued]
- **Dashboard purposes, staged.** Track work on Hngh + ongoing
  operations/services; track research lines; interface with Hngh memory
  (llm-wiki is the easy first integration); review system resources;
  manage system configuration; CachyOS integration (packages + config);
  KDE/Plasma/X11/Wayland depth; true system-harness aspirations. [queued]
- **Self-supervision rung** added to backlog (Hngh watches its own agents:
  transcript phase detection, stall flags, roguelike replacement) — the
  harness agent must not be the permanent safety net. [landed rung]
- **Schedule reconciliation (this check).** Overcome-by-events lanes found
  in the oneoff list: machine-steered-backlog, agent-live-view,
  push-self-sufficiency, governance-vocabulary (all landed — see §2),
  credential-rotation-auto (folded into key-rotation-freshness). Queue
  flips applied this session. [landed]
- **Window-size law.** Operator's normal desktop window is a KWin
  half-screen snap (~1035px); clean page behavior required at ANY size
  (480/768/1035/1440/1920 sweep, geometry probes). [landed as rule;
  breakpoint fix in flight]

## 8. Second evening directive — dashboard QoL review + consolidation

The operator adversarially reviewed the unified dashboard ("insufficient
results so far, partial or impractical starts") and set the standard:
rendered geometry at real sizes, not element counts. Findings + the wave
responding to them:

- **Tab chrome**: buttons separate from contents; want seamless join.
  **Winamp-style skeuomorphism**: textured bezels, LED readouts, dense
  chrome — CSS-first, libraries welcomed over reinvention. [wave:
  ChromeSkin]
- **Schedule**: leftover-looking items; clean/combine/reorganize or
  determine what is still needed; recurring vs one-off must be obvious;
  the dream is the cascade — new work items created and fitted into
  place. [wave: SchedulePolish + the wrapped-delegation loop feeds it]
- **Sessions**: titles unreadable, display cut off/partial; want more
  QoL, navigable session views. [wave: SessionsTitles]
- **System**: cut-off widgets by default, coarse uncompromising grid,
  resize not useful — compact into a small dashboard; meaningful
  controls: package management, system update, configuration
  management, backups, syncing, local network status, connected Hngh
  instances/clients. [wave: SystemV2; governed package ops = rung]
- **Research**: controls for existing entries — reorder precedence,
  review collected material, knowledge-base links. [queued: ResearchV2]
- **Knowledge base**: review/navigate existing KB and researched
  material; QoL for KB management, multiple sources, scraped data.
  [wave: KBView]
- **Logs**: unused left space; reorganize; auto-summarize by
  category/source into subsections. [wave: LogsView]
- **The route**: most parts exist but lack a coherent route guaranteeing
  arrival. Roadmap rewritten to the seven-stage consolidated route with
  exit criteria. [landed]
- **Self-recognition**: Hngh should procedurally classify
  sufficient/insufficient — "why is this acceptable for the moment but
  intended for improvement later, and why is this unacceptable needing
  immediate attention." [landed: self-review two-tier vocabulary;
  extension rungs queued]
- **Methods documentation**: qualitative + quantitative records of
  methods and completed work, scheduled into routines. [landed: digest +
  wave records; cadence formalization queued]
- **The horizon**: Hngh improving itself rather than oh-my-pi improving
  it — supervision, scheduling, and correction become Hngh-native
  (self-supervision tick rung). [landed rung]

### Addendum — the stage-3 wrap wave (third evening session)

All four stage-3 exit criteria witnessed; roadmap State moved `next` →
`landing`. [landed] Fresh-eyes review of the acceleration wave returned
sound-to-build-on with two nits — both fixed (AUTO `9a8d647`, `a004d74`).
[landed] The 8,800-row stale-store alert backlog pruned through the
ledger's own prune gate; every ceremony store from the flap archived or
disposed (`M3` was receipts-only, never armed). [landed] Wrap witnessed
live: run-1 ran start → observatory `working` → `cancelled` end-to-end
(`b7d78f7`) — the persistent bridge store is single-use by kernel
design, so closed records rotate into `bridge/<ts>-<run>/` subdirs.
[landed] Auto-replace: seeded stall flagged + closed `dead` +
re-provisioned in one unattended tick (`e44a09d`); found and fixed a
real supervision bug — UTC record timestamps parsed as local time
skewed stall ages by the UTC offset. [landed] Per-lane medians +
actual bars rendered beside projections (`4ea4bdd`). [queued] The
larger pattern behind four render bugs: schedule feed and time ledger
share no canonical lane identity — make the lane name the join key at
the feed level; and the dashboard is the only component without a
selfcheck rung — a headless page-level selfcheck would collapse every
UI verification loop into one command.

## 9. Third evening intake — eight observations, folded

Operator observations after the stage-3 wave landed, each tagged with its
fold destination. Be careful as we proceed: capture before views, no
daemons, nothing engine-locked.

- Reporting appends a file every five minutes — separate telemetry from
  the curated record: SQLite (WAL, stdlib, no daemon) or journald for
  telemetry, git-tracked docs stay for curated rows. [design:
  ledger-and-records-spec.md]
- Standardized docs/planning/roadmap practices worth adapting to our
  aesthetics: ADRs (decision records with immutable numbering — our
  docs/records are already 80% of one), Diátaxis (tutorials/how-to/
  reference/explanation split), C4/arc42 for architecture docs, Shape Up
  (appetite + hill charts — honest progress fits the honesty law),
  Now/Next/Later roadmap vocabulary. Adopt as working agreements, not
  dependencies. [decision: working agreements, queued]
- Knowledge base store vs engine: the markdown vault is the canon;
  the KB tab is a bad viewer, not a bad store — wiki-grade reader
  (client-side search index, backlinks, graph, TOC), thin adapters to
  whatever the system has (Obsidian deep links, optional mkdocs/quartz
  publish), publishers evaluated at first publication. [design:
  knowledge-base-spec.md]
- Schedule items illegible at 100% zoom (vertical squash, horizontal
  clipping). [grade hooks: display-register-spec.md text-legibility
  floor + name completeness]
- Session names opaque: want category, type, creation hierarchy, age,
  full readable names, when/why created, duration, cost, models.
  [design: ledger-and-records-spec.md session-cost capture; display
  side rides the SessionsTitles wave]
- Research section opaque: want per-subject time, money, token cost,
  models, references, searches/engines; linked to the knowledge map;
  strategy-game-style presentation. [design: ledger-and-records-spec.md
  research-beat capture; view rides stage 5]
- Logs rework: apply known patterns (12-factor event streams, structured
  events, severity/facet filtering, rate histograms, retention tiers,
  redaction, safeguards) and decide what logs to produce for
  self-optimization. [design: ledger-and-records-spec.md is the data
  half; LogsView presentation is the wave]
- KB "wiki but not as usable as any wiki" + long-term publications and
  the story of Hngh's creation. [design: knowledge-base-spec.md]

## 10. Fourth evening intake — proceduralized scouting + arbitrary-event watching

Two observations from the self-improvement cadence wave, folded by
destination:

- Delegated scouting is proceduralized: the harness auto-delivers scout
  results to the orchestrating session the moment they settle — no
  polling, no hand-carried reports. Hngh-side equivalents should treat
  "result delivery" as a ledger append (report row + telemetry), not a
  daemon or a watcher. [landed: the day-tier drop-ins file their
  observables exactly this way]
- Operator decision — arbitrary-event watching is a Hngh capability:
  Hngh can and should be set up to watch for arbitrary events on demand,
  supplying notifications in whatever pipeline the consuming agentic or
  procedural function needs. Today's live views (session observatory,
  schedule/feeds) are the first consumers; the discipline stays
  fail-closed and bounded — on-demand watches with ledger-append
  notification rows, never resident daemons. Harness-internal event
  surfaces (omp spawn/admit/retire, kernel-side transitions) become
  watchable sources under this same capability. [decision: capability
  admitted; per-event wiring rides future waves]
