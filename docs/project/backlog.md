# Backlog

> **archived 2026-09-25: folded into queue.md** — no further writes.

No runtime feature is admitted before its policy proposal and required run-domain
or application contracts are fixture-backed. A proposal must name its problem,
smallest useful outcome, source manifest, principle matrix, risk note,
dependency, and evidence trigger.

Potential future work belongs here only with a problem statement, smallest
useful outcome, source or evidence, risk note, dependency, and review trigger.

## Pi read-only delegation spike

- **Problem:** Hngh has no admitted disposable agent worker, while future
  source-grounded reconnaissance and independent review need a bounded worker
  substrate.
- **Smallest useful outcome:** a manually launched Pi RPC worker in a disposable
  directory can run one fixture-backed, read-only scout or reviewer task with
  an explicit route, no session persistence, no ambient discovery, no mutation
  tools, and a bounded receipt.
- **Evidence:** `docs/records/2026-08-13-pi-worker-and-delegation-survey.md`.
- **Risk:** third-party extensions execute in the Pi worker process and Pi tool
  policy is not OS-level isolation; provider and search credentials, session
  state, child processes, and recursive delegation must remain unavailable by
  default.
- **Dependencies:** a Pi adapter proposal; a process/environment isolation
  design; fixture fakes for the application ports; a cost/loadout policy; and
  the eight fixture gates named by the Pi survey.
- **Review trigger:** an independent reviewer accepts the fixture results,
  child-process cleanup proof, route/cost receipt, and unchanged fixture
  repository manifest. A successful worker self-report is not acceptance.

## Node lattice rung (megastructure mesh)

- **Struck 2026-09-24:** absorbed by queue row node-lattice-admission, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Certificate-bound wake mutation lane (boundary amendment)

- **Struck 2026-09-24:** absorbed by queue row wake-mutation-lane, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Ambient-free tunnel keepalive (boundary amendment)

- **Struck 2026-09-24:** absorbed by queue row tunnel-automation, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Governance property tests — COMPLETED (2026-08-24)

completed; history in git + records (folded 2026-09-24)

## DSSE envelope export serializer

- **Struck 2026-09-24:** absorbed by queue row dss-e-export, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Governance-benchmark research lane

- **Struck 2026-09-24:** absorbed by queue row governance-benchmark, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Dogfood loop — COMPLETED (promotion rung 9, 2026-08-24; hardened by the loop-history guard 2026-08-25)

completed; history in git + records (folded 2026-09-24)

## Operator policy profiles — COMPLETED (promotion rung 16, 2026-08-25)

completed; history in git + records (folded 2026-09-24)

## Bridge-backed continual worker (worker-rung candidate)

- **Problem:** the intent document names a worker behind a port — "likely
  one called Pi" — and the bridge now surfaces the worker lane
  (`hngh_run_worker`, `worker-driver`), but no agent thread yet drives
  the full governance loop through the bridge end to end, and the only
  continual workers are the shell jobs in hngh-automation.
