# Changelog

All notable changes to Hngh are documented here. Entries are dated by the
day they were recorded. Nothing has been released yet; development work
lives under Pre-release / early development until the first release.

## Pre-release / early development

### 2026-08-28

#### Added

- **Evening selfdev wave** (hngh-automation `585ccd0`, `c9474bf`,
  `6a9d561`, `5b6ad25`, `4bc46ae`, `6ef85c4`, `2ea3db0`): the
  automation gate repaired and both repos now gated daily
  (`03-gate-check.sh` sweeps kernel + hngh-automation, identity-scoped
  red alerts); the lint-identifiers scanner learned quoted-heredoc
  scoping and caught a real bug — the deck-setup .bashrc block's
  `$DESKTOP_IP` splices never expanded (quoted tag), so the deck's
  `HNGH_DESKTOP_IP` sourced empty; tree-skew whitelists
  machine-maintained append paths (dashboards, ledgers, journals) so it
  fires only on stalled agent edits; the review digest carries findings
  + reviewed ranges instead of the echoed prompt with ~1100 diff lines
  (122KB -> 1.9KB); first telemetry readers (`telemetry-report.py`) and
  session-cost capture (one row per omp session, usage parsed from
  transcripts, idempotent by session id); the 5m oversight tick now
  escalates unread gate-red rows (hourly cap, per-repo identity) and
  files a single ui-audit regression breadcrumb when a rule's violation
  count crosses upward.
- **Pre-trip sprint** (hngh-automation `be984d2`, `933c7c5`, `448e2d5`,
  `4787207`, `abb2be2`): hourly adversarial workbeat (the kick-start
  automation, guardrails included); winamp-only themes and the
  digest-freshness P1 fixed; wake-time context in every beat prompt
  (UTC now, last-activity age, unread alerts) with the accepted →
  executed plan transition; Steamdeck paired — tailscale userspace
  daemon, `hngh-desktop` ssh alias, `hngh-tunnel`, remote-posture card
  on the System page; plan ledger gains dashboard-qol and
  remote-hardening waves; the first autonomous overnight shift was
  evaluated and its lessons landed as fixes (budget counting,
  ceremony-store sweep, selector timeout with kill-after); acceptance
  policy reconciled — normal-risk plans machine-accepted by gate,
  critical-risk and the policy itself stay operator-owned.
- **Winamp conversion wave 1** (hngh-automation `5a4ac12`): the classic
  skin is the dashboard's default — playlist-editor schedule rows
  (uniform 48px rows, striping, LED greens), LCD marquee ticker, panel
  shade/roll-up, schedule jump filter and status bar, and a programmatic
  UI audit (`jobs/ui-audit.mjs`: axe-core + display-register rules,
  mounted on the hour tier) whose first runs found and fixed real
  contrast and landmark defects.
- **Docs wave**: route-doc corrections (intent, architecture, index,
  roadmap), register framing across the dry docs, spec-triage bounds
  sentences, and the automation-advancement review record.
- **Lessons consolidation** (hngh-automation evidence, hngh docs):
  yesterday's and today's process lessons folded to their homes —
  ceremony-loop lessons into autonomous-development-control.md
  (timeout-split ceremonies hand off via a runbook, refusal surfaces
  carry the refusal reason, expected-dirty ledger paths are not skew),
  the ledger append invariant into ledger-and-records-spec.md, two
  backlog rows (gated-red cadence watch fixes; report-queue escalation
  caps), the operator-goals design-pressure paragraph in roadmap Next,
  and the reports.md double-header repaired — the review digest's open
  P1 (alert 31527cac), fixed at the source. Record:
  docs/records/2026-08-28-lessons-consolidation.md.
- **Continuous operation wave** (hngh-automation `362a10a`, `3007081`,
  `3f4ad10`, `6d6e837`, `6e772d9`): budgeted remote GLM leg in the
  model chain (OpenRouter-compatible, key-file gated, daily call cap);
  the research-line lifecycle (beats advance lines
  planned → expanding → contracting → crystallized, crystallizing into
  docs/research/); the overnight work loop (`hngh-overnight.timer`:
  accepted plan step → top queue lane → research beat, executed through
  bridge-gated delegated GLM sessions with post-session critical-path
  audit); Winamp skin v2 (classic base-2.91 tokens, hard pixel bevels,
  visible playlist stripes, LCD insets, square everywhere); the plan
  ledger (docs/project/plans/, operator-authored and operator-accepted,
  machine-executed) with `dashboard/plans.json`;
  docs/design/subsystem-anatomy.md — the body vocabulary rooted in
  Clean Architecture, signals never flowing outward; and the ceremony
  commit landing the subsystem-anatomy update, the
  automation-advancement framing correction (plans are operator-accepted,
  not machine-accepted), and four newly-landed 2026-08-28 research docs
  (log-presentation-patterns, session-cost-display, tech-tree-research-ux,
  telemetry-schema-exemplars; gantt-legibility landed earlier).

### 2026-08-27

#### Added

- **Self-improvement cadence wave** (hngh-automation `34cd275`,
  `232c5fe`): the orphaned 30m and hour cadence tiers wired (systemd
  unit pairs, tick allowlist, make enable/disable); four day-tier
  routines — ledger prune (48h alert retention, archived), daily kernel
  gate check, fresh-eyes review over both repos' last 36h of commits,
  and a daylight research beat (round-robin over
  `research-subjects.txt`) — all fail-closed report-row writers;
  telemetry store v0 (`jobs/telemetry.py`, SQLite WAL, capture-first);
  the schedule and research feeds mounted on the 30m tier.
