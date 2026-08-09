# Changelog

All notable changes to Hngh are documented here, dated and categorized per
[Keep a Changelog](https://keepachangelog.com/) (format) and the project's
[D1 doc convention](docs/project/decisions.md) (durable records carry
`green @ <sha>`).

The format is based on [Keep a Changelog](https://keepachangelog.com/).
Releases are not yet used (pre-alpha); entries are grouped by date.

## [Unreleased]

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