- **Smallest useful outcome:** a disposable, read-only worker omp session
  (local Ornith/Qwen via the automation's own model chain) that can
  open one run, gather read-only candidate evidence, run one `review`
  through the operator reviewer transport, and close the run — driven
  through the hngh-omp bridge tools, with the run ledger as the record.
- **Evidence:** `docs/records/2026-08-13-pi-worker-and-delegation-survey.md`
  (Pi survey); hngh-omp plugin scaffold; rung-13 reviewer transport.
- **Risk:** the worker is read-only by default and never carries a
  mutation certificate; a worker self-report is not acceptance.
- **Dependencies:** the bridge plugin (present); rung-13 operator
  reviewer file (present); a loadout that admits `:model` transport.
- **Review trigger:** an independent reviewer accepts the disposable
  worker's run receipt, its review evidence, and an unchanged fixture
  manifest — the same gates the Pi survey named.

## Node-lattice admission rung (implementation) — queued 2026-08-25

- **Struck 2026-09-24:** absorbed by queue row node-lattice-admission, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Documentation-sync loop — queued 2026-08-25

- **Struck 2026-09-24:** absorbed by queue row doc-sync-loop, 2026-09-24 (stale "queued 2026-08-25" state folded: the queue row went done 2026-08-25; proposal prose removed as a duplicate; last commit containing the removed content: bd2c1cee).

## Night-agent plan authoring (plan-supply) — queued 2026-08-30

- **Problem:** plans are operator-authored (suite doc 08 R2); when the
  plan queue emptied after the 2026-08-28 evening-selfdev plan
  executed, the machine idled for 40h+ — zero kernel commits after
  `667a36b` (2026-08-28T19:46Z) through 2026-08-30T12:30Z, the hourly
  workbeat re-announcing the same lane with no plan to feed it
  (reports.md rows `f27e3532`, `9b362832`), and overnight budget
  digests at sessions=0.
- **Smallest useful outcome:** the overnight loop gains a
  plan-authoring leg that drafts one normal-risk plan per night from
  open backlog rows, deduplicated alert rows, and crystallized
  research lines, filing it under `docs/project/plans/` as
  `status=drafted`; the operator accepts or rejects each morning and
  the existing accepted→executed machinery runs unchanged.
- **Evidence:** docs/project/plans/ (last plan 2026-08-28);
  docs/records/2026-08-30-lessons-and-foldback.md §1–§2; the 2026-08-28
  evening-selfdev plan as the proof that one good plan converts to a
  full night of verified work.
- **Risk:** an authored plan is a proposal, never authority —
  acceptance stays operator-owned; the standing rule forbidding
  machine sessions from kernel src/tests/Makefile stays.
- **Dependencies:** the plan ledger and dashboard (`dashboard/plans.json`,
  landed 2026-08-28); the backlog lane parser.
- **Review trigger:** an operator accepts one machine-drafted plan and
  its execution passes both repos' gates unattended.

## Alert → plan-candidate routing — done 2026-09-01

- **Struck 2026-09-24:** absorbed by queue row alert-plan-routing, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Bridge-as-operator-host — queued 2026-08-25

- **Struck 2026-09-24:** absorbed by queue row bridge-operator-host, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Evidence-freshness + key-rotation rung — queued 2026-08-25

- **Struck 2026-09-24:** absorbed by queue row key-rotation-freshness, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Gantt ports (gantt-ports) — interface-expansion rung

- **Problem:** one dashboard readout is a fine start, but the operator
  wants gantts like they want weather: all kinds. Axial and circular
  clock-face rings, animated spirals, wobbling, dancing, "crazy" —
  the whole instrument panel should be portable to any gantt dialect
  the operator fancies, each reading the same committed timeline
  spine.
- **Smallest useful outcome:** the readout gains a `--style` switch
  with (at least) `linear`, `circular` (clock-face rings), and
  `spiral` (already exists) renderers, all over the same spine; each
  renderer smoke-tested like `--spiral` is today.
- **Evidence:** `scripts/dashboard-readout` (linear + spiral both
  live); the timeline spine (`docs/project/timeline.md`) + ETA
  windows as the shared data.
- **Risk:** rendering options multiply — keep each style a tiny pure
  function over the same rows; don't let styling infect data.
- **Dependencies:** the dashboard-readout spine (present); each new
  style is check-in-scale.
- **Review trigger:** an independent run of each style renders the
  same rows/ETAs, and the smoke test covers every style (fails on a
  missing/renamed renderer).

## Dancing interfaces (dancing-ui) — the music runs the room

- **Problem (deliberately weird):** interfaces are static; the
  operator wants the whole system to *dance in time to music playing
  on the machine*, intensity varying with the track — a UI that
  breathes, pulses, and glides with the beat. Pure delight; it must
  never obscure the data.
- **Smallest useful outcome:** one probe reads the system's audio
  signal (pulse audio/pipewire intensity, or when unavailable a
  constant BPM/no-op) and maps it to an intensity value; the
  dashboard applies it as a set of `--dance` amplitude classes
  (subtle pulse on the ETA bars). A human can toggle it off; it never
  changes a decision.
- **Why probe first:** feasibility (reading system music, mapping to a
  UI amplitude) before committing the full dance to all interfaces.
- **Risk:** music-driven motion must not become motion-sickness or
  performance drag; it is a display-only layer under the pass-thru
  data, no daemon.
- **Dependencies:** the dashboard-readout; the audio source probe.
- **Review trigger:** an independent reviewer accepts that the `--dance`
  mode pulses to an injected fake intensity, is disabled by default,
  and renders the data identically when off.

## Project journal + daily narrative (journal-daily)

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## Long-form ebook: the megastructure memoir (ebook longform)

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## Self-hosted public surface (public-surface rung)

- **Problem:** the operator wants a public web on their own cloud
  (budget-scaled) — blog posting, comment collection/moderation,
  organization of practical interfaces to remote Hngh instances,
  leaderboards, and interaction between Hngh users/instances.
- **Smallest useful outcome:** one static+tiny-server site — journal
  posts (from journal-daily), a comment intake (moderated), a public
  readout of the Hngh queue (the dashboard), and a
  leaderboard-like "instances" page — self-hosted on a cheap VPS.
- **Evidence:** dashboard-readout (has the data), journal-daily, the
  self-funding scan.
- **Risk:** a public surface is a responsibility — moderation and
  rate-limits first; never expose secrets/stores.
- **Dependencies:** journal-daily, dashboard-readout, a hosting plan
  (budget-scaled).
- **Review acceptance:** the site serves the journal + readout from
  committed data, has a moderated intake, and no Hngh store is
  exposed.

## Device fleet bring-up (device-fleet)

- **Problem:** old hardware (an Android phone, a Steam Deck, a tired
  laptop with a slow NIC) can become local helper peers for Hngh's
  network and hardware-resource work.
- **Smallest useful outcome:** each device joins the local tailnet +
  an Hngh node (wake-peer ready), contributing bounded facts (uptime,
  load, network state) as evidence, with the same admission rules as
  the node lattice.
- **Evidence:** the node-lattice rung; wake-on-demand; the fleet
  vision.
- **Risk:** unattended low-power peers need the evidence-freshness /
  key-rotation story first.
- **Dependency:** node-lattice admission, key-rotation-freshness.
- **Review acceptance:** a device's facts appear in a ledger and it
  can be wake-peer'd under a certificate.

## Self-publishing / royalties pipeline (royalty-pipeline)

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## Funding rails (funding-rails) — bootstrap income

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## Royalty catalog APIs (royalty-apis)

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## Interface mocks (interface-mocks) — the mock matrix lane

- **Problem:** the operative layer is an interface *family* (panels,
  TUI, overlay, web, Emacs-style surface, voice), but only the TUI is
  real; the others are unproven concepts. We need cheap, graded mocks
  to pick which surfaces earn a build.
- **Smallest useful outcome:** one compact llm-trim-style panel mock
  (menubar/card popover), then the KDE overlay operative — each run
  through the automated interface grading loop before the next.
- **Dependencies:** the `grade-interface` loop (landed); the family
  matrix in `docs/design/assistant-interface.md`.
- **Review trigger:** an independent reviewer accepts the graded mock
  screenshots and ledger rows, not just the code.

## Operative overlay (operative-overlay) — qml6 floating operative

- **Problem:** the operative should float above the desktop — sprites,
  speech, buttons, scrolling text — not live only in a terminal. A
  plasmoid draws *under* windows; a standalone qml6 window is the
  correct X11 recipe.
- **Smallest useful outcome:** a frameless always-on-top transparent
  qml6 window showing the operative as an `AnimatedSprite` sprite
  sheet with speech, graded by the loop.
- **Dependencies:** the sprite-sheet assets (`pixel-agent-assets`);
  qt6-declarative (present); a research record exists.
- **Review trigger:** an independent reviewer accepts a captured
  overlay frame with a ledger grade and no daemon.

## Operative voice (operative-voice) — local character voices

- **Problem:** the operative is silent; speech should be a local,
  character-driven *rendering* of the textual record, never a gate.
- **Smallest useful outcome:** 3–5 distinct local neural TTS voices
  (piper / kokoro-82m) plus STT (whisper.cpp / sherpa-onnx) with
  push-to-talk, each operative persona voiced; record stays textual.
- **Dependencies:** a chosen TTS engine; the tts-research record.
- **Review trigger:** an independent reviewer accepts a rendered
  speech sample matching the persona, with the textual record
  unchanged.

## Pixel-agent assets (pixel-agent-assets) — the sprite sheet lane

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## CI governance gate (ci-governance-gate)

- **Problem:** CI failures surface as unstructured logs; nothing
  parses or resolves them, ceremonies do not auto-complete, and a
  pending commit can sit unevaluated. The operator wants any CI
  failure parsed and resolved through the governance loop, no pending commit
  left un-evaluated.
- **Smallest useful outcome:** a GitHub Actions adapter consumes an
  exported failure log as downstream evidence, runs the dogfood
  governance loop to complete or reject the pending commit, and refuses to
  re-run until the event is governance-resolved.
- **Evidence:** the ceremony-drive script and the promotion rung 18
  worker evidence fact; this entry.
- **Risk:** CI logs are untrusted input; parsing must refuse closed
  on malformed or oversized logs; the gate must not become an ambient
  watcher (operator-owned cron and state, no daemon).
- **Dependencies:** the governance loop (rung 9); a Gitea/Forgejo
  Actions second adapter once a pinned peer really runs Forgejo.
- **Review trigger:** an independent reviewer accepts a fixture where
  a failure log maps to one certificate-bound completion or rejection
  and a re-run refuses without a new event.

## Resource pool view (resource-pool-view)

- **Problem:** the fleet (local plus wide-area machines) is not yet a
  single pool; per-node status, duty, health, and capabilities are not
  surfaced together.
- **Smallest useful outcome:** one on-demand dashboard panel listing
  each admitted node as a row with status, duty, health, and
  capabilities; no ambient collector — the operator-owned heartbeat
  tick refreshes it.
- **Evidence:** the node-lattice groundwork (pinned peers, wake-peer,
  attestation); `dashboard-readouts`; this entry.
- **Risk:** rows must trace only pinned, evidence-backed claims; a
  node stays untrusted until pinned through the existing governance loop.
- **Dependencies:** node-lattice admission (`node-lattice-admission`),
  `pooled-hardware`, the dashboard panel machinery.
- **Review trigger:** a reviewer accepts a rendered pool page whose
  rows all trace to pinned, evidence-backed claims.

## Config manager (config-manager)

- **Problem:** system configuration is edited in place; rollouts are
  not evidence-backed or reversible.
- **Smallest useful outcome:** a per-node declared-config bundle whose
  intended state after apply is read back into evidence, a
  certificate-bound apply, and reversibility by reverting the
  declaration.
- **Evidence:** the mutation executor (`:commit` action); the worker
  substrate; this entry.
- **Risk:** configuration changes are high-band actions — the apply
  must recheck every evidence fact at the moment of mutation, and the
  revert path must exist without an untracked daemon.
- **Dependencies:** the mutation executor, the per-node worker,
  optional model patterns (NixOS, home-manager, apt-adjacent).
- **Review trigger:** an independent reviewer accepts a fixture where
  an applied and reverted config binds to evidence facts and a drift
  from the declared bundle refuses.

## Security manager (security-manager)

- **Problem:** key rotation freshness, secret hygiene, patch-state
  evidence, and incident-response evidence chains are not surfaced
  across nodes.
- **Smallest useful outcome:** per-node patch-state and key-freshness
  evidence rows (vintage of the secret scan, date of last rotate,
  patch delta) as machine-checkable facts; incident response is a
  transparent event-to-record-to-certify chain.
- **Evidence:** the `key-rotation-freshness` workload;
  `secret-scan-report`; this entry.
- **Risk:** patch and rotate metadata is perishable and must carry its
  own evidence; freshness attestations are easy to fake if the chain
  is not pinned.
- **Dependencies:** the resource pool view; the key-pin registry
  (rung 12).
- **Review trigger:** a reviewer accepts a freshness or secret finding
  that, alone or in a chain, refuses to certify a stale key.

## Notify agent (notify-agent)

- **Problem:** mail and job-search signals sit in inboxes; nothing
  reacts. The preparatory agentic work (draft a reply, first evidence,
  governance proposal) is manual.
- **Smallest useful outcome:** a KDE notification reaction agent —
  via `org.freedesktop.Notifications` and the probed notification
  daemon — receives an event and prepares a draft reply, evidence, and
  a governance proposal.
- **Evidence:** the desktop overlay and notification-daemon research;
  the tts/voice `omp say` note; this entry.
- **Risk:** notification payloads are untrusted UI content; the agent
  must treat them as hints, never as authorization, and stay
  operator-confirmed before any external side effect.
- **Dependencies:** a bounded reaction worker (Pi survey and the
  rung-18 worker); push via ntfy / Apprise as a follow-on.
- **Review trigger:** a reviewer accepts a fixture where a
  notification maps to a prepared, non-mutating artifact and never
  fires an ambient action.

## Push self-sufficiency (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row push-self-sufficiency, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Credential rotation automation (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row credential-rotation-auto, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Cadence continuum (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row cadence-continuum, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Activity cadence (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row activity-cadence, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Governance vocabulary (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row governance-vocabulary, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Agent live view (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row agent-live-view, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Surface evolution loop (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row surface-evolution-loop, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Machine-steered backlog (autonomy continuum 2026-08-26)

- **Struck 2026-09-24:** absorbed by queue row machine-steered-backlog, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Webapp dashboard (operator directive 2026-08-26)

- **Problem:** the current terminal dashboard is an eyesore and pops up
  automatically; the operator wants a browser-window webapp dashboard
  only when requested, handled deliberately, not a periodic popup.
- **Smallest useful outcome:** a webapp dashboard (browser window) that
  consolidates the hngh dashboard surfaces (lanes, reports, live
  agents, cadence) behind the existing hngh-automation
  dashboard service (or a successor), never auto-launching; opening it
  is an explicit operator action or an explicit timer-wired trigger.
- **Evidence:** operator directive 2026-08-26; hngh-automation
  dashboard.json + index.html; hngh scripts/dashboard-readout /
  dashboard-tui.
- **Risk:** duplicating the existing readout; reuse the --json spine as
  the only data source.
- **Dependencies:** agent-live-view roster; cadence-continuum.
- **Review trigger:** an operator opens the dashboard in a browser by
  intent; nothing auto-pops it; data matches the readout spine.

## Self-optimization continuum (operator directive 2026-08-26)

- **Problem:** the evolution/grading/steering loops target operator-facing
  surfaces and work slices, but Hngh's own operations (cadence placement,
  probe costs, timer hygiene, credential rotation, drop-in design) only get
  optimized reactively when a failure surfaces.