- **Nerve center unification** (hngh-automation `e04b6be`, `6a5ee15`,
  `f67f972`): the dashboard consolidates into one page with formal tabs
  (Health, Counts, Timeline, Schedule, Queue, Lanes, Agents, Reports,
  Digest, Sessions), fixing dead tabs (a triple state-system collision)
  and a cold-load mount pairing bug. New: session-per-column transcript
  observatory (2,688 parsed conversation entries across 24 omp
  sessions, collapsible thinking/tool blocks, search, redaction),
  unified Schedule view (recurring vs one-off, system backdrop
  compaction, honesty-labelled estimates), `POST /tile` window tiling
  (Phi 62/38 profiles, KWin-snapped, opt-in), and
  `jobs/window-tile.py`.
- **Operator session notes**: `docs/project/session-notes-2026-08-27.md`
  — the day's direction, intent, designs, decisions, and forward work,
  harvested and tagged `[landed]`/`[queued]`/`[decision-pending]`.
- Acceleration wave (four parallel slices, each committed through its own
  certificate loop):
  - `scripts/omp-bridge` closes the roguelike delegation loop:
    `--run-start` gates a delegated session behind hngh admission
    (create-run + admit-transport `:worker`, loadout token/time limits as
    the delegated budget, persistent `OMP_BRIDGE_STORE`), `--run-end`
    closes it with a client-validated disposition; `HNGH_BIN` env seam
    for hermetic tests; suite `tests/scripts/test-omp-bridge.py`
    (9 checks) wired into `make test`.
  - Interface-plan S3: `scripts/hngh status` — one truth-telling spine
    read (verdict-first: `all-clear`/`attention`/`unavailable` from the
    data.json digest + system.json headroom booleans; system/active/next/
    roster panes; `stale (Nm)` freshness; all panes fail closed to
    `unavailable`). Optional sources via `HNGH_STATUS_*` env overrides;
    +37 kernel checks (suite now past 2,851).
  - Interface-plan S1: truth-telling dashboard on the readout spine —
    verdict-first hero + state legend (evacuated = finished & detached),
    display-only `ETA` → `Depends on` rename, reorder-by-usefulness
    (active work floats, stable otherwise), unified `stale (Nm)` pane
    labels, additive `verdict` key on `--json`.
  - `docs/design/display-register-spec.md` — the slow-tier register
    consolidation: one Nihei-register spec (voice/captions, gen-4 measured
    proportions, palette discipline, perceptual-only vocabulary table,
    dosage ladder, future grade hooks), consolidating the dormant
    aesthetic decisions.
  - `.gitignore` now excludes `docs/project/report-bodies/` (write-once
    ledger artifacts, never committed): git porcelain scans drop from
    6,312 rows to 25, speeding every evidence/ceremony/watchdog gate.
- Closed both upstream papercuts flagged by the automation digest:
  - `create-run --store=/missing/dir` (and every command through
    `dispatch-command`) now refuses with `store directory missing: PATH
    (create it first, or drop --store)` exit 2 instead of a raw
    `transport-fault` exit 3; existing stores proceed unchanged, all
    other faults stay faults (+4 checks, suite past 2,855).
  - `scripts/run-autonomous provision_card` no longer turns a prose
    evidence field into garbage candidate paths (the
    node-lattice-admission card wedged every autonomy tick with
    `invalid candidate manifest`, exit 3): only real repo-relative
    paths are kept, prose degrades to the item-id placeholder (+1
    regression test; wedged card removed).
  - `scripts/run-autonomous` defers ceremonies whose card candidates
    are missing from disk (a placeholder card is a declaration of
    intent, not a drivable manifest — the re-wedged
    `hngh-autonomy.service` tick proved the first fix incomplete):
    exit 0 with a deferral line instead of exit 3, card stays mounted
    until real paths replace the placeholder (+1 regression test,
    suite 9).
  - `scripts/report-queue` ledger hygiene: `--add --identity KEY
    [--window S]` collapses repeated entries into one row with a `×N`
    marker and per-occurrence body lines; `--prune --before TS --kinds
    ... [--archive PATH]` removes aged rows/bodies with optional
    archive. Suite 8 → 14 checks. Incident during development: a debug
    repro seded the live reports.md ts cells (~2 min); repaired
    in place (7,083/7,083 rows re-verified against body filenames and
    body meta, 0 mismatches) and the lesson stored
    (`debug-repro-sandboxes-only`).
  - `scripts/report-queue` dedup widened: identity matching now scans
    ALL same-kind rows within the window (newest match wins), not just
    the newest row — multi-identity writers no longer spam duplicates
    (+1 alternation check, suite 15).
  - `jobs/dashboard-self-review.py` + hourly drop-in — Hngh checks its
    own dashboard on schedule: feed freshness vs tiers, feed validity,
    served-marker regression, ledger/body drift; every finding
    classified `unacceptable-now` or `acceptable-for-now` (with the
    planned improvement named), deduped via report-queue identities,
    all-clear ticks silent.
  - Host orientation + retention rungs added to the backlog (new-system
    situating pass; report-ledger rotation policy).
