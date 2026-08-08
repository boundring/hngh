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