- **Smallest useful outcome:** a standing principle + mechanism where Hngh
  self-optimizes every part of its operations continually: the oversight
  tick's agentic leg gains a self-review mode that evaluates its own
  ticking costs/placement (which probes fit which windows, what fired
  on-change vs by-poll, what new cheap event hooks exist) and emits
  `optimize: <suggestion>` breadcrumbs; a 10m cadence drop-in collects
  them into a self-optimization ledger (`docs/project/self-optimize.md`)
  whose accepted suggestions ride the normal queue→card→ceremony path;
  nothing changes its own timer/unit definitions without a ceremony.
- **Evidence:** operator directive 2026-08-26; oversight-tick (agentic
  leg); cadence-continuum; surface-evolution-loop pattern.
- **Risk:** self-modification runaway — every change to Hngh's own
  operation still clears the same gates (proposal→verdict→certificate→
  mutation); suggestions are advisory until then.
- **Dependencies:** oversight-tick agentic leg; cadence tiers; queue/card
  ceremony path.
- **Review trigger:** a suggestion raised by the self-review mode is
  recorded, ranked with the queue, and only lands as a mutation through
  the certificate gate; the ledger shows a continual series.

## Hosted agentic interface (operator directive 2026-08-26 — "Hngh as an application")

- **Problem:** Hngh is a sidecar (kernel + timers + dashboard), not yet
  an application in its own right: a user cannot sit down with Hngh
  directly and have it fire up sessions and host its own instanced
  oh-my-pi / pi surface for interfacing with agentic Hngh.
- **Smallest useful outcome:** Hngh visibly firing up new sessions
  itself and hosting its own oh-my-pi/pi instance — an agentic
  interface where requests and steers reach the running Hngh as its
  own interactive session, not only through ceremony/timer paths.
- **Evidence:** operator directive 2026-08-26; r18 worker transport +
  worker-driver (bounded read-only worker lane exists); the omp/pi
  bridge concept; the nervous-system control-plane precept (#7).
- **Risk:** an agentic interface is an ambient process — the biggest
  departure from "no daemon." Mitigate: the interface itself stays an
  on-demand session host (fired by an explicit start / a steered
  event), never a background service; every action it takes still
  flows through the certificate gates.
- **Dependencies:** worker-driver/bridge-hosted end-to-end session
  (roadmap Next), the pi/oh-my-pi host surface, the dashboard webapp
  as the read side.
- **Review trigger:** a user opens the hosted interface, watches Hngh
  fire up a new worker session from it, and the session's actions land
  only with their certificates; nothing ambient runs without an
  explicit start.

## Hosted agentic interface — navigable + auto-tiling sessions (operator refinement 2026-08-26)

- **Problem (extends `hosted agentic interface`):** beyond firing sessions,
  the operator wants *readouts for all scheduled agent runs* (a navigable
  gantt) and *navigable, auto-tiling sessions* for the agentic interface —
  short-term and long-term views of Hngh runs, so Hngh visibly builds and
  uses itself rather than relying on oh-my-pi as the builder.
- **Smallest useful outcome:** the webapp gains the navigable gantt
  (scheduled runs readout — the ASAP slice); the hosted interface
  (backlog `hosted agentic interface`) then gains navigable sessions
  with auto-tiling (tmux-like tiles per run), gantt-adjoining the
  schedule, both driven by the same evidence/spine (never fabricate
  dates; timeline events anchor, queue items are planned ghosts).
- **Evidence:** operator directive 2026-08-26; `queue-eta` widget;
  `timeline-events`; the webapp (a2ae5fc) + spine; `hosted agentic
  interface` entry.
- **Risk:** fabricating dates/claims — the gantt renders only real
  timeline events + planned (ghost, ETA tooltip) queue rows; the
  tiling sessions are read-only views of runs, never governance input.
- **Dependencies:** gantt panel (dispatch in flight); hosted agentic
  interface (bridge/worker-driver rung); webapp panels.
- **Review trigger:** an operator-browser gantt shows today's real
  rotation events + future queued ghosts with ETA tooltips, and a
  session host tiles all open Hngh runs (navigable, live).

## OMP↔Hngh bridge plugin (operator directive 2026-08-26 — Hngh improves Hngh)

- **Problem:** Hngh is bootstrapped by OMP ad-hoc (launch an omp instance
  in the project dir, ask agents to orient); we're not taking advantage
  of Hngh itself to improve Hngh. The operator is OK using a plugin that
  directly interfaces oh-my-pi with Hngh while Hngh grows toward hosting
  its own sessions.
- **Smallest useful outcome:** an omp plugin that connects oh-my-pi
  sessions to Hngh's governance surfaces directly — so work ON Hngh
  runs through Hngh's own rules (ceremony-gated commits, roguelike
  watchdog visibility, wired-state lens, oversight alerts) rather than
  as a parallel ad-hoc lane. Reuse oh-my-pi's existing session/tool
  structure; add a thin Hngh-facing adapter, not a rewrite.