- Closed P1 #1.5: machine-steered course selection extracted from the
  service tick into the pure kernel:
  - `src/domain/course.lisp` — pure `course-candidate` value and the
    fixed written ranking policy (mounted card first, ascending last
    increment with never-incremented most due, queue priority
    tiebreak), with `select-course-candidate` reasons.
  - `src/application/select-course.lisp` + ports — the `select-course`
    use case over `course-selection-ports` (fetch/clock/record),
    accepting only validated candidates, refusing empty sets as
    `no-courseable-lanes`, failing closed on callback faults.
  - `scripts/hngh select-course ID:MOUNTED:TS:RANK...` CLI dispatch
    (exit 0 accepted / 1 refused / 2 malformed) and the
    `course <id>: <reasons>` renderer.
  - `scripts/run-autonomous` now asks the kernel selector first and
    falls back to the internal rule only when the kernel is
    unavailable or refuses (fail-closed, never fabricated).
  - Unit suites `tests/domain/test-course.lisp` and
    `tests/application/test-select-course.lisp` wired into
    `tests/run.lisp`; `make test` green.
- Stood up the four P2 DESIGN contracts (ceremony-ready):
  - `docs/design/command-center.md` — unified CLI+GUI command center
    over one spine, S1–S8 mapping, control + awareness contracts.
  - `docs/design/system-awareness-map.md` — read-only probe
    architecture, `system.json` flow, flap-suppressed alerts,
    headroom thresholds, fail-closed rules.
  - `docs/design/buddy-menu-spec.md` — summoned non-nagging pixel-RPG
    overlay: quest ask, toggles, shortcut lenses, state→animation
    mapping, QML6 delivery over `/tmp/hngh-osd.json`.
  - `docs/design/gamified-runs.md` — runs-as-stories model with the
    closed event vocabulary, the roguelike death rule, and the
    `perceptual:true` honesty leash.
  - Indexed in `docs/architecture-index.md` and the
    `docs/README.md` read order.
- Stage-3 "Roguelike delegation live" wave (hngh-automation
  `9a8d647`, `a004d74`, `b7d78f7`, `e44a09d`, `4ea4bdd`; hngh
  `600b993`), all four stage-3 exit criteria witnessed:
  - Ledger hygiene + hardening: stale-store flap backlog pruned
    (8,876 alert rows archived to the gitignored report-bodies/,
    progress rows untouched), `journal_day` hardened against
    full-ISO `HNGH_TICK_TS` (+1 regression test, suite 11),
    AUTO `.gitignore` runtime markers, gantt theme-read guard.
  - Wrap witnessed live: bridge runs render as observatory
    `working` (terminal states pass through); a real delegation
    cycle ran start → `working` → `cancelled` end-to-end with the
    run visible in `dashboard/sessions.json` at every step.
  - Roguelike auto-replace: a stalled bridge-store run is closed
    `dead`, its record rotates into a timestamped bridge subdir,
    and `omp-bridge --run-start` re-provisions the same mission in
    one unattended tick (hermetic stub test + live seeded stall;
    supervision UTC timestamp parse fixed — local `mktime` skewed
    stall ages by the UTC offset).
  - Per-lane medians + actuals: cadence drop-ins time themselves
    into `logs/drop-in-timing.log`; the time ledger gains
    `dropin:<name>` and `bridge:<slug>` walls (closed runs only —
    hngh close receipts carry no timestamp, mtime is the close
    moment); gantt draws one solid actual bar per anchored lane at
    its real last-run epoch beside the dashed projections
    (source-labelled tooltip; exact lane-unit identity, dense-band
    lanes included; embedded Schedule view now feeds the ledger to
    the engine).
- Third-evening intake folded (eight operator observations):
  `docs/design/ledger-and-records-spec.md` (telemetry/records split —
  SQLite WAL store for high-frequency telemetry, git-tracked docs stay
  curated; session-cost and research-beat capture feeding the Sessions
  columns and the stage-5 tech-tree research view), and
  `docs/design/knowledge-base-spec.md` (markdown vault as canon,
  wiki-grade client-side viewer, thin adapters to whatever the host
  has, publisher choice deferred, story-of-creation curation surface);
  Schedule text-legibility floor added to the display register's grade
  hooks; working-agreement standards noted (ADRs, Diátaxis, Shape Up
  appetite/hill charts, Now/Next/Later); roadmap working order item 5.

### 2026-08-26

#### Added

- Added the autonomy reporting layer:
  - `scripts/report-queue` — append-only report ledger (progress /
    expense / optimization / scheduled / alert kinds) with body files,
    a read cursor, newest-first `--list`/`--unread` table rows, and a
    `--json` dashboard payload.
  - `scripts/run-autonomous` — one no-prompt ceremony tick for the
    hourly cadence: journal generation when absent, one check-in-scale
    ceremony slice when the queue/lane/card gates open (fresh
    `/tmp/hngh-auto-*` store), scheduled reporting, fail-closed exits
    (2 malformed card, 3 refusing sub-step, 0 nothing-due).
  - Hermetic suites `tests/scripts/test-report-queue.py` (8 checks)
    and `tests/scripts/test-run-autonomous.py` (6 checks), wired into
    `make test`.

#### Fixed

- `scripts/generate-publication`: restored the missing `import os`
  (NameError at import; suite 4/4 green again).

