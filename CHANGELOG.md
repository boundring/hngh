# Changelog

All notable changes to Hngh are documented here, dated and categorized per
[Keep a Changelog](https://keepachangelog.com/) (format) and the project's
[D1 doc convention](docs/project/decisions.md) (durable records carry
`green @ <sha>`).

The format is based on [Keep a Changelog](https://keepachangelog.com/).
Releases are not yet used (pre-alpha); entries are grouped by date.

## [Unreleased]

### Fixed — planner quota pacing
- Planner admission now derives bucket pacing from the locked quota ledger and
  reset anchors rather than treating caller-supplied zero elapsed time as
  authority. Added a fixture that distinguishes live derived pacing from that
  forced-zero path; `docs/records/2026-08-11-card-127-planner-quota-truth.md`
  carries the review and test receipts.

### Changed — documentation reorientation
- Moved 130 legacy design, project, journal, research, review, session, and
  Hermes-plan files to `docs/archive/2026-08-10-pre-consolidation/` without
  content edits. The consolidation manifest records content-set receipts and
  recovery paths.
- Replaced the former overlapping working surface with `docs/core/` for the
  charter, system boundary, session operations, delivery system, and records
  governance; `docs/records/` now carries the live backlog and dated work log.
- Added compatibility aliases for documented and programmatic legacy paths.
  They preserve access while new work uses the compact core set.
- Updated the test-count lint to inspect current core documents rather than
  the archived roadmap.

### Added — bounded K3 authority completions
- Added `docs/design/k3-bounded-completions.md`: compact one-turn packets,
  no tools by default, strict context/output caps, and coupled 5h/7d/30d
  admission so a fresh short window cannot exhaust weekly/monthly reserves.
- Added a Pi-like thin-harness feasibility spike to the backlog without
  selecting or depending on Pi.
- Added evidence and continuation gates to the coordination contract so
  finished seats reconcile claims, lanes, and the deck before resting.

### Added — model economy and context lifecycle
- Added `docs/design/model-economy-and-context-lifecycle.md`: every remote
  route above $0.20/M input or with UNKNOWN price is reserve-only; reserve
  calls use explicit admission, compact packets, reservations, and actual-use
  reconciliation. Added 12/18/25% context lifecycle, minimal capability
  profiles, prompt-component ledger, and local/cheap benchmark discipline.

### Changed — Hermes cost and prompt surface
- Disabled DeepInfra/FAL video plugins plus browser, image generation, vision,
  voice, and GUI toolsets for new sessions. Removed Blender, Unreal Engine,
  and NotHumanSearch MCP servers; Hngh, MisakaNet, and DepScope remain pending
  profile audit. OpenCode removed NotHumanSearch and unfiltered DepScope;
  only local MisakaNet remains. Created mandatory standard `hngh` and
  local-only `hngh-minimal` profiles; Hngh launchers now select `hngh`, which
  retains only core Hngh capabilities. Hngh now treats 20 turns as a sprint
target and 40 as a safety cap; continuation is evidence-gated. Added the
strict local-only `hngh-opencode` adapter: bounded implement/review/probe
roles, named command authority, pruned compaction, and a fixture-first
benchmark path. Added a tiered guidance loop: reserve-model decisions become
fingerprinted teaching packets, lower-cost adoption maps, fixture proof,
independent challenge, and case-base/benchmark evidence. Kimi quota is
K3-only; GLM 5.2 is the preferred architecture teacher; Sol and Anthropic
are disabled; K2/MiMo/Terra remain explicit packeted specialists. Input and
output tokens are jointly budgeted: compact evidence packets replace transcript
replay and routine status prose. Fresh sessions are normal: a procedural
handoff, evidence-backed retirement reason, and cheap successor replace
open-ended continuation. Continuation compares bounded retained-context cost to
verified reset loss and is admitted only when reset loss is higher. Measured
fixed-prompt budgets are documented in
  `model-economy-and-context-lifecycle.md`. Reduced compression to 18%/10%,
  reduced protected history, capped standard Hngh sessions at 40 turns, and
  removed strategic routes
  from automatic fallbacks. Fresh-seat screenshot evidence still showed 72.6K
  context with 48 tools, 74 skills, and 4 MCP servers; card 130 audits the
  remaining static surface.

### Changed — K3 quota sequencing
- Seu's bounded review found the shipped predicate is not yet an authoritative
  gate: no effective 5-hour default, marginal amount ignored, no ledger rollup
  or call reservation. Card 128 now hardens quota truth before card 127 wires
  the planner.

### Changed — workspace migration target
- Replaced the flattened migration plan with whole-tree preservation under
  `~/.hngh/.hngh-night/` and `~/.hngh/.hngh-day/`, scratch-HOME verification,
  atomic moves, compatibility symlinks, and rollback.
- Executed the live migration after 70 fixture checks: 316 night and 33 day
  file manifests matched; old-root symlinks and watcher health verified.

### Fixed — dashboard interactive startup
- The dashboard runner renders the initial frame before entering its input wait loop.
- Dashboard Watch now reads live `watch/outcomes.jsonl` and falls back to the retired shell feed only when the live output is absent.
- Dashboard Steers now reads watcher-generated lane entries, with the legacy centralized log retained as fallback.

### Added — MisakaNet lesson pipeline (card 113, owner 14:51)
- Backlog card for queueing/processing/submitting failure lessons to
  MisakaNet at scale (deferred execution; deck first).
- Queue seeds from session lessons: argv-shaped duplicate-kill match,
  calm-cadence busy-fail retry, heartbeat-vs-demand steers, atomic
  steer delivery (two-call send race).
- References existing lessons (cronjob one-shot race, FReeLLMAPI
  cross-thread) instead of duplicating; template + 75-pt quality gate
  respected per repo LESSON_QUALITY_SCORING.md.

### Added — hngh-coord MCP registration (MCP-REG, working-group wave)
- Fixed `initialize.capabilities.tools` from JSON `null` to an empty
  object, and normalized empty tool schemas to `{}` / `[]` rather than
  JSON nulls.
- Corrected the stdio transport to newline-delimited JSON, matching the
  Python MCP SDK used by Hermes. The prior raw Content-Length probe was
  valid for cxxxr/jsonrpc but not for Hermes's client transport.
- Registered `hngh-coord-mcp` as local Hermes server `hngh`; discovery and
  test report five enabled tools. Independent newline wire probe passes.

- Added docs/design/durable-coordination-records.md: layered record
  model — COORD JOURNAL (steers as data), automatic procedural
  breadcrumbs per seat per phase, append-only enforced by tooling
  (lane-append helper + lane-watch CLOBBER detection), git-backed
  recovery floor via the existing ~/.hngh backup-manager tree.
- dashboard.md §8 input gating extended: all ride-along writes via the
  append helper with breadcrumbs; every steer dispatch lands a COORD
  JOURNAL record (kind "steer") for data-driven steer history.
- cross-agent-normalization.md §5a: steer ledger + breadcrumbs are the
  structured case-base feed (:human ground truth from records, not
  prose parsing); prose sweep demoted to fallback.

### Added — Hngh model manifest (card 107B, design lane)
- Added `docs/design/model-manifest.json`: the Hngh provider:model set
  with tier metadata (workhorse / reserve), schema v1. Validated in the
  seat-dashboard fixture suite against
  `hermes_cli/model_catalog._validate_manifest`.
- `seat-up`'s model gate now reads runtime truth: the SWR disk cache
  (`~/.hermes/cache/model_catalog.json`) when present, with the
  checkout copy as fallback; the gate accepts models from the catalog
  block, the canonical registry, or config `providers.<name>.models`
  (so config custom providers like `unsloth-local` spawn cleanly).
  Gate runs under the Hermes venv python (system python3 lacks yaml).
- Manifest/override transport (`model_catalog.providers.<name>.url`,
  `file://` URLs) verified end-to-end; wiring remains owner-gated.
- Fixture coverage: `tests/scripts/test-seat-dashboard.sh` now 12
  checks (added config-provider accept + manifest schema validation).

### Added — procedural agent-to-agent prompt lint (card 103)
- Added `hngh prompt-lint FILE`, a local, no-LLM guard for briefs, steers,
  and outbox entries. It emits one JSON report with level, category,
  quoted fragment, suggested fix, producer attribution, and summary counts;
  errors exit 1 and warnings-only reports exit 0.
- The lint validates model references against the daemon's
  `~/.hngh/config/hngh.lisp` path (or `HNGH_PROMPT_LINT_CONFIG` for an
  explicit profile/fixture) and the loaded model-route data. This catches
  `gpt-5.6-luna-max` without embedding a second model list.
- V1 checks model IDs, explicit paths, dangerous actions (with
  `operation-gate` human-gate reference), evidence for operational claims,
  and `STATE:`/`STEER:`/`ANSWER:` plus acceptance structure.
- Regression coverage: `tests/scripts/test-prompt-lint.py` drives the built
  `hngh` binary with temporary fixtures; 8 fast tests, no LLM or network.
- Launch-path wiring is now covered by card 106: `seat-up` runs the
  no-LLM lint before tmux/Hermes spawn, saves the JSON report in the seat
  lane, rejects error findings, and appends warning counts to worklog.
- Regression coverage: the seat fixture checks a clean mission passes and
  `gpt-5.6-luna-max` is rejected before spawn.

### Fixed — hngh-coord ACP face wire-proven (card 101 ACP half, tandem-delivered)
- Same yason trap as the MCP face, fatal on the ACP wire too: `acp-server`
  returned keyword plists, which yason's list encoder walks as arrays.
  Results now use `%mcp-object` hash-tables (the ACP face's `%ht` shape);
  coord/post and coord/status encode as JSON objects.
- `serve-acp` now rebinds `*standard-output*` to `*error-output*` — the
  state-store init INFO log was leaking onto the newline wire (same
  stream-discipline fix as `serve-mcp`).
- `read-inbox` / `coord-view` call `%ensure-store`: reading the journal
  before the first post died with a NIL `*hngh-home*` (Merge-Pathnames
  type error). Store init is now lazy on both read and write paths.
- **Verified**: independent newline-framed wire probe — initialize +
  coord/post + coord/status: ALL PASS (frame-only stdout).

### Fixed — hngh-coord MCP face dead on startup (card 101, tandem-delivered)
- Two defects, both invisible to the FiveAM store suite (which never wired
  the serve path — the MCP/ACP serve path is verified only by an
  independent wire probe over Content-Length frames).
- `coord.lisp` `mcp-server`: a paren imbalance in the `tools/list` tool
  descriptor folded the `tools/call` + `initialize` expose calls into the
  `tools/list` expose as extra arguments; at runtime the outer call hit
  `jsonrpc:expose` with 5 arguments ("invalid number of arguments: 5")
  and the server died before the first frame. Source-side count was
  globally balanced, so compiles/loads were clean; only the reader parse
  showed EXPOSE(len 6) at LET level. One missing close after the last
  `%mcp-tool` call, one compensating extra close in `initialize`.
- `coord.lisp` MCP returns: string-keyed alists → `%mcp-object` hash-tables.
  yason's default list encoder emits arrays and walks every element; a
  dotted-tail alist crashed on `("protocolVersion" . "2024-11-05")`
  ("The value \"2024-11-05\" is not of type LIST"). Hash-tables encode as
  JSON objects natively; same shape as the ACP face's `%ht`.
- `~/.local/bin/hngh-coord-mcp`: `init`'s INFO log went to fd1 (the MCP
  wire) before `serve-mcp` rebinds stdout to stderr; wrapped the init eval
  in `(let ((*standard-output* *error-output*)) ...)`. Wire is now
  frame-only, verified by raw-byte capture.
- **Verified**: independent wire probe — initialize + tools/list +
  post_message + read_inbox over raw Content-Length framing: ALL PASS
  (frame-only stdout). `make test`: **956/956 fast, 0 fail-suites**.

### Added — Wave C item 4: hash-chained action log
- **`src/core/safety-boundary.lisp`** — the append-only action log
  (`journal/actions.lisp`) is now **tamper-evident**: every entry carries
  an additive `:hash` = SHA-256 over the previous entry's hash (32 raw
  bytes; all-zero root for the first entry) and the entry's canonical
  serialization (the same downcased/unpretty form `append-journal` writes,
  so it re-derives byte-for-byte). Existing readers (`getf`-style, incl.
  the case-base journal) are unaffected — the hash is an extra key.
  - **`verify-action-log`** re-derives the whole chain and reports the
    first broken index, fail-closed: `(values NIL IDX)` on the first
    tampered entry, `(values NIL NIL)` on any read/parse error.
    Pre-chain entries (written before this change) carry no hash and are
    skipped — the chain restarts at the first hashed entry. `verify-action-log-entries`
    exposes the same check over a caller-supplied list (fixture copies).
  - Digest via **ironclad** (SHA-256) — SBCL has no built-in SHA-256
    (`sb-md5` is MD5-only). Added `ql ironclad` to `qlfile`/`qlfile.lock`
    (pin 2026-01-01) and `:ironclad` to `hngh.asd`.
- New tests in the existing `:hngh.safety-boundary` suite (5): chain-carried
  hash shape, chain intact, tamper → broken index on a fixture copy,
  pre-chain-head tolerance, fail-closed on malformed input. Isolated temp
  home, no network/model.
- Verified `make test`: **851/851 fast, 0 fail-suites** (was 846; +5 new).
  The 837 references in AGENTS.md/roadmap were already stale; corrected to
  851 per `scripts/lint-test-counts.sh` verdict.

### Added — L2/L3 Tier-1 semantic judge + paren lint gate
- **`src/plugins/situation-judge.lisp`** — cheap/local semantic judge (step 4
  of `situation-scoring.md` §8) catching what Tier-0 detectors cannot: faulty
  logic, hallucination, instruction-misread, risky-approach, wasted work.
  - **Pluggable backend**: `:http` (direct OpenAI-compatible call to any
    cheap/local endpoint — ollama, unsloth, vllm) or `:agentic` (one-off
    opencode/Hermes/Pi session via the `*judge-responder*` injection seam).
  - **Watchdog budget**: bounded judge calls per run (`*budget-per-run*`),
    reserve/fail-closed when exhausted.
  - **Bounded prompt**: recent N observations, one-line JSON verdict
    (score + confidence + reason), parsed fail-closed.
  - **Offline calibration harness**: `calibrate-judge` measures precision /
    recall / confidence-calibration against a labeled case-base; the live gate
    only opens once calibration is recorded (§6/§7). Open taxonomy grows with
    Hngh's self-development loop.
- **`scripts/lint-parens.py` + `make lint-parens`** — procedural paren guard
  wired into `test-suite`: detects unbalanced `()[]{}` in Lisp source before
  every test run (single full-text pass; handles strings/comments/char
  literals; zero false positives on multi-line docstrings), with `--fix` to
  append missing `)` at EOF.
- Green @ `be14779`: **730/730 fast, 2471/2471 full** (was 693/2434).

### Added — M8 model-routing data seed (two-role split)
- **`src/plugins/model-routes.lisp`** — the route table as data
  (id/backend/model/price/class) + the **2026-08 human steer**: primary
  **agentic** model = **deepseek-v4-flash**, primary **coding** model =
  **gpt-5.6-luna**. Accessors `route-model`/`role-model`; `role-model` falls
  back to the agentic primary for unknown roles. Read-only parse test
  (design doc verification task #2).
- 63 new checks; **818/818 fast, 2559/2559 full** (was 755/2496).
- Full M8 routing selectors (`route-task`) remain unbuilt — this seeds data
  only, per design.

### Added — Wave C items 2+4 (bwrap sandbox + hash-chained log) + paren-fixer hardening
- **Hash-chained action log (item 4, task 94 — Luna-delegated `c4c5b88`)**:
  `log-action` now hashes each entry (additive SHA-256 `:hash`, zero root for
  the first, backward-compatible skip of pre-chain entries); new
  `verify-action-log` re-derives the chain and reports the first broken
  index, fail-closed `(values nil nil)` on any error. First delegated build
  (brief → `hermes chat` on gpt-5.6-luna → verify → commit), vetted for the
  Hngh delegation process. 19 new checks; ironclad pinned in qlfile.
- **Bubblewrap per-task sandbox (item 2, task 96 — attended)**:
  `src/core/sandbox.lisp` — `run-sandboxed` runs a command in a bwrap
  default-deny profile (no net, ro system dirs, writable only the explicit
  task dir; `--die-with-parent --new-session`); fail-closed: no bwrap =>
  error, never an unsandboxed fallback. Tool hub: `tool-info` gains
  `sandboxed-p` (default NIL — attended agent sessions untouched),
  `execute-agentic-cli` routes through the sandbox when set. Tests:
  argv shape, network opt-in, fail-closed, real smoke (write outside task
  dir denied). +2 checks (smoke skipped when bwrap absent).
- **Procedural paren fixer (owner directive: LLMs never hand-count parens)**:
  `lint-parens --fix` now runs before the check in the test gate
  (auto-appends the needed `)` at EOF for unclosed forms; stray-close stays
  report-only — never deletes blindly). New regression tests
  `tests/scripts/test-lint-parens.py` (4 tests: balanced pass, unclosed
  auto-fix, stray reported-not-deleted, mixed never half-fixed) run via
  `uv run --with pytest`, wired as `make lint-parens-test` in test-suite.
- **Verified**: `make test` exit 0, **858/858 fast, 0 fail-suites**,
  lint gates + fixer tests green.

### Fixed — ACP subprocess-pipe flake (card 100, `51ebf47`)
- Two halves of the same M9.34 CI flake: an ACP reading thread whose pipe
  died under it either signaled an unhandled `SB-INT:SIMPLE-STREAM-ERROR`
  or lingered and later read recycled descriptors, dying with an unhandled
  `JSONRPC-PARSE-ERROR` that killed the whole SBCL image mid-suite.
- `acp-transport.lisp` `receive-message-using-transport`: `read-line`
  wrapped in `handler-case (stream-error () nil)` — dead/closed pipe is
  clean EOF, reader loop exits quietly (parse failures still propagate).
- `acp-client.lisp` `acp-disconnect`: destroys the jsonrpc reader/processor
  threads with bordeaux-threads `bt:destroy-thread` (the vendored
  `jsonrpc:client-disconnect` calls `bt2:destroy-thread`, a generic with
  no applicable method under the pinned qlot — silently leaked every
  connection's reader thread). Verified: 0 leaked jsonrpc threads after
  the fix; full suite stable across consecutive runs.
- +3 checks in `test-acp-client.lisp` (closed-pipe-as-EOF, thread exits
  quietly).

### Added — Wave C item 8: :operation human gate (card 99, tandem-delivered)
- **Spec** `docs/design/operation-gate.md` (tandem-a, `8933f89` + seam trap
  `f343128` + deployment note `1ca1edf`); **impl** `c657071` (tandem-b:
  gpt-5.6-luna-max). Core-file commits + dependency installs require
  explicit human approval. Unapproved → refused (task `:blocked`
  "awaiting-human-approval" at submit), journaled via safety-boundary
  `log-action :denied`, published as `operation.denied` bus event. Never
  silent, never auto-approved.
- **What landed**: `submit-task &key operation-spec` forces
  `:type :operation` + `:authority :approval` (re-set after the v3
  flatten — submit-task's `(if v3p :worker authority)` would otherwise
  dispatch an un-gated `:worker` task); `approve-task` human-only
  (config-seeded `:operation-approvals` durable, live registry, flips
  `:blocked`→`:queued`); `operation-gate-check` exact-match predicate
  (subset/superset rejected) composing lint-deps for `:core-commit`;
  driver pre-delegate gate (refusal → `:failed`, no delegate call);
  package-manager gates `install-packages`/`remove-packages`/
  `upgrade-system` before any daemon call. 8 tests, 38 checks
  (suite `:hngh.operation-gate`).
- **Deployment note (owner)**: `:operation-approvals` lives in
  `config/hngh.lisp`, which safety-boundary mode-locks to 0444 — an owner
  `hngh config set :operation-approvals ...` needs a chmod first (same
  quirk as `:tool-grants` after card 97). C6 stays PARKED until the
  canary/scan tail closes.

### Added — Wave C item 3 (least-agency tool scoping, tandem-delivered)
- **Two-Hermes ACP tandem delivered the full item** (`dccad77`, ~35 min
  launch→commit→FINAL, unattended): seat B (gpt-5.6-luna) implemented
  deny-by-default tool grants from seat A's (deepseek-v4-flash) spec
  `2244281`. Both seats ran as `hermes acp` servers driven over stdio
  JSON-RPC by the tandem director.
- **What landed**: `*tool-grants*` registry + `tool-granted-p` +
  `grant-tool`/`revoke-tool`, read-only tools auto-granted, denials
  journaled + `tool.denied` bus event, `select-tool` filter, config
  fail-closed until `:tool-grants` present. 46 new checks.
- **Process notes**: flash-as-review-counterpoint wrote STEER: notes
  (stale `grants-path` symbol, wrong bus topic, spec-contradicting
  persistence test) before luna finished — folded in mid-flight. Seat
  stopped itself cleanly with FINAL-B.md per the wind-down policy.
- **Verified**: `make test` exit 0, **904/904 fast, 0 fail-suites**.
- All Wave C gate items 1–4 land; `:operation` gate (99) + canary/scan
  tail remain before C6 is unparked.

### Added — Wave C item 1 (qlot pin) + CI red→green
- **`qlfile` + `qlfile.lock`** — project-local dependency pin via qlot
  (Wave C item 1 / autonomy-strategy §7 item 9): pins Quicklisp dist
  2026-01-01 + 8 project deps (bordeaux-threads, cl-ppcre, babel, jsonrpc,
  alexandria, yason, jsown, fiveam). sb-posix/sb-bsd-sockets correctly
  excluded (SBCL-internal).
- **Makefile**: `SBCL_FLAGS` loads `.qlot/setup.lisp` when present
  (conditional no-op otherwise) so all build/test sbcl invocations resolve
  deps from the pin. `.qlot/` gitignored.
- **`ci.yml` rewritten** to **lint-only** (deterministic `lint-parens` +
  `lint-deps`, pure python, seconds) — owner decision: the per-push
  build/test CI was serving no function (local `make test` is the quality
  gate and runs on every commit), was slow (cold recompile per push) and
  flaky (ACP stream race under CI timing). Kept as a cheap public health
  signal (`workflow_dispatch` available now). GitHub CI green.
- **`mirror.yml` deleted** — redundant (local pushes both remotes) and
  broken on the runner (SSH key path absent); was the source of "Run failed"
  email noise on every push.
- **Verified**: `make test` exit 0, 837/837 fast, 0 fail-suites; `make
  build` exit 0 — all under the pin (was failing pre-fix); GitHub CI green
  on the lint-only gate.

### Added — Wave C/backup task deck (93–99) + Luna delegation verified
- **Task cards 93–99** composed in `~/.hngh-night/tasks/` from the
  Wave C adoption research + backup-sync design (owner directive: plans →
  requirements → granular dogfood-able tasks): qlot pin, hash-chained action
  log, bwrap sandbox, native least-agency scoping (gate items 1–4), backup
  Phase A observe, canary/scan sidecar, `:operation` gate. Each card carries
  context, VERIFIED FACTS, must-do/must-not, verification gate, attribution.
- **GPT-5.6 Luna delegation verified live** (`gpt-5.6-luna` and
  `-max`, openai provider, existing OPENAI_API_KEY; probes exit 0) — no
  Copilot OAuth needed; available for delegated code completions per card.
- Session estimates from M9.32 remain provisional until cards are run and
  the work is measured against surfaces.

### Added — backup/sync accommodation design (Syncthing flagship, ADR-043/044)
- **`docs/design/backup-sync-integration.md`** — owner direction: Hngh
  manages/configures/optimizes backup + sync across devices, eliminating
  manual config. **Syncthing** is the flagship continuous device/LAN sync
  layer (P2P, no server, REST API Hngh steers: observe → reconcile → tune;
  `:operation`-gated, read-only fail-closed default).
- **Three jobs, three tools**: gbd = dotfiles (NOT a general backup manager,
  per owner); `backup-manager` = Hngh state tree (git); Syncthing = mirror
  across devices. Encrypted offsite (restic/borg/tarsnap) deferred.
- **ADR-043** (Syncthing + split), **ADR-044** (OPA SHELVED — native
  `safety-boundary`/sentry rules at this scale; revisit for fleet).
- Phase A (observe/status + Tier-0 out-of-sync detector) is the first build.

### Added — Wave C open-source adoption research
- **`docs/research/wave-c-open-source-tooling.md`** — ADOPT-or-BUILD
  decisions for all 8 Wave C items, per the owner's "don't reinvent"
  direction. ADOPT: **OPA** (least-agency tool scoping), **Bubblewrap**
  (per-task sandbox; unprivileged, smallest trust base; Firejail's own
  maintainers caution wrapper-SUID limits), **qlot** (CL dep pinning),
  **Canarytokens** (self-hosted canaries, no Docker), **LLM Guard**
  sidecar (untrusted-content scan). BUILD (novel): provenance tagging,
  `:operation` gate extension. Small build w/ precedent: SHA-256
  hash-chained action log (hermes-agent #487 pattern); Trillian rejected
  as over-heavy. gVisor/Firecracker/Kata deferred to the fleet wave.
  Adoption order documented; Wave C gate unchanged.

### Added — Wave C immutable safety layer (part 1)
- **`src/core/safety-boundary.lisp`** — the root piece of the hardened
  security baseline (autonomy-strategy.md §7 Wave C): the agent cannot edit
  its own approval/sentry/sandbox config.
  - Protected-path registry: `config/hngh.lisp`, `config/sentry.lisp`,
    `config/sandbox.lisp` registered + frozen at init; containment check
    (a path under a protected dir is protected).
  - `allow-mutation-p` — fail-closed (NIL for protected), denial recorded
    to the append-only action log. `ensure-mutable` signals on protected.
  - Append-only action log (`journal/actions.lisp`), `recent-denials`.
  - Best-effort 0444 mode-lock at init (tolerated in temp dirs / read-only
    filesystems — in-process guard enforces regardless).
  - Lives in CORE, not a plugin, so a self-modifying agent can't extend its
    own protected list. Wired into main.lisp init (after state-store,
    before plugins) + both shutdown paths.
- 19 new checks; **837/837 fast, 2578/2578 full** (was 818/2559).
- Remaining Wave C items (least-agency tool scoping, untrusted-content
  tagging, canary tokens, execution sandboxing, pinned deps, `:operation`
  human gate) are next; no core self-modification until complete.

### Added — Wave B governance guardrails (`make lint-deps`)
- **`scripts/lint-deps.py`** — deterministic dependency fitness checks
  (autonomy-strategy.md §7 Wave B), wired into `test-suite` alongside
  `lint-parens`:
  - rule1: no plugin→plugin `:use` clauses (plugins talk via hngh.core)
  - rule2: core packages never call plugin symbols (main.lisp is the
    composition root, restricted to `:init`/`:shutdown`)
  - rule3: no circular dependencies over the package `:use` + call graph
  - rule4: production never depends on `hngh.tests`
- Pattern matches `lint-parens`: single full-tree pass, per-rule violation
  reports, exit 1 on violations. Fixture-verified (4 deliberate-violation
  fixtures under `tests/fixtures/guardrails/` all fire; real tree clean).
- **Verified**: `make test` exit 0 — gates run before tests, 818/818 fast.

### Added — L2/L3 case-base + review pass (step 5, self-improvement loop)
- **`src/plugins/situation-casebase.lisp`** — persistent case-base: every
  scored situation + action + outcome is appended to a journal alongside
  human `/steer` ground-truth (high-weight), with attribution (§7).
  - `record-case` / `all-cases` / `cases-by-source` /
    `situation-distribution` — append-only persistence via the state-store.
  - `run-review-pass` — cheap/local, scheduled: re-runs the judge offline,
    recomputes precision/recall/conf, appends the pass record.
  - `accuracy-improving-p` — the §8 step 5 gate (calibration improves across
    successive passes). `emergent-classes` — open-taxonomy probe.
- 25 new checks; **755/755 fast, 2496/2496 full** (was 730/2471); later
  M8 routing seed raised the suite to 818/2559.
- L2/L3 steps 1–5 of `situation-scoring.md` §8 are now built; step 6
  (cross-agent normalization) remains.

### Added — canonical recursive acronym family + archive
- **Decision (human): canonical = the `Hngh ... Hngh` bookend family** —
  Hngh as both first and last word (the acronym expands into itself).
  Winner: `Hngh Network Goes Hngh.`; honorable mention: `Hngh Network
  Grows Hngh.` The `... Heavy` ending variants were discarded (they break
  the self-referential shape). README tagline + family updated.
- `scripts/gen-hngh-acronyms.py`: deterministic generator — grammar gate
  (`N_VERB_FORM`, killed agreement noise 1,064→400), Nihei/BLAME! register,
  H-type sections, flipped series, canonical + archive outputs. Composed
  bookend family + curated picks drafted by LLM (deepseek-v4-flash-0731 via
  openrouter) — promoted only on human approval, rest archived.

### Added — pre-public vetting + recursive-acronym tooling
- **`docs/design/public-vetting.md`** — assessment framing for going public:
  self-improvement-loop honesty, feature parity vs Odysseus & Agent Zero
  (docs-first research), multi-agent-tool ACP/MCP/A2A surface, public
  cost-vs-capability accounting, multi-instance network (design seed,
  post-v1). Registered in backlog + roadmap (not scheduled build).
- **`scripts/gen-hngh-acronyms.py`** — recursive-acronym enumerator for
  "Hngh" (H-N-G-<Hngh> in the Nihei/BLAME! register, sentence-grammar gate).
  `data/acronyms/hngh-acronyms.txt`: reproducible expansions;
  "hermes next go Hngh" / "home network goes Hngh" are in the space.

### Added
- **Design seed** — `docs/design/encoded-filename-metadata.md`: captured the
  standing idea of a standardized, decodable filename convention for agent
  direction (intended consumer, project scope, per-agent read hints / line
  scoping, semantic tags) as a non-committal seed for later evaluation.
  Registered in `docs/project/backlog.md` Open Design Questions. The
  "design seed → review gate" capture process is now formalized in
  `CONTRIBUTING.md`.

### Added — L2/L3 auto-steering brain (steps 1–3, `0c62fa9`)
- **`src/plugins/situation-detectors.lisp`** — the observation model (plist:
  `ts/agent/kind/tool/args/fingerprint/error-class/tokens/ok/artifacts/seconds`;
  kinds `:tool-call :tool-result :thinking :wait :message :cost-exceeded`) plus
  **8 Tier-0 deterministic detectors** (model-free, fail-closed):
  identical-call loop (md5 fingerprint, poll-tool exempt), retry-without-
  progress, zero-progress, long-thinking token-sink, failing-verification,
  excessive-waits, cost-exceedance, chatter-loop. Detectors emit
  `situation.detected` on the event bus; they never act on their own. Full
  design: `docs/design/situation-scoring.md`.
- **`src/plugins/situation-scoring.lisp`** — the L3 scorer behind the A3 ACP
  actuator: priority score (`w_i·impact·urgency·spread + w_c·confidence` +
  recurrence boost), a **recovery-stage tracker** (a validated fix resets the
  counter — a healthy correction never escalates), **progressive gate-lowering**
  (thresholds fall per unresolved recurrence), and action mapping to `:none /
  :steer / :interrupt` via `acp-steer-command`. Fail-closed throughout: nil
  situation → `:none`, first-seen never interrupts, S3 / token-sink-zero-env
  interrupt only on recurrence.
- Wired into `main.lisp` lifecycle, `packages.lisp`, `hngh.asd`, and the
  `make test` fast suite. Two new test files (60 checks): fixture-based, each
  with healthy counter-examples. **Green @ `0c62fa9`: 693/693 fast,
  2434/2434 full.**

### Fixed — squad opencode seats failing to start (`5dd3cc3`, config)
- Coder/worker opencode seats configured with `deepseek/deepseek-v4-flash-0731`
  failed with `UnknownError: Unexpected server error` on their first prompt
  (window opened but the seat never started). Root cause: opencode recognizes
  the `deepseek` provider, which only exposes simply-named models
  (`deepseek-v4-flash`, `deepseek-v4-pro`); the `-0731` suffix is **openrouter's
  catalog name** for flash (no `deepseek-v4-pro-0731` exists).
- Fixed `~/.hngh-night/squad-seats.conf`: coder/worker `SEAT_MODEL` →
  `openrouter/deepseek/deepseek-v4-flash-0731` (same model via openrouter;
  Flash is the smarter model for now, and the openrouter route is *usually*
  the cheaper one). `squad-up --list` parses clean; headless kick verified
  `OPENCODE_SMOKE_OK`.

### Changed
- **Cost policy** (`ff61698`): models > $0.10/M tokens are a strategic reserve
  used as rarely as Kimi K3 — GLM-5.2 is no longer a PM/Designer default
  (seats demoted to `deepseek-v4-flash-0731`). See
  `docs/design/cost-conservation.md`.
- **cogmem dropped** (`0dc36a0`, ADR-042): Anthropic-key dependency conflicts
  with cost policy. Cross-session memory = OptMem + hngh beans + AGENTS.md
  breadcrumbs.

### Fixed — earlier this block
- **ACP transport framing** (`95d61e2`): ACP requires newline-delimited
  JSON-RPC; the cxxxr/jsonrpc stdio transport used LSP Content-Length framing
  and did not interoperate with real peers. New `src/plugins/acp-transport.lisp`
  implements `:mode :acp` with newline framing; INTEROP-verified.

---

## Prior history

Before this changelog existed, development was recorded per-session in
[`docs/project/work-sessions.md`](docs/project/work-sessions.md) and
[`docs/journal/`](docs/journal/) (M0–M9, ACP A1–A4, L2/L3 research + design).
Those records remain the authoritative history for that period; this file
starts at the L2/L3 first build (2026-08-08).