- **Evidence:** operator directive 2026-08-26; precept 11 (Hngh improves
  Hngh); worker-driver r18; `hosted agentic interface` + `bridge-operator
  -host` backlog entries; the roguelike watchdog + agent-handoffs ledger.
- **Risk:** coupling omp to hngh too early — the plugin must be a sided
  adapter (omp keeps its structure; hngh kernel stays side-effect-free),
  failures fail closed, no new daemon.
- **Dependencies:** `bridge-operator-host` rung; worker-driver; the
  watchdog/handoff surfaces.
- **Review trigger:** a session invoked through the plugin lands its
  commit through Hngh's certificate gate and its session is visible in
  the watchdog/handoff ledger; the same rules apply whether the agent
  is working in Hngh or on Hngh.

## Command center — CLI + GUI operator surfaces (operator directive 2026-08-26)

- **Problem:** there's no real "command center": no flexible ever-
  expanding agentic interface for a system harness; we use oh-my-pi
  ad-hoc. The operator needs BOTH a command-line and a GUI Hngh
  interface, each with flexible readouts and simple controls for
  summoning and scheduling agents for various purposes.
- **Smallest useful outcome (needs-first):**
  - CLI: `scripts/hngh` grows a `schedule` / `summon` surface (see
    agentic-interface rung) — operator types an ask, sees it considered
    + contrasted with existing features, sees it slotted into the
    active schedule.
  - GUI: the webapp becomes the command center (see webapp rungs +
    agentic-interface) — same surfaces, clickable.
  - **Expedite visibility:** a user can ask for an expedite and SEE the
    impact (what it accelerates, any cascading delay to other scheduled
    work/maintenance) at any degree of expedite.
  - **Subagent view+control:** subagent views accessible alongside any
    main Hngh instance / attached session; users can identify and PAUSE
    a misbehaving subagent, highlight/name the unwanted behavior for
    Hngh's correction.
- **Evidence:** operator directive 2026-08-26; webapp (live :8890);
  roguelike watchdog + agent-handoffs; `hosted agentic interface`,
  `OMP↔Hngh bridge plugin`, `machine-steered-backlog` backlog entries.
- **Risk:** scope creep — needs-first: build what the operator must SEE
  first (awareness: runs/schedule/subagents/system), then what's nice;
  no daemon until the bridge rung proves it needs one.
- **Dependencies:** machine-steered-backlog (scheduling+completing own
  development), hosted agentic interface + OMP↔Hngh bridge (summon/
  schedule controls), system awareness rung (harnessing hardware/
  software/network), watchdog pause/highlight surface.
- **Review trigger:** an operator opens either interface, types an ask
  about Hngh's development, sees it considered, expedited with visible
  ripple impact, and can pause+label a misbehaving subagent from the
  subagent view — all without leaving the interface.

## System awareness rung (operator directive 2026-08-26)

- **Problem:** Hngh should maintain steady awareness of its surrounding
  system, using hardware/software/network resources to suit its own
  development and expansion — currently it only sees its stores/timers.