- Added the autonomous scheduling & heartbeat layer (the machine-level
  heartbeat pipeline):
  - `scripts/schedule-heartbeat` — one non-daemon scheduler tick that
    reads the queue ledger, probes system preconditions (working tree,
    model route, network, audio), triggers a mounted driver (heartbeat
    cards in `docs/project/heartbeat/`), records a dated heartbeat entry
    with SHA-256 verification, and commits the ledger docs. `--dry-run`
    probes without mutating; `--loop N` re-ticks in the foreground.
  - `scripts/probe-model-route` — one bounded read-only reachability
    probe over the operator reviewer-transport files (local/remote/auto),
    resolving a route choice to a live endpoint.
  - `docs/project/heartbeat-service.md` — cron one-liner and systemd
    user timer specification; the queue's Scheduling section carries
    the cron example.
- Added dynamic model route fallback to the drivers:
  - `scripts/rotate-queue --route=auto|local|remote` resolves the
    reviewer transport by probe when no `--reviewer=` file is given;
    the loadout route label follows the choice.
  - `scripts/worker-driver --route=auto|local|remote` names the session
    compute family (local default); `auto` probes once.
- Extended `scripts/dashboard-readout` with live/export surfaces:
  - `--watch [N]` / `--live [N]` foreground TUI refresh loop;
    `--json` machine-readable spine; `--export-html=FILE` self-contained
    page; live session telemetry read from the operator store through
    `scripts/hngh present` (read-only, bounded, non-fatal).
- Added `scripts/generate-publication` (journal, e-book, site):
  - `--daily [DATE]` compiles `docs/journal/YYYY-MM-DD.md` from the
    verified git/checkin/timeline record (refuses to overwrite an
    operator journal); `--check [DATE]` verifies machine journals;
    `--ebook [DIR]` assembles book.md + a stdlib zipfile EPUB;
    `--site [DIR]` exports the dashboard HTML plus a lane leaderboard.
- Added `scripts/fleet-manager` (device-fleet discovery):
  - `--discover`/`--json` report tailscale peers, per-peer ping state,
    audio/tailscale/D-Bus/interfaces probes; `--wake PEER` sends one
    WOL magic packet for an operator-pinned MAC (unpinned/malformed
    MACs refuse); `--record` appends dated observations to
    `docs/project/fleet.md` and the queue ledger. The source pin
    registry is never touched by a script.
- Added `scripts/ceremony-drive` — a closed ceremony glue for explicit
  file candidates (create-run → admit → deterministic verdict →
  prepare-candidate → commit) used to land the milestone.
- Added the full-screen dashboard TUI (`scripts/dashboard-tui`): a
  textual (rich) read-only TUI with an animated operative, an
  active-lanes panel, and live session tables, fed from the operator
  store through the same read-only renderer as `dashboard-readout`
  (`--watch`/`--live` foreground loop, `--json` spine, `--export-html`).
- Added the interface grading loop (`scripts/grade-interface` +
  `docs/project/ui-grades.md`): a deterministic first-finding grade
  (target + grade + first finding) per interface, feeding every UI
  iteration.
- Added the operative evolution story (`scripts/evolve-operative`,
  generations 1–4/5) with `docs/design/operative-frames.md` (the
  frame/animation spec) and the operative layer framed in
  `docs/design/assistant-interface.md`.
- Added the desktop OSD overlay (`scripts/osd-operative` +
  `osd-operative.qml`): a frameless always-on-top Plasma 6 webview that
  floats the operative above app windows, backed by
  `tests/scripts/test-osd-operative.py`.
- Added backlog tooling: `scripts/backlog-lanes` parses
  `docs/project/backlog.md` into lane rows (json/text, status + date,
  in-queue mapping) for any "active lanes" surface; `scripts/notify-agent`
  is a bounded KDE notification reaction agent
  (`org.freedesktop.Notifications`) that classifies job-search signals
  and appends hits to `docs/project/notify-log.md` — one-shot, no
  daemon, stdlib only.
- Added research docs: `docs/project/integrations-marketplace.md` (where
  Hngh's governance pattern binds to CI, agent harnesses, ops, and
  security tooling, each with a ranked now/next/later first slice) and
  `docs/project/system-harness-roadmap.md` (a resource pool of nodes
  under one governance: pool view, config manager, security manager).
- Added the scheduled-runs investigation record
  (`docs/records/2026-08-26-scheduled-runs-investigation.md`): the
  hngh-automation schedule is healthy (7 systemd user timers firing),
  the cancelled store runs were beacons closed `cancelled` by design,
  and exit-0 runs now close `evacuated`.

#### Changed

- The queue ledger's Scheduling section documents the heartbeat cron;
  the fleet observation record and heartbeat card mounts land in
  `docs/project/`. The dashboard documentation now covers the
  full-screen TUI, the grading loop, the operative evolution, and the OSD
  overlay.

### 2026-08-25

#### Added

- Added the operator reviewer transport (promotion rung 13):
  - `review RUN content-hash=HASH paths=PATH,... [reviewer=PATH]` admits
    an operator reviewer-transport file (endpoint, model, max-tokens,
    timeout, token-file; strict parsing, closed refusals) that replaces
    injected review ports with the real curl-backed provider transport;
    the provider token travels only in the one Authorization header.
  - `hngh.adapters.model:make-model-transports` now works against real
    OpenAI-compatible servers: stdin is a string stream (not a filename),
    the request envelope is a chat message with `enable_thinking:false`,
    and the model's completion document is extracted from the provider
    response envelope by a minimal JSON scanner (`model-response-content`;
    numbers/booleans/nulls consumed opaquely).
  - The rung-6 fixed review prompt carries an explicit advisory-reviewer
    instruction; output contract unchanged.
  - Verified live against the local Unsloth server with Ornith-1.0-35B
    (`status=complete`, closed findings document, `:current` review fact).