- **Smallest useful outcome:** the oversight tick + dashboard surface
  live system health (CPU/mem/disk/net, tailscale/fleet peers, model
  server health, resource headroom) as read-only awareness
  (fleet-manager already probes some); the agentic leg can name
  resource-based steers (e.g. "network down — pause network-labeled
  jobs").
- **Evidence:** operator directive; fleet-manager --discover;
  probe-model-route; credentialed network probes.
- **Risk:** awareness becoming ambient control — keep it read-only
  awareness feeding steer suggestions, never implicit mutation.
- **Dependencies:** cadence-continuum + oversight tick; fleet-manager.
- **Review trigger:** the dashboard shows live system-resource state,
  and a resource change (e.g. network loss) produces a steer/alert
  without any hidden action.

## Time ledger & delay flagging (self-optimization telemetry)

- **Problem:** Hngh aims to be self-optimizing, but operation wall-times
  live in scattered places (ceremony-drive `[ceremony-timing]` lines,
  systemd journal, suite walls, agent-wave reports) and get reviewed
  only when a human notices slowness. Excessive delays — like the
  2026-08-27 autonomy-tick wedge that sat failed for hours — should be
  noticed procedurally.
- **Smallest useful outcome:** one rolling time-ledger artifact
  (per-unit last/p50/max wall seconds, per-ceremony-step milliseconds)
  plus one oversight check that flags any operation exceeding
  max(2× its trailing median, floor) as a flap-suppressed alert row
  feeding the existing steer path.
- **Evidence:** the 2026-08-27 delay-ledger review
  (`records/2026-08-27-operator-items-closeout.md`,
  `records/2026-08-27-acceleration-wave.md`); measured wins already
  banked (untracked-artifact tax 6312→25 rows; ceremonies 40s→~3s).
- **Risk:** measurement load; alert noise; thresholds tuned to hide
  real drift — flap suppression and a small fixed floor keep it honest.
- **Dependencies:** oversight-tick alert path; systemd unit metadata;
  ceremony-timing lines; the report ledger.
- **Review trigger:** a seeded synthetic delay in a fixture run is
  flagged once, flap-suppressed after, and the ledger round-trips
  real unit timings.

## Session observatory (live subagent runs page)

- **Problem:** delegated agent runs are invisible while they run: the
  watchdog sees deaths, the roster shows counts, and neither offers an
  operator a navigable view of live sessions with their output.
- **Smallest useful outcome:** a read-only webapp page listing every
  session with state filters and a per-session detail pane (fields +
  bounded, redacted transcript tail), syntax highlighting, two themes,
  auto-refresh with honest staleness stamps.
- **Evidence:** operator directive 2026-08-27 (dedicated browser window
  welcome; multiple pages/styles/purposes intended); interface-plan
  S4/M6; master plan P4 navigable sessions.
- **Risk:** transcript surfaces touch operator home directories —
  read-only, bounded tails, secret-redaction at the feed boundary; the
  page must never render, let alone feed, governance input.
- **Dependencies:** `readout.json` roster spine; omp session surfaces;
  the refresh-dashboard feed pattern; browser relay for operator view.
- **Review trigger:** the page renders fixture sessions byte-identical
  to store records, redaction provably fires, and no canonical field
  is consumed for any decision.

## Browser notification surface

- **Problem:** attention-worthy events (alert rows, verdict flips)
  reach the operator only when a dashboard pane is being watched.
- **Smallest useful outcome:** opt-in browser notifications via the
  relay page for alert-class rows and verdict flips — digest-level,
  one-shot, flap-suppressed, zero default-on.
- **Evidence:** operator directive 2026-08-27 (browser notifications
  welcome alongside other channels).
- **Risk:** nagging; notification permission creep — the buddy rule
  (summoned, never nagging) applies: one notification per flap window.
- **Dependencies:** session observatory page host; report ledger
  cursor.
- **Review trigger:** a fixture alert produces exactly one
  notification and the toggle defaults off.

## Emacs-style surface configurability

- **Problem:** surface behavior (themes, refresh intervals, panel
  toggles, thresholds) is hard-coded per script; the operator wants
  declarative, layered configuration across all Hngh interfaces.
- **Smallest useful outcome:** one user config file
  (`~/.config/hngh/ui-config.*`) read at render/feed time, layering
  operator overrides over built-in defaults for display preferences —
  theme, refresh interval, visible panels, alert thresholds.
- **Evidence:** operator directive 2026-08-27 ("emacs-style
  configurability intended").
- **Risk:** config becoming a second authority — config is
  display/ops-preference only and can never carry governance fields
  (presentation-boundary law applies to configuration too).
- **Dependencies:** the dashboard/observatory surfaces it configures.
- **Review trigger:** the first config key ships with a fixture test
  proving governance fields in the config file are refused.

## Model-tier refresh cadence

- **Problem:** route and cost assumptions drift as providers change
  pricing and capability (the GLM 5.3 Flash workhorse window ends
  2026-09-09); BENCH_MODELS rot was already observed (MiniMax-H3 0/5).
- **Smallest useful outcome:** a quarterly re-bench + route review
  that lands a `route:` report row naming the current workhorse,
  runner-ups, and any model dropped from BENCH_MODELS.
- **Evidence:** `7a4041e` (MiniMax-H3 drop); the 2026-08-27 workhorse
  directive (GLM 5.3 Flash through Sept 9).
- **Risk:** benchmark churn; over-fitting to single-run scores —
  keep 0/5-twice as the drop rule.
- **Dependencies:** model-bench job; probe-model-route.
- **Review trigger:** the next quarterly bench lands a route report
  row even when nothing changes.

## Host orientation pass (new-system situating)

- **Problem:** on any system Hngh gets installed on, it must investigate
  what is present — packages and install sources (pacman, AUR/yay,
  npm/bun/bunx/uv), agent tools and their config surfaces — before it
  can interface with that system and help its operator.
- **Smallest useful outcome:** one orientation pass producing a
  host-inventory artifact plus a redacted config archive
  (`~/.local/state/hngh-automation/config-archive/`) and lane
  declarations for `config-backup.sh`, so config governance starts from
  day one on every host.
- **Evidence:** the 2026-08-27 CachyOS config archive (18 entries,
  six agent tools) and the git-back-dots subsumption inventory.
- **Risk:** inventories that leak secrets — scan classes only, values
  never rendered; archives stay local unless a lane declares a remote.
- **Dependencies:** config-backup lanes; system-awareness probe.
- **Review trigger:** a fixture host (container/chroot) yields a
  complete inventory + archive through the standard gates.

## Report-ledger retention policy

- **Problem:** the report ledger grows unboundedly (6,920 rows in two
  days of cadence output); `--prune` exists but nothing schedules it.
- **Smallest useful outcome:** a weekly ceremony-bound prune drop-in
  that archives alert/scheduled rows older than 30 days and lands the
  rotation as a check-in-scale commit, keeping the dashboard unread
  signal meaningful.
- **Evidence:** `report-queue --prune --archive` (this change set).
- **Risk:** pruning evidence prematurely — the archive preserves every
  pruned row verbatim; kinds are explicit.
- **Dependencies:** `report-queue --prune`; the autonomy ceremony slice.
- **Review trigger:** first prune runs inside a certificate loop with
  the archive attached to the candidate manifest.
- **Path convention (2026-08-27):** ledger rows carry repo-relative or
  `~/` paths, never absolute local paths — the public-content scan
  refuses candidates containing any absolute home directory prefix, so
  producers strip `$HOME` at emission (oversight-tick tree-skew was the
  last offender; 58 uncommitted rows normalized in place).

## Widget grid + QoL evolution cadence (dashboard surfaces)

- **Problem:** dashboard panes are fixed-position; quality-of-life
  improvements happen only when the operator demands them. The operator
  wants moveable, flexible widgets (terminalfeed.io as the reference
  example) and a scheduled, cyclical QoL research/development loop.
- **Smallest useful outcome:** a draggable, persisting widget layout for
  the dashboard pages (position/size per pane, per operator, layered
  with the ui-config layer), plus a scheduled surface-evolution beat
  that lands one graded QoL improvement per cycle without human
  intervention.
- **Evidence:** operator directive 2026-08-27 (terminalfeed.io named as
  the example; "regular, cyclical research and development concern").
- **Risk:** layout state becoming canonical — layout is display
  preference only; the evolution beat may propose but never auto-mutate
  cadence or governance surfaces.
- **Dependencies:** ui-config layer (emacs-style configurability rung);
  grade-interface; the observatory and gantt pages.
- **Review trigger:** one cycle lands a graded, revertible QoL change
  with before/after screenshots attached to the candidate.

## Cascading gantt: run estimates + parallel cascade

- **Problem:** the gantt rendered per-day granularity only; runs had no
  duration estimates and parallelizable overlap was invisible.
- **Smallest useful outcome:** first slice LANDED 2026-08-27
  (`dashboard/gantt.html`: ESTIMATE-labelled bars from time-ledger p50
  -> loadout time-limit -> 30m default, dependency connectors, zoom and
  drag pan, relative projected starts). Remaining: per-lane medians once
  wrapped sessions name lanes in their missions; live-run bars beside
  projected ones; expedite-ripple projection (M5) drawn as an alternate
  cascade.
- **Evidence:** hngh-automation `f67f972`; adversarial review caught and
  fixed an off-canvas connector artifact (double ms-conversion).
- **Risk:** estimates read as schedule facts — every bar carries its
  source; relative starts only, never fabricated dates.
- **Dependencies:** time-ledger; readout spine; the roguelike wrap
  (wrapped sessions name lanes).
- **Review trigger:** a wrapped live session renders an actual bar next
  to projected ones with the estimate source labelled.

## Interface plurality + session spawn affordances

- **Problem:** the operator works with Hngh through many surfaces — an
  OMP session in Konsole is the primary one today — and the dashboard
  should hand off to those surfaces, not replace them.
- **Smallest useful outcome:** first slice LANDED 2026-08-27
  (`POST /spawn`: configurable launchers from ui-config, Konsole tail
  proven live). Remaining: per-surface presets (OMP collab windows,
  browser windows), a session-page launcher menu, operator-editable
  launcher documentation.
- **Evidence:** operator directive 2026-08-27; the observatory flag
  path (UI -> server -> ledger) as the established pattern.
- **Risk:** spawn is desktop mutation — allowlisted templates only; the
  client names a key, never a command.
- **Dependencies:** dashboard-server; the ui-config layer.
- **Review trigger:** every launcher key documented, validated, and
  demonstrated once against a live session.

## Self-supervision tick (Hngh watches its own agents)

- **Problem:** delegated-run supervision is currently performed by the
  harness agent (reading transcripts, noticing stalls, debugging
  integration seams). In the long run Hngh's operations are Hngh's:
  every supervision pattern the harness agent exercised must become a
  Hngh-native mechanism.
- **Smallest useful outcome:** a supervision tick extending the
  watchdog: parse delegated-run session transcripts (jsonl), compute
  per-run phase (discovering / writing / fixing-own-regressions /
  verifying — classified from tool-call patterns), detect stalls (no
  tool-call progress beyond budget), and emit flap-suppressed alert
  rows; roguelike replacement (close-run :dead + re-provision) for
  budget-expired runs rides the existing loop.
- **Evidence:** the 2026-08-27 transcript-analysis session proved the
  pattern live (phase + tool-density computed for 30+ agent runs in one
  pass); the watchdog already observes deaths — this adds progress
  observation.
- **Risk:** transcript formats vary by harness (omp schema derived from
  LibScout/agent specimens; others differ) — per-harness parsers behind
  one interface; phase classification is heuristic and stays advisory.
- **Dependencies:** the roguelike wrap (runs to supervise);
  sessions-feed transcript resolution; report-queue identities.
- **Review trigger:** a seeded stalled fixture run is flagged with the
  correct phase within one tick, and a healthy run is never flagged.

## Research lines: user controls

- **Problem:** the Research view is read-only; the operator cannot add a
  new line of research or attach notes/steering to existing lines.
- **Smallest useful outcome:** from the Research tab, the operator adds
  a research line (name + intent; lands in backlog as a proposal-ready
  lane) and attaches notes or steering commentary — affecting (rides the
  certificate gates like any steer) or non-affecting (annotation only) —
  to lines in any state (active, completed, in-proposal).
- **Evidence:** operator directive 2026-08-27 (evening, "first user
  controls").
- **Risk:** user-added lines bypassing governance — additions are
  proposals by default; only the affecting class touches cadence or
  gates, and only through the loop.
- **Dependencies:** research view; report-queue identities; the
  certificate loop for affecting steers.
- **Review trigger:** an added line appears in backlog + Research view;
  an affecting note lands as a deduped steer row; a non-affecting note
  never touches a gate.

- note (2026-08-27T20:36:05Z): What is this, a control for a note? Weird research line, seems like it should probably get resolved?
## Memory surface (llm-wiki integration)

- **Problem:** Hngh's harvested lessons and memory live in the llm-wiki
  and session notes — invisible on any operator surface.
- **Smallest useful outcome:** a Memory tab/panel listing wiki sources
  and recent lessons (read-only first), searchable, linked to the runs
  and waves that produced them.
- **Evidence:** operator directive 2026-08-27 ("easy opportunity for
  interfacing with llm-wiki").
- **Risk:** memory display implying memory authority — lessons inform,
  never decide (the wiki is already a record, not a gate input).
- **Dependencies:** llm-wiki vault; research view patterns.
- **Review trigger:** the panel renders the real vault index and every
  displayed lesson links to its source record.

- **State (2026-09-07; folded to one line 2026-09-24):** vaults mapped (two); the project vault (`~/Projects/etc/llm-wiki/.llm-wiki`) is stale - 92 pages on disk against 26 in the registry, all Cistern lessons unindexed since the 2026-08-19 meta freeze; health probe (`hngh-automation/cadence/week/04-wiki-health.sh`), research-beat consumption, and the lessons production seed landed; the one rebuild action is documented in [../design/wiki-surface.md](../design/wiki-surface.md).

## Startup launch flow

- **Problem:** starting work means opening a terminal, an omp session,
  and the dashboard separately, by hand.
- **Smallest useful outcome:** from the dashboard (or one command), the
  operator fires up a live agentic session for continuing Hngh and
  system work — an omp/agent session spawned, wrapped by the roguelike
  run-start, and visible in the observatory — with the dashboard open
  beside it.
- **Evidence:** operator directive 2026-08-27 ("dashboard at startup…
  immediately fire up an agentic session").
- **Risk:** desktop spawn is mutation — allowlisted launchers only
  (existing pattern); the spawned session is wrapped, never raw.
- **Dependencies:** the roguelike wrap; /spawn endpoint; ui-config.
- **Review trigger:** one click spawns a session that appears in the
  observatory within one feed tick, already run-wrapped.

## System controls → governed package operations

- **Problem:** the System view is observability-only; the operator named
  package management, system update, configuration management, backups,
  syncing, and network status as the controls they actually want.
- **Smallest useful outcome:** v1 controls landed (refresh, check
  updates, reset-failed, run-backup — safe ops, handoffs-logged). Next:
  governed package upgrades ride the certificate loop (proposal →
  verdict → executor runs the update in a declared window with
  rollback evidence).
- **Evidence:** operator directive 2026-08-27 (evening System review).
- **Risk:** unattended upgrades break running work — upgrades are
  certificate-gated, declared-window, rollback-evidenced, never ambient.
- **Dependencies:** system-ops feed; the certificate loop; a declared
  maintenance window lane.
- **Review trigger:** one governed upgrade executes end-to-end with
  pre/post manifests and rollback evidence.

## Research precedence + collected material

- **Problem:** research lines cannot be reordered by precedence, and
  material already collected for a line (design docs, records, wiki
  sources) is not linked from the line.
- **Smallest useful outcome:** precedence order persisted and rendered
  (up/down controls); each line links its collected material (design
  docs, records, kb snapshots) with one-click navigation.
- **Evidence:** operator directive 2026-08-27 (Research review).
- **Risk:** precedence becoming a second priority system — it orders
  display and attention only; the machine-steered selector keeps its
  own policy.
- **Dependencies:** research view; kb view.
- **Review trigger:** reorder persists across reload; collected
  material links resolve for every lane.

## Cadence watch fixes — gated red, recorded not landed (2026-08-28)

- **Problem:** the automation repo's own gate has no scheduled checker,
  and its watch probes alert on the machine's own housekeeping. With
  the kernel gate green, hngh-automation `make test` sat red on HEAD
  (lint-identifiers: deck-setup.sh reports `$DESK_LAN_IP`/`$DESK_TS_IP`
  as referenced-never-defined although both are defined inside the
  `hngh-connect` heredoc — the scanner does not track heredoc-scoped
  definitions; hngh-ufw-manage.sh carries a genuinely dead
  `TS_SUBNET`), and no alert fired: `cadence/day/03-gate-check.sh`
  sweeps only the kernel. Separately, the oversight tree-skew probe
  fired x64 on machine-maintained append paths, and the fresh-eyes
  digest ships the echoed prompt plus raw diffs instead of findings.
- **Smallest useful outcome:** a day-tier drop-in gates hngh-automation
  too (`make test` there, alert rows on red); the tree-skew probe
  whitelists machine-maintained append paths (reports.md, ui-grades.md,
  current-overlay.json, plan status transitions) or ceremonies sweep
  them on a fixed cadence; lint-identifiers learns heredoc scoping (or
  gains a scoped exclusion) and `TS_SUBNET` is removed; the review
  digest keeps the findings section, not the prompt echo.
- **Evidence:** hngh-automation `make test` red on HEAD 2026-08-28
  (3 lint problems, run this day); oversight tree-skew alerts x64
  (report rows 96bd99de, 07:55Z–08:00Z); digest/REVIEW-2026-08-28.md
  prompt echo; `cadence/day/03-gate-check.sh` sources.
- **Risk:** none beyond script edits in hngh-automation — no new
  daemons; changes land as plain commits there once its gate is green.
- **Dependencies:** cadence/day drop-ins; jobs/lint-identifiers.sh;
  scripts/hngh-ufw-manage.sh; review-prep digest generation.
- **Review trigger:** hngh-automation `make test` green on HEAD and a
  gate-red alert reproducible in a fixture run.

## report-queue escalation caps

- **Problem:** identity+window dedup collapses repeat alerts, but the
  xN occurrence marker grows unbounded and a permanently-deduped alert
  stops being information (stale-store spam x12 per id at 11:10Z, rows
  0582c2ca/4b0abe9a; dash-selfreview summary at x18, row f438818b).
- **Smallest useful outcome:** cap the xN marker; past a threshold,
  escalate to the operator-facing digest instead of bumping the count.
- **Evidence:** report-ledger lesson row b185ea3c
  (2026-08-28T18:35:46Z, device-pairing wave).
- **Risk:** low — display and escalation policy only; identities and
  windows unchanged.
- **Dependencies:** scripts/report-queue; digest generation.
- **Review trigger:** one deduped alert crosses its cap and surfaces
  in the operator-facing digest.

## Router-side re-arm pre-check (router-rearm-precheck) — done 2026-09-01

- **Struck 2026-09-24:** absorbed by queue row router-rearm-precheck, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Publication pipeline: research-lines wiring vs the fixed 7-file contract (publication-lines-contract) — queued 2026-08-31

- **Struck 2026-09-24:** absorbed by queue row publication-lines-contract, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Ebook book-machine inputs (ebook-book-inputs) — queued 2026-08-31

- **Struck 2026-09-24:** absorbed by queue row ebook-book-inputs, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

- Language discipline (2026-08-27): operator-facing output is English-only, enforced via AGENTS.md layers (global ~, repo). Long-run alternative: an automatic detect-and-translate layer over any non-English model output.

## Operator-coherence layer (the Mirror) — operator directive 2026-09-07

- **Problem:** operator intent drifts across sessions and sits outside
  the source-resolution chain ([design/autonomous-development-control.md](../design/autonomous-development-control.md)
  step 1): machine decisions cannot be checked against what the
  operator actually wrote, valued, or meant. The existing substitutes
  (the writing/display registers, cadence-params.tsv, the llm-wiki
  vault, the lessons index) are each partial. Designed in
  [design/operator-mirror.md](../design/operator-mirror.md).
- **Smallest useful outcome:** one preference/principle register with
  versioned, citable rows, one named source ingested into the
  local-first corpus, and one grow-admission coherence check that holds
  a contradicting plan with cause=intent-conflict.
- **How we'd know it works:** a plan that contradicts a cited register
  row parks at admission; a conforming plan passes; every corpus item
  has a manifest row and a per-item exposure policy (nothing enters a
  remote prompt unnamed).
- **Review trigger:** the first register row is cited by a real
  disposition, or the coherence check fires (or provably never fires
  across a full Stratum) — either is evidence.

## Credential-rotation harness (the Keyring) — operator directive 2026-09-07

- **Struck 2026-09-24:** absorbed by queue row credential-rotation-auto, 2026-09-24 (proposal prose removed as a duplicate; the queue row is the live handle; last commit containing the removed content: bd2c1cee).

## Takeout ingest pipeline (the Portage P1) — operator directive 2026-09-07

- **Problem:** the operator's personal data (gmail, calendar, docs,
  drive, sheets) sits inside walled gardens; the Mirror's corpus
  ([design/operator-mirror.md](../design/operator-mirror.md) §3) has no
  transport to feed it. Export, normalization, and ingest are long,
  multi-step work that needs checkpoints and evidence. Designed in
  [design/data-sovereignty.md](../design/data-sovereignty.md) §3 and §5.
- **Smallest useful outcome:** one Google Takeout export read-only,
  normalized into a local corpus tree, with manifest rows (paths and
  hashes, no values) and ingest rows naming each corpus item per the
  no-unnamed-source rule.
- **How we'd know it works:** re-running normalization over the same
  export yields identical hashes (deterministic); every normalized item
  has an ingest row; no remote write occurs anywhere in the phase.
- **Review trigger:** the LobeHub integration-surface study lands in
  research/ (2026-09-07), or the first export run produces a complete
  manifest — whichever comes first.

## Syncthing fleet manager (the Portage P2) — operator directive 2026-09-07

- **Problem:** rehomed data must spread across local devices (desktop,
  deck, NAS, laptop), but syncthing configuration is hand-edited per
  device and the fleet's shape is uncitable. Hngh should manage
  folders, devices, and ignore patterns as ledger rows over syncthing's
  REST API, one-shot per tick, no daemon
  ([design/data-sovereignty.md](../design/data-sovereignty.md) §4).
- **Smallest useful outcome:** one folder-device pair admitted through
  the proposal/check/record path and reconciled by a tick — desired
  state as a ledger row with provenance, the change recorded, no
  watching process.
- **How we'd know it works:** the row's provenance names the run that
  wrote it; killing the tick mid-reconcile leaves the pair consistent
  or parked with cause; a second device joins via the introducer with
  its own admission run.
- **Review trigger:** the first device admission run records its
  evidence, or the mesh-horizon nodes (backlog "Node lattice rung")
  need a transport for file movement — whichever comes first.

## Repo topology consolidation (single-repo candidate)

- **Problem:** Hngh's operational tier lives in a second public repo
  (`hngh-automation`), splitting the story the docs tell from the
  machine that acts: 856 cross-references, dead relative links on
  GitHub, two URLs, and hourly sweep commits polluting one history.
- **Smallest useful outcome:** an operator decision — merge via
  machine-data quarantine (`git subtree add --prefix=automation`, env
  seam collapse, systemd cutover, remote archive) or a recorded
  decision to stay split with sweep-noise pruning — per
  [design/repo-merge-consideration.md](../design/repo-merge-consideration.md).
- **Risk:** migration touches 37 systemd units and one cutover day on
  a live cadence; raw operational data leaves the public git surface
  under the quarantine path.
- **Review trigger:** operator decision after reading the
  consideration.

## Clean reorientation track A (automation cleanup)

- **Problem:** the automation-tier ponytail audit found nine verified
  findings — four dead utility scripts (388 lines), config.env quota-leg
  stopgaps shadowing landed cadence-params rows, four-plus duplicated
  curl-POST-parse blocks in `lib/model.sh`, five duplicated test stub
  servers, and three tombstones (a dead env var, a documenting tsv row,
  a tripled comment). Clean-architecture principles (kernel purity,
  single authority, artifact-consumer invariant) dictate the cleanup.
- **Smallest useful outcome:** Track A phases A1–A4 landed in
  hngh-automation, each independently gated on `make test`, per
  [design/clean-reorientation.md](../design/clean-reorientation.md)
  (~-560 measured lines); Track B (topology) stays gated on the merge
  P0 decision.
- **Risk:** low — zero-caller deletions and behavior-preserving
  consolidations; the one behavior-adjacent move (`DECK_URL` into its
  tsv row) is value-identical. The leave-alone doctrine list in the
  plan protects the fail-closed paths from over-zealous cleanup.
- **Review trigger:** landed after operator reads clean-reorientation.md;
  Track B gated on merge P0.

## Kernel gate watch-test load flake

- **Problem:** kernel `make test` flakes under launch-storm load —
  `tests/scripts/test-dashboard-live.py` spawns
  `scripts/dashboard-readout --watch 1` with a hard 5s subprocess wait;
  during overnight-cycle launch storms the spawn exceeds 5s, the kernel
  gate returns rc=2, accept-plans blocks plan acceptance for that tick,
  and a gate-red alert row + routed plan are filed (2026-09-05 ×6,
  2026-09-06 ×8, 2026-09-07, 2026-09-08 bursts).
- **Smallest useful outcome:** raise the watch-spawn wait (5s → 30s) or
  make it load-hermetic in tests/scripts/test-dashboard-live.py; kernel
  gate stays green under concurrent launch load.
- **Evidence:** alert bodies 598ffaaa (2026-09-08T01:01:33Z, full
  traceback), 60e40190 (2026-09-06T21:00:45Z), 870f7cf0
  (2026-09-05T12:01:28Z); plan
  `docs/project/plans/2026-09-02-routed-gate-red-hngh.plan.md`
  (executed 2026-09-08T01:06Z — both gates green on direct re-run,
  kernel rc=0 / 2855 checks).
- **Risk:** low — test-only timeout change; no `src/` semantics touched.
- **Dependencies:** a session with kernel `tests/` write permission; the
  change rides the certificate ceremony with a green `make test`.
- **Review trigger:** kernel `make test` green twice in a row under a
  simulated launch storm (concurrent cadence tick), and the
  `overnight:plan-accept-gate:kernel` alert identity silent for a full
  day of launch ticks.

## Interactive installer maturity (real distro matrix) — operator directive 2026-09-11

- **Problem:** the OS-harness vision
  ([2026-09-11-operating-system-harness-vision.md](../records/2026-09-11-operating-system-harness-vision.md))
  needs install that works beyond one host; today Hngh situates itself via
  the host orientation pass but nothing installs it onto a fresh machine
  across a real distro matrix.
- **Smallest useful outcome:** an installer skeleton that brings the
  kernel + automation tier up on one second machine, later verified across
  N distinct distros — the vision record's staging triggers.
- **Evidence:** vision record 2026-09-11; host-orientation backlog row.
- **Risk:** medium — touches system setup paths; gated by proposals.
- **Dependencies:** installer skeleton, environment contract, secrets
  seam (1Password pattern).
- **Review trigger:** second machine runs the kernel + automation tier
  green, or a staging trigger fires.

## OS-harness knowledge tracks (systemd/distro packaging research) — operator directive 2026-09-11

- **Problem:** the OS-harness vision's near-term ladder (environment
  contract, package registry, cross-platform abstraction) lacks research
  grounding in systemd integration depth and distro packaging prior art.
- **Smallest useful outcome:** stage 5 research beats (queued in
  automation/research-subjects.txt 2026-09-11) crystallized into design
  inputs for the ladder's rungs.
- **Evidence:** vision record 2026-09-11; research-subjects.txt entries.
- **Risk:** low — research-only.
- **Dependencies:** none; rides the stage 5/6 alternation.
- **Review trigger:** a ladder rung's proposal needs the research input.

## Social read layer — operator directive 2026-09-11

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## Social post layer (gated) — operator directive 2026-09-11

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale row prose removed; last commit containing the removed content: bd2c1cee.

## OSS contribution candidates — operator directive 2026-09-11

- **Struck 2026-09-24:** no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane) - stale "Risk: low - deferred until a real diagnosis exists" prose folded away with the row; last commit containing the removed content: bd2c1cee.

## Jcode primary-harness worker lane — operator directive 2026-09-14

- **Problem:** Jcode is admitted as the primary agent harness
  (records/2026-09-14-jcode-primary-harness-admission.md) but no hngh
  delegation lane drives it; the existing bounded worker lane is omp/pi.
- **Smallest useful outcome:** one governed Jcode worker cycle:
  `launch()`-based driver (or CLI-equivalent) wrapped `--run-start` →
  observatory `working` → `--run-end`, permissions deny-by-default bridged
  to the certificate loop, one witnessed run with evidence.
- **Evidence:** admission record 2026-09-14; governed-fleet.md §4
  delegation invariants; 2026-09-12 harness-delegation research line.
- **Risk:** medium — new transport into the delegation matrix; spawn depth
  and token seams must be declared before first witnessed cycle.
- **Dependencies:** hngh MCP server (landed, shared stdio standard);
  certificate loop; observatory working state.
- **Review trigger:** operator directive 2026-09-14 (prioritized ahead of
  discretionary queue work).

## Jcode observatory surface — operator directive 2026-09-14

- **Problem:** the nerve-center Sessions tab has no Jcode session source;
  the operator runs Jcode sessions the observatory cannot see.
- **Smallest useful outcome:** read-only Jcode session preview in the
  observatory via `connect()`/`peekSession` (preview-without-disturb),
  behind the existing read-only probe architecture.
- **Evidence:** admission record 2026-09-14; system-awareness-map design.
- **Risk:** low — read-only, owner-only socket, no mutation path.
- **Dependencies:** worker lane first (or independently via the operator's
  `jcode api-bridge`).
- **Review trigger:** worker lane's first witnessed cycle.

## Crumbs writer-flip — brief recommendation 2

- **Struck 2026-09-24:** absorbed by queue row crumbs-writer-flip, 2026-09-24 (stale review-trigger prose folded: first consumer request, >= 1 clean parity day, or the next db-migration slice, whichever comes first; proposal prose removed as a duplicate; last commit containing the removed content: bd2c1cee).
## Router re-route policy - follow-up 2026-09-24 (automation tier)

- **Follow-up (2026-09-24):** bound re-routes per alert identity or park after expiry (the router re-routes the same identity indefinitely, e.g. tree-skew:hngh -> routed-tree-skew-hngh-7).
- **Problem:** same-identity re-routes generate an unbounded chain of routed plan candidates (routed-tree-skew-hngh-7 is the seventh re-route), inflating the plan ledger and the planned-work surface.
- **Smallest useful outcome:** a bound (or expiry) per alert identity past which the router parks the identity instead of re-routing it.
- **Evidence:** reports.md tail 2026-09-24 (routed-tree-skew-hngh-7; patrol:journal-error re-routed x2); the router-churn finding of the 2026-09-24 foundation consolidation.
- **Risk:** a still-live alert could be parked silently; parking must leave an observable parked row.
- **Dependencies:** scripts/router-tick.py (hngh-automation); report-queue dedup/escalation caps.
- **Review trigger:** one alert identity reaches its bound (or expiry) and parks instead of re-routing, with an observable row.

## Adopted-disposition adoption wire - follow-up 2026-09-24 (automation tier)

- **Follow-up (2026-09-24):** research-lifecycle-audit.md:4-7: 0 of 73 adopted dispositions feed any runtime decision; wire adopted verdicts into at least one runtime decision surface.
- **Problem:** adopted verdicts (support/oppose/followons) sit in research-dispositions.tsv columns that nothing consumes; the research pipeline is circular, never cumulative.
- **Smallest useful outcome:** at least one runtime decision surface reads adopted verdicts as input evidence.
- **Evidence:** [../design/consider/research-lifecycle-audit.md](../design/consider/research-lifecycle-audit.md):4-7.
- **Risk:** adopted verdicts are advisory evidence, never proof; a wired surface must not let a disposition decide alone.
- **Dependencies:** research-dispositions.tsv; one runtime decision surface (the research-beat guidance path is the nearest).
- **Review trigger:** one runtime decision demonstrably reads an adopted verdict and records it as input evidence.

## Cadence-tier collapse - follow-up 2026-09-24 (automation tier)

- **Follow-up (2026-09-24):** pivot-synthesis.md:57-59: 9 cadence tiers collapsible to 2-3, behavior-preserving.
- **Problem:** 9 cadence tiers (month/week/day/hour/10m/5m/1m + ad-hoc and mounted jobs) are named accretion to retire.
- **Smallest useful outcome:** the cadence runs on 2-3 tiers with identical firing behavior.
- **Evidence:** [../design/consider/pivot-synthesis.md](../design/consider/pivot-synthesis.md):57-59.
- **Risk:** collapsing tiers must not change when work fires; behavior-preserving is the acceptance bar.
- **Dependencies:** hngh-automation cadence tier layout; the tier router and timer units.
- **Review trigger:** a fixture shows each collapsed tier fires the same work at the same effective cadence as before.

## Write-only artifact classes - follow-up 2026-09-24 (automation tier)

- **Follow-up (2026-09-24):** STATE-OF-PROJECT.md:57-61: 3 of 16 artifact classes are write-only; wire-or-delete.
- **Problem:** digest-BENCH, digest-RESEARCH, and email-qa.log are produced but never read (torch ledger).
- **Smallest useful outcome:** each write-only class is wired to a named reader or deleted.
- **Evidence:** [STATE-OF-PROJECT.md](STATE-OF-PROJECT.md):57-61 (hngh-automation torch-ledger.tsv).
- **Risk:** deleting an unwired class could drop a future consumer's input; delete only with the decision recorded.
- **Dependencies:** the torch ledger audit (hngh-automation cadence/day/17-torch-audit.sh).
- **Review trigger:** each of the three classes is either consumed by a named reader or removed, with the decision recorded.

## Interpretation seam for findings - follow-up 2026-09-24 (automation tier)

- **Follow-up (2026-09-24):** typed-challenges / research review gain canon-informed supportive/adversarial commentary as advisory output rows (docs/design/interpretation-doctrine.md).
- **Problem:** typed-challenges and research review report mechanical verdicts only; findings gain no canon-informed reading.
- **Smallest useful outcome:** advisory supportive/adversarial commentary rows accompany the mechanical verdicts, following the doctrine's named seams.
- **Evidence:** docs/design/interpretation-doctrine.md (2026-09-24 foundation consolidation).
- **Risk:** interpretation must stay advisory - it never admits or refuses a mutation and never enters the evidence ledger as proof.
- **Dependencies:** the interpretation doctrine's named seams; the typed-challenge / research review output rows.
- **Review trigger:** one typed-challenge or research review carries supportive/adversarial advisory rows while its mechanical verdict is unchanged.