- Added the operator pinned-key registry and signature-verification
  transport (promotion rung 12, the "revocation policy refinement" named
  in the roadmap):
  - `hngh.domain` adds the pure `key-pin` value (plain bounded identifier
    plus absolute key path; option-like path components refuse) and the
    immutable `key-pin-registry` (duplicate identifiers refuse, defensive
    copies, `lookup-key-pin`) in `src/domain/attestation.lisp`.
  - `hngh.adapters.federation` adds `parse-pinned-keys` (strict
    `IDENTIFIER<TAB>ABSOLUTE-KEY-PATH` line parser over operator text;
    comments and blanks skipped, everything else refuses),
    `hex-decode` (the pure envelope signature codec), and
    `make-pinned-attestation-ports` (attestation ports that resolve keys
    from the registry and verify signatures through one bounded
    `openssl dgst -sha256 -verify` invocation on the injected process
    transport; no default transport).
  - `verify-attestation RUN FILE [pins=PATH]` admits the operator pins
    file — the trust anchor that replaces injected ports with the real
    pinned registry and process transport; a missing or malformed pins
    file is a malformed invocation. New `list-pins PATH` renders one
    tab-joined line per pinned key through `render-pin-list`.
  - Live proof (RSA-2048/SHA-256 throwaway keypair): a real signature
    verifies `status=verified key=live-key-1` exit 0; a tampered payload
    refuses `bad-signature`; an unpinned key refuses `unknown-peer-key`.

#### Changed

- Root README restated the self-governance claim honestly: the loop is
  the default lane for behavior changes, closed exceptions (the
  dependency guard refusing to certify a no-behavior commit) are by
  rule, and pre-loop history is recorded rather than rewritten as
  ceremony. Fixed the stale check-count line (now "a suite past 2,690
  checks; the run prints the current number") and expanded the
  `Where this is going` section with the node-lattice megastructure
  vision (small ledgered machines sharing learned facts, wake-on-demand,
  persistent tunnels without a watching daemon, evidence-first
  admission of low-powered peers).

#### Added

- Ed25519 signature-transport hardening (promotion rung 14): the pins
  file gains an optional closed ALGORITHM column
  (`rsa-sha256` default, `ed25519` admitted; unknown, empty, or extra
  columns refuse), the `key-pin` domain value carries the algorithm, and
  signature verification routes per pin — digest signatures via
  `openssl dgst -sha256 -verify`, raw Ed25519 signatures via
  `openssl pkeyutl -verify -pubin -inkey -rawin -sigfile -in`.
  `list-pins` renders each pin's resolved algorithm. Verified live end
  to end with a real Ed25519 keypair (`status=verified key=ed-key` exit
  0; tampered payload refuses `bad-signature`) and committed through the
  self-governed ceremony (chore export lane for `src/packages.lisp`,
  excluded by the dependency guard; candidate commit bound to the
  implementation and tests).

- Network claim method (promotion rung 15): `+federation-methods+` gains
  `:http-claim` (carrier-bundle and http-claim are the closed method
  set; anything else still refuses at request construction).
  `fetch-evidence RUN peer=ID [method=carrier-bundle|http-claim]
  [max-facts=N]` accepts the closed method option (unadmitted methods
  are malformed exit 2); the transport sees the method on the request,
  and the peer remains a plain identifier with endpoint resolution
  transport-owned — no default wire. Verified live over a real local
  HTTP server through an injected transport (`status=complete` with the
  closed claim states) and committed through the self-governed ceremony.

- Operator policy profiles (promotion rung 16): the domain gains the
  pure `evidence-profile` value (principle → permitted requirement
  kinds; duplicate principles and non-closed kinds refuse) and
  `evaluate-policy-proposal-under-profile`, which narrows a proposal's
  requirements to a listed principle's permitted kinds — a profile only
  narrows, never broadens. The requirement-kind vocabulary admits
  `:review`, so a profile can demand review evidence; `propose` gains
  `profile=PATH` (strict `PRINCIPLE<TAB>KIND` lines; missing or
  malformed files are malformed invocations). Committed through the
  self-governed ceremony (chore export lane for `src/packages.lisp`).

- Wake-on-demand (promotion rung 17): `wake-peer RUN PINS-FILE PEER`
  issues one explicit wake request for a pinned lattice peer behind an
  injected transport. The pins registry is the admission evidence; the
  transport receives `(PEER KEY-PATH)`; a zero exit issues, a nonzero
  exit refuses `wake-refused`, a throw faults `wake-fault`; an unpinned
  peer refuses `unknown-peer-key` before any transport call. No default
  transport — without injection the command refuses
  `no-wake-transport`. Committed through the self-governed ceremony
  (chore export lane for `src/packages.lisp`).

- Machine-checked self-governance (2026-08-25): the README's restated
  claim is now falsifiable by construction.
  `tests/scripts/test-loop-history-guard.py` walks every code-surface
  commit since the restatement `1915713` and fails the gate on any
  commit that is neither `hngh: candidate <hash>` nor labeled
  `(excluded from cert manifest by dependency guard)`. The carve-out is
  recorded as a decision entry in `docs/project/decisions.md`, with the
  one pre-guard violation (`915e0e3`, comment-only) named rather than
  rewritten. Committed through the self-governed ceremony.

- Bounded read-only worker task (promotion rung 18): the worker-rung
  first slice. `hngh.adapters.worker` supplies a closed `worker-request`
  (bounded task label plus optional bounded payload), `worker-ports`
  (one injected `execute-worker` callback, no default transport), and
  `run-worker-task`, which binds a `:worker` `:current` evidence fact
  on a zero exit and refuses/faults closed otherwise. `:worker` joins
  `+admitted-transports+` behind the `worker-task` tool label on the
  run loadout; `run-worker RUN task=LABEL [payload=TEXT]` is the
  operator surface. A worker self-report is evidence, never acceptance,
  and a worker never carries a mutation certificate. Committed through
  the self-governed ceremony (chore export lane for `src/packages.lisp`).
- Live worker proof (2026-08-25): the full cycle ran through the
  dispatch surface with a real subprocess worker transport —
  create-run (worker-task label) → admit worker → run-worker
  (`worker status=complete task=scout candidates`) → present — with
  the `:worker` `:current` evidence fact bound from real output.
- Continual-worker driver (2026-08-25): `scripts/worker-driver` runs
  the one-shot worker cycle as a single explicit invocation
  (`--store=PATH OBJECTIVE TASK [PAYLOAD]`: create-run with the
  worker-task label → admit worker → run-worker → close). It is glue
  over the existing dispatch surface, adds no transport or authority,
  and the periodic invocation stays with the operator's scheduler.
  Committed through the self-governed ceremony.

- Queue rotation (2026-08-25): `scripts/rotate-queue` closes one
  queued item through the full loop — queue-row flip, real evidence,
  a real local-model review via the operator reviewer file, a
  ten-principle proposal, certificate binding, and the certificate-
  bound commit. The first rotation (doc-sync-loop, the doc-numbers
  guard) ran live end to end: review `status=complete findings=4`
  (advisory), verdict admitted 10/10, `git add` + `git commit`
  executed as `hngh: candidate bbd1d598…`, queue ledger flipped in
  the same commit. The queue ledger lives in
  `docs/project/queue.md`; a scheduler (operator-owned) may invoke
  rotate-queue periodically.

### 2026-08-24

#### Added

- Added the distributed attestation & evidence federation slice (promotion
  rung 11):
  - `hngh.domain` adds the pure `remote-attestation` envelope value and the
    closed structural checker `verify-attestation-shape` plus `utc-string-p`
    in `src/domain/attestation.lisp` (no clock, no network, no key store).
  - `hngh.adapters.federation` is a bounded federation adapter with two
    injected-port entry points: `gather-federated-evidence` reads an
    operator-carried carrier bundle through the `fetch-remote` callback and
    maps its claims into domain evidence facts with the closed
    evidence-state vocabulary (`:current` when locally re-hashable,
    `:unverifiable`, `:malformed`, `:missing`, `:conflicting`); and
    `verify-remote-attestation` runs the kernel shape gate, resolves the
    signing key against the operator-pinned list, checks the signature
    through `verify-signature`, and checks the expiry window against the
    injected `now`, binding a `:remote-attestation` fact only on a fully
    verified envelope. The closed refusal taxonomy names `unknown-peer-key`,
    `bad-signature`, `signature-fault`, `malformed-attestation`,
    `malformed-expiry`, `expired-attestation`, `attestation-clock-skew`,
    `transport-fault`, and `output-too-large`.
  - `hngh.domain:+admitted-transports+` is now
    `(:filesystem :model :terminal :federation)`;
    `hngh.domain:+evidence-requirement-kinds+` gains `:remote-attestation`
    and `:federated-claim`.
  - `hngh.application:admit-transport` admits `:federation` only under a
    loadout carrying the `remote-evidence` network label or the
    `carrier-bundle` tool label, else the closed
    `loadout-refuses-transport` refusal.
  - `hngh.main:dispatch-command` gains `fetch-evidence` and
    `verify-attestation`, threaded through `&key federation-ports
    attestation-ports` with no defaults: un-injected, the operations refuse
    `no-federation-transport` / `no-attestation-transport`, so plain
    `scripts/hngh` never touches a wire; both serve only a run holding a
    `:federation` admission receipt.
  - `hngh.presentation` adds the two outward renderers
    `render-federation-result` and `render-attestation-result`.
  - Test suite `tests/adapter/test-federation.lisp` and updated vocabulary
    coverage in `tests/domain/test-governance.lisp` (closed transport set)
    and `tests/domain/test-governance-properties.lisp` (requirement kinds).
- Added the bounded model and terminal worker transports (promotion rung
  10): `hngh.adapters.model:make-model-transports` returns the transport
  `complete` callback shape so the existing bounded review adapter can
  drive a real provider (advisory only, no default provider);
  `hngh.adapters.terminal` captures one bounded operator statement as a
  `:terminal` evidence fact with an in-process SHA-256 fingerprint
  (advisory only, no subprocess, no default input);
  `hngh.domain:+admitted-transports+` is now `(:filesystem :model :terminal)`
  and `hngh.application:admit-transport` reuses the run loadout for the two
  new kinds (`:model` needs a non-`local` route plus the `model-review`
  network label; `:terminal` needs the `terminal-input` tool label) with
  the closed `loadout-refuses-transport` refusal;
  `hngh.main:dispatch-command` gains the `review` and `terminal` operations,
  both fail-closed without injected ports
  (`no-review-transport`/`no-terminal-transport`) and both served only to a
  run holding the matching admission receipt;
  `hngh.presentation` adds the one outward renderer `render-operator-result`.
- Added the operator-facing command surface and transport admission (promotion rung 8):
  - `hngh.domain:+admitted-transports+` (`(:filesystem)`) in `src/domain/governance.lisp`.
  - `hngh.application:admit-transport` in `src/application/admit-transport.lisp` creating `:admission` receipts with facts `transport`, `scope`, `route`, `run`, and `timestamp`.
  - `hngh.adapters.filesystem` in `src/adapter/filesystem.lisp` recording canonical run-and-receipt lines under an explicit `--store=PATH` without domain imports.
  - `hngh.main:dispatch-command` exposing the 7 CLI operations (`create-run`, `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`, `present`) with a closed exit code protocol (0 accepted, 1 refusal/conflict, 2 malformed, 3 fault).
  - `scripts/hngh` executable SBCL wrapper.
  - Test suites: `tests/application/test-admit-transport.lisp`, `tests/adapter/test-filesystem.lisp`, `tests/main/test-dispatch.lisp`.
  - Record: `docs/records/2026-08-24-command-surface-and-transport-admission.md`.
- Added the operator governance command surface for the dogfood loop
  (`scripts/hngh`, promotion rung 9):
  - `propose [key=value...]` forms a closed `policy-proposal` from operator
    fields and renders the deterministic `policy-verdict` (0 admitted,
    1 refused with labels, 2 malformed).
  - `issue-cert ACTION RUN [PATH...]` reads the stored run from `--store`,
    binds repository identity/base revision/candidate paths to it, and mints
    a candidate certificate under an admitted verdict (refuses runs without
    an admission receipt).
  - `mutation-check ACTION RUN [EVIDENCE...]` builds fresh fixture evidence
    and executes the certificate-bound mutation through injected ports, so
    the loop runs fully in-process with no subprocess (0 executed, 1
    mismatch/refused, 2 malformed, 3 transport fault).
  - `hngh.main:dispatch-command` gained a `:mutation-ports` injection key;
    test suite `tests/main/test-governance-dispatch.lisp` asserts no real
    process is ever spawned.
  - Record: `docs/records/2026-08-24-command-surface-dogfood.md`.
- Completed the first self-governed development loop (promotion rung 9):
  Hngh proposed, reviewed, certified, and committed its own documentation
  change (`propose`, `issue-cert`, `mutation-check` against live repository
  evidence), then pushed the certificate-bound commit to origin.
  Record: `docs/records/2026-08-24-first-self-governed-commit.md`.
- Completed the second self-governed development loop: Hngh proposed,
  certified, staged, gated, and committed its own adapter bug fixes
  (`process-run-at` value-order; certificate path sorting) under a real
  evidence certificate (`33b8d94 hngh: candidate 1befdda9...`), then pushed
  to origin. Record: `docs/records/2026-08-24-second-self-governed-commit.md`.
- Added exhaustive governance property tests (backlog item): totality
  over the 7 proposal classes x 21 evidence-requirement kinds (147
  combinations; absent-matrix-principle refuses rather than errors) and
  monotonicity of the deterministic evaluator (ignoring evidence never
  flips refused to admitted; single- and double-ignore exercised).
  suite total 2353 checks. Record:
  `docs/records/2026-08-24-governance-property-tests.md`.
- Recorded the 2026-08-24 prior-art research session:
  `docs/records/2026-08-24-prior-art-landscape.md` maps the closest prior
  art (Progent arXiv:2504.11703 closest, CaMeL arXiv:2503.18813,
  AgentSpec arXiv:2503.18666), the four deliberate divergences from
  in-toto/SLSA/DSSE (no PKI / hash self-certification, duplicate facts
  refuse, moment-of-action freshness recheck as a novel property, no
  multi-party machinery), the adopted invariants (monotonicity, deny with
  structured reason, totality over closed kinds, DSSE as a YAGNI-gated
  future export grammar), harness-landscape positioning (Claude Code,
  Codex CLI, mini-swe-agent, Aider, OpenHands/ACP), the no-public-
  governance-benchmark gap, and the strategy sequencing ending in
  federation as a scope-broadening proposal class.
- `docs/project/decisions.md` records the no-PKI / hash self-certification
  stance as a single-machine decision with an explicit revisit trigger:
  multi-machine evidence sharing.
- `docs/project/backlog.md` gains four entries: governance property tests
  (matrix totality over closed kinds plus monotonicity), a DSSE envelope
  export serializer (YAGNI-gated), a governance-benchmark research lane
  (AgentDojo / InjecAgent / R-Judge prior-art scan; tamper-evidence,
  approved equals executed, reconstruction-from-record metrics), and the
  dogfood loop as a future rung candidate (Hngh proposes, evaluates, and
  commits changes to itself via its own harness). Documentation only; no
  source or behavior change.


### 2026-08-19

#### Changed

- Root README `Why` and `Where this is going` rewritten to frame Hngh as a
  growing system harness: the Why contrasts Hngh's record-first posture with
  the throughput-first agent-harness mainstream (grounded in a 2026
  empirical study of 70 agent-harness projects and the 2026-07-28 stateless
  MCP update), and Where-this-is-going names the corridor: local and remote
  models, priced routes, pooled hardware, all behind the same bounded, recorded,
  human-closable cycle. Documentation only; no source or behavior change.

- Retired the `make check-archive` archive gate and the archive-boundary
  framing: the external retirement archive is historical evidence only, no
  active gate verifies it, and meaningful archive material is harvested
  into the operator's separate llm-wiki knowledge base. The archive itself
  is untouched. Makefile and documentation only; no source or behavior
  change.


### 2026-08-18

#### Added

- A read-only evidence adapter (promotion rung 4): a fixed, enumerable set of
  read-only local evidence commands — repository revision, whole-tree
  working-tree status, and file content hashing — gathered through an
  injected process transport and mapped to domain evidence facts and source
  manifest entries with closed states; unknown commands, malformed output,
  escaping targets, and duplicate evidence fail closed, and the adapter
  never decides policy or mutates anything.

- A fixture-backed mutation executor (promotion rung 5): `hngh.adapters.mutation`
  rechecks every certificate fact against fresh evidence and emits only the
  certificate-bound fixed Git action through an injected transport; stale facts,
  expiry, disabled actions, malformed evidence, command failures, and transport
  faults refuse without mutation.

- A fixture-backed bounded model-review adapter (promotion rung 6):
  `hngh.adapters.review` sends one closed review request (candidate paths, content
  hash, policy-context labels) through an injected reviewer transport and maps the
  model's structured output into sanitized, duplicate-free finding labels and
  citations plus one deterministic review evidence fact. Malformed JSON, unknown
  fields, unsafe citations, oversized or overlong findings, duplicate labels, and
  transport faults refuse closed; a failed review call becomes an `:unverifiable`
  fact. Reviewers advise, never decide; the adapter is pure (no provider defaults,
  no network, no subprocess calls).

- An operator-visible presentation layer (promotion rung 7):
  `hngh.presentation` renders application results, runs, receipts, evidence facts,
  policy verdicts, candidate certificates, and installed adapter results into
  plain factual strings without mutating canonical state or importing an adapter;
  refusals stay literal, and the optional reference lexicon applies display copy
  only at a named surface and can never carry canonical control.

- A composition root (promotion rung 7): `hngh.main` composes the five use cases
  into one `run-harness` with injected or fail-closed default port adapters
  (in-memory record store, per-harness identifier source, clock, and `unknown`
  admission, verification, and manifest evidence), wires the installed evidence,
  mutation, and review adapters through injected transports, keeps an
  operator-visible in-memory record root, and renders every result through
  `hngh.presentation`. It starts no background work by import and supplies no
  default model or terminal transport.

- Public read-only accessors on domain run and receipt values
  (`run-identifier`, `run-mission`, `run-role`, `run-loadout`, `receipt-kind`,
  `receipt-facts`) so presentation renders without touching canonical state,
  and a dependency-guard extension that rejects any inward package importing an
  adapter.

#### Changed

- Root README, documentation index, and roadmap now frame Hngh's intent and
  direction in plain language, recovered from the archived pre-refactor plans;
  added `docs/intent.md` as the human-facing vision document. Documentation
  only; no source or behavior change.


### 2026-08-17

#### Added

- Pure governance values for closed proposal, principle, failure, evidence, and
  verdict vocabulary; they remain non-authoritative policy data.

- A deterministic proposal-evidence-ledger policy: closed requirement kinds
  bind evidence facts to principles without making fact producers or adapters
  domain policy.

- A deterministic principle evaluator over the proposal ledger: ten
  matrix-ordered principle results and closed refusals for missing, stale,
  malformed, conflicting, or unverifiable evidence; `:admitted` only when every
  principle passes.

- A closed failure-disposition policy: each of the eight failure categories
  maps to one deterministic disposition, unknown categories refuse, and
  conditional rows resolve to their primary default.

- A non-mutating candidate authorization certificate: an immutable value
  binding one closed action plus the admitting verdict and recorded facts,
  minted by a pure mechanical issuer.

- The policy-gated `close-run` use case: a run reaches a terminal state only
  under an `:admitted` policy verdict, with closed transition refusals and one
  atomic run-and-receipt record.


### 2026-08-12

#### Added

- A read-only, fixture-tested Common Lisp parenthesis guard in the fast gate.

- A pure run domain with validated mission, role, loadout, lifecycle, and
  evidence values.

- A pure application create-run slice with explicit identifier, clock, and
  atomic recording capabilities.

- A pure application arm-run slice with explicit admission facts and atomic
  recording capabilities.

- A pure application start-run slice with one atomic transition recording
  capability.

- A pure application checkpoint slice with closed verification and manifest
  evidence callbacks plus one atomic transition recording capability.

- A policy-only autonomous-development-control design: source-grounded
  principle evaluation, closed proposal and authorization classes, bounded
  reviewer challenges, and certificate-gated future mutations.

- A read-only candidate evidence bundle with an explicit manifest, fixed local
  checks, whole-tree observation, hash-bound output, and closed refusals for
  unsafe or out-of-scope input.

#### Changed

- Routine design, review, and future mutation decisions move from
  approval-by-perception to source-grounded, fail-closed certificates; human
  approval is a deployment profile.

- Application callback failures now refuse at the invocation boundary while
  domain and application errors remain visible to the test gate.


### 2026-08-11

#### Added

- Compact, side-effect-free kernel baseline with explicit profile validation.

- Compact active documentation and cutover record.

- Clean Architecture charter, component map, test boundary, and
  presentation/reference-lexicon boundaries.

- Fixture guards for inward dependency direction and renderer-only lexicons.

#### Changed

- Retired the previous daemon, plugin, watcher, dashboard, mission-control,
  launcher, and unit architecture into an external local archive.
